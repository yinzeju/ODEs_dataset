using LinearAlgebra, JLD2, SHA
import JSON
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
using .TestSub2NV

function main()
    BLAS.set_num_threads(1)
    root=normpath(joinpath(@__DIR__,"..",".."))
    config=joinpath(root,"configs","releases","testsub2_nv_20261004.json")
    cfg=JSON.parsefile(config)
    selected=isempty(ARGS) ? cfg["objects"] : ARGS
    all(id->id in cfg["objects"],selected) || error("Unknown model selection")
    release=joinpath(root,"data","releases",cfg["release_id"],"TestSub2")
    mkpath(release)
    files=sort!(filter(p->endswith(p,".jl"),readdir(joinpath(root,"src","data","testsub2_nv");join=true)))
    push!(files,config,@__FILE__,joinpath(root,"configs","environments","testsub2_nv","Project.toml"),
        joinpath(root,"configs","environments","testsub2_nv","Manifest.toml"),cfg["protocol_note"])
    hashes=Dict(replace(relpath(p,root),'\\'=>'/')=>TestSub2NV.file_sha(p) for p in files)
    binding=bytes2hex(sha256(join(sort!([k*":"*v for (k,v) in hashes]),"\n")))
    if isfile(joinpath(release,"release_manifest.json"))
        println("Frozen release already published; run the verifier or choose a new release_id.")
        return
    end
    TestSub2NV.write_json(joinpath(release,"manifests","provenance_$(binding[1:12]).json"),
        Dict("binding"=>binding,"files"=>hashes,"julia_version"=>string(VERSION),"configuration"=>cfg))
    snapshot=joinpath(release,"audit_only","source_snapshots",binding)
    snapshot_files=Dict{String,Any}()
    for (relative,hash) in hashes
        snapshot_relative=startswith(relative,"../") ? "_inputs/protocol_source.md" : relative
        destination=joinpath(snapshot,snapshot_relative);mkpath(dirname(destination))
        cp(normpath(joinpath(root,relative)),destination;force=true)
        TestSub2NV.file_sha(destination)==hash || error("Source snapshot mismatch")
        snapshot_files[relative]=Dict("snapshot_path"=>snapshot_relative,"sha256"=>hash)
    end
    TestSub2NV.write_json(joinpath(snapshot,"snapshot_manifest.json"),Dict("binding"=>binding,"files"=>snapshot_files))
    cp(cfg["protocol_note"],joinpath(release,"manifests","protocol_source.md");force=true)
    for id in selected
        m=jldopen(joinpath(root,"runs","testsub2_nv","models",id*".jld2"),"r") do f;f["model"];end
        folder=joinpath(release,m.id,m.configuration);mkpath(folder)
        qualification=TestSub2NV.initial_conditions(m;resource="QUAL")
        population=TestSub2NV.initial_conditions(m)
        initial_hashes=[bytes2hex(sha256(reinterpret(UInt8,ic.q))) for ic in population]
        allunique(initial_hashes) || error("Duplicate canonical initial condition")
        audit=joinpath(folder,"audit_only");mkpath(audit)
        jldopen(joinpath(audit,"mechanical_model.jld2"),"w") do f
            f["M"]=m.M;f["C"]=m.C;f["K"]=m.K;f["omega"]=m.omega;f["modes"]=m.modes
            f["equilibrium"]=zeros(2m.n);f["active_dofs"]=m.active;f["nodes"]=m.nodes;f["elements"]=m.mesh
            f["numerical_state_scale"]=vcat(m.qscale,m.omega[m.reference_mode].*m.qscale)
        end
        TestSub2NV.write_json(joinpath(audit,"frozen_initial_population.json"),
            [merge(copy(ic.meta),Dict("trajectory_id"=>ic.id,"split"=>ic.split,
                "initial_state_sha256"=>initial_hashes[i])) for (i,ic) in enumerate(population)])
        for ic in qualification
            TestSub2NV.solve_certified(m,ic,cfg,folder,binding)
        end
        certificates=Vector{Dict{String,Any}}(undef,length(population))
        # Julia tasks share only the immutable physical model; each solver owns its buffers.
        Threads.@threads :dynamic for i in eachindex(population)
            certificates[i]=TestSub2NV.solve_certified(m,population[i],cfg,folder,binding)
        end
        TestSub2NV.train_normalizer(folder,certificates,m)
        expected=cfg["canonical_counts"][id]
        actual=[count(c->c["split"]==s,certificates) for s in ("train","val","test")]
        actual==expected || error("Population budget mismatch")
        learner=Dict("object_id"=>m.id,"configuration_id"=>m.configuration,
            "noise_view"=>"clean","state_dimension"=>2m.n,"snapshot_count"=>cfg["periods"]*cfg["samples_per_period"]+1,
            "dt_output"=>2pi/m.omega[m.reference_mode]/cfg["samples_per_period"],
            "trajectories"=>[Dict("trajectory_id"=>c["trajectory_id"],"split"=>c["split"],
                "path"=>c["state_path"],"sha256"=>c["state_sha256"]) for c in certificates])
        TestSub2NV.write_json(joinpath(folder,"manifests","learner_manifest.json"),learner)
        TestSub2NV.write_json(joinpath(folder,"manifests","configuration.json"),
            Dict("object_id"=>m.id,"configuration_id"=>m.configuration,"status"=>"qualified",
                "binding"=>binding,"canonical_counts"=>actual,"metadata"=>m.metadata,
                "maximum_state_error"=>maximum(c["scaled_state_error"] for c in certificates),
                "maximum_energy_balance_error"=>maximum(c["fine"]["energy_balance_relative"] for c in certificates),
                "qualification_count"=>length(qualification)))
        println("CONFIGURATION_QUALIFIED ",id," ",actual);flush(stdout)
    end
    println("GENERATION_FINISHED; run verify_testsub2_nv_dataset.jl before publication")
end
main()
