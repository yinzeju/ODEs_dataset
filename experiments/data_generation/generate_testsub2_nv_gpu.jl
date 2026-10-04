using LinearAlgebra, JLD2, SHA, Dates
import JSON
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_exponential.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_physical.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_modal.jl"))

function freeze_sources(root,release,cfg,config)
    files=sort!(filter(p->endswith(p,".jl"),readdir(joinpath(root,"src","data","testsub2_nv");join=true)))
    append!(files,[config,@__FILE__,joinpath(@__DIR__,"prepare_testsub2_nv_models.jl"),
        joinpath(root,"configs","environments","testsub2_nv_gpu","Project.toml"),
        joinpath(root,"configs","environments","testsub2_nv_gpu","Manifest.toml"),cfg["protocol_note"]])
    calibration=joinpath(root,"runs","testsub2_nv","gpu_qualification","gpu_profile_calibration.json")
    if isfile(calibration)
        evidence=JSON.parsefile(calibration)
        all(row["passed"] for row in evidence["results"]) || error("GPU profile calibration did not pass")
        evidence["modal_source_sha256"]==TestSub2NV.file_sha(joinpath(root,"src","data","testsub2_nv","gpu_modal.jl")) || error("Calibrated solver source changed")
        for (profile,key) in (("gpu_baseline","baseline"),("gpu_fine","fine"))
            diagnostics=first(evidence["results"])[key]
            all(diagnostics[k]==cfg[profile][k] for k in ("reltol","abstol")) || error("Calibrated tolerance changed")
            diagnostics["max_step_over_reference_period"]==cfg[profile]["max_step_fraction"] || error("Calibrated step cap changed")
        end
        push!(files,calibration)
    end
    for name in ("gpu_transform_benchmark.json","gpu_batched_focused_tests.log")
        evidence_path=joinpath(root,"runs","testsub2_nv",name)
        isfile(evidence_path) && push!(files,evidence_path)
    end
    hashes=Dict(replace(relpath(p,root),'\\'=>'/')=>TestSub2NV.file_sha(p) for p in files)
    binding=bytes2hex(sha256(join(sort!([k*":"*v for (k,v) in hashes]),"\n")))
    TestSub2NV.write_json(joinpath(release,"manifests","provenance_$(binding[1:12]).json"),
        Dict("binding"=>binding,"files"=>hashes,"julia_version"=>string(VERSION),"configuration"=>cfg,
            "integration"=>"GPU Float64 Vern9 with a complete invertible mechanical modal basis; original physical-state output"))
    snapshot=joinpath(release,"audit_only","source_snapshots",binding)
    entries=Dict{String,Any}()
    for (relative,hash) in hashes
        saved=startswith(relative,"../") ? "_inputs/protocol_source.md" : relative
        destination=joinpath(snapshot,saved);mkpath(dirname(destination))
        cp(normpath(joinpath(root,relative)),destination;force=true)
        TestSub2NV.file_sha(destination)==hash || error("Source snapshot mismatch")
        entries[relative]=Dict("snapshot_path"=>saved,"sha256"=>hash)
    end
    TestSub2NV.write_json(joinpath(snapshot,"snapshot_manifest.json"),Dict("binding"=>binding,"files"=>entries))
    return binding
end

function save_trajectory(m,ic,base,fine,i,folder,binding,cfg)
    canonical=ic.split in ("train","val","test")
    relative=canonical ? joinpath("can","clean",ic.split,ic.id*".jld2") : joinpath("qualification",ic.id*".jld2")
    certificate=joinpath(folder,"qualification",ic.id*"_certificate.json")
    statepath=joinpath(folder,relative)
    state_error=TestSub2NV.compare_trajectories(m,(x=view(base.x,:,:,i),),(x=view(fine.x,:,:,i),))
    bdiag, fdiag=base.diagnostics[i],fine.diagnostics[i]
    passed=state_error<=cfg["maximum_scaled_state_error"] &&
        max(bdiag["energy_balance_relative"],fdiag["energy_balance_relative"])<=cfg["maximum_relative_energy_balance_error"] &&
        fdiag["minimum_damping_power"]>=-1e-12
    cert=Dict{String,Any}("trajectory_id"=>ic.id,"split"=>ic.split,"binding"=>binding,
        "passed"=>passed,"scaled_state_error"=>state_error,"baseline"=>bdiag,"fine"=>fdiag,
        "state_path"=>replace(relative,'\\'=>'/'),"snapshot_count"=>length(fine.t),"state_dimension"=>2m.n)
    if !passed
        TestSub2NV.write_json(certificate,cert)
        error("Qualification failed $(m.id)/$(m.configuration)/$(ic.id): state=$state_error, energy=$(fdiag["energy_balance_relative"])")
    end
    mkpath(dirname(statepath))
    jldopen(statepath*".tmp","w") do f
        f["x"]=Matrix(view(fine.x,:,:,i));f["t"]=fine.t;f["trajectory_id"]=ic.id;f["split"]=ic.split
        f["state_layout"]="rows=[all q; all v], columns=time; active DOFs in node order"
        f["units"]=m.metadata["units"]
    end
    mv(statepath*".tmp",statepath;force=true)
    energydir=joinpath(folder,"audit_only","energy");mkpath(energydir)
    jldopen(joinpath(energydir,ic.id*".jld2"),"w") do f
        f["energy"]=fine.energy[:,i];f["dissipated"]=fine.dissipated[:,i];f["damping_power"]=fine.power[:,i]
    end
    metadata=merge(copy(ic.meta),Dict("trajectory_id"=>ic.id,"object_id"=>m.id,
        "configuration_id"=>m.configuration,"resource"=>canonical ? "CAN" : "QUAL","split"=>ic.split,
        "reference_period"=>2pi/m.omega[m.reference_mode],"dt_output"=>fine.t[2]-fine.t[1],
        "snapshot_count"=>length(fine.t),"state_layout"=>"col(q,v)","physical_units"=>m.metadata["units"],
        "mesh_id"=>m.metadata["mesh_id"],"noise_view"=>"clean","solver_version"=>"Julia $(VERSION); frozen GPU environment; OrdinaryDiffEqVerner.Vern9",
        "qualification_certificate"=>replace(relpath(certificate,folder),'\\'=>'/')))
    TestSub2NV.write_json(joinpath(folder,"audit_only","trajectory_manifests",ic.id*".json"),metadata)
    cert["state_sha256"]=TestSub2NV.file_sha(statepath)
    TestSub2NV.write_json(certificate,cert)
    println("GPU_QUALIFIED ",m.id,"/",m.configuration," ",ic.id," state_error=",state_error,
        " energy=",fdiag["energy_balance_relative"]);flush(stdout)
    return cert
end

function generate_configuration(root,release,id,cfg,binding)
    m=load(joinpath(root,"runs","testsub2_nv","models",id*".jld2"),"model")
    folder=joinpath(release,m.id,m.configuration);mkpath(folder)
    info=joinpath(folder,"manifests","configuration.json")
    if isfile(info)
        old=JSON.parsefile(info)
        old["status"]=="qualified" && old["binding"]==binding || error("Different frozen configuration already exists")
        manifest=JSON.parsefile(joinpath(folder,"manifests","learner_manifest.json"))
        for row in manifest["trajectories"]
            TestSub2NV.file_sha(joinpath(folder,row["path"]))==row["sha256"] || error("Resume checksum mismatch")
        end
        println("REUSE_GPU_CONFIGURATION ",id);flush(stdout)
        return
    end
    parity=GPUExponential.force_parity(m)
    qualification=TestSub2NV.initial_conditions(m;resource="QUAL")
    population=TestSub2NV.initial_conditions(m)
    ics=vcat(qualification,population)
    hashes=[bytes2hex(sha256(reinterpret(UInt8,ic.q))) for ic in ics]
    allunique(hashes) || error("Initial states must be independent")
    audit=joinpath(folder,"audit_only");mkpath(audit)
    jldopen(joinpath(audit,"mechanical_model.jld2"),"w") do f
        f["M"]=m.M;f["C"]=m.C;f["K"]=m.K;f["omega"]=m.omega;f["modes"]=m.modes
        f["equilibrium"]=zeros(2m.n);f["active_dofs"]=m.active;f["nodes"]=m.nodes;f["elements"]=m.mesh
        f["numerical_state_scale"]=vcat(m.qscale,m.omega[m.reference_mode].*m.qscale)
    end
    TestSub2NV.write_json(joinpath(audit,"frozen_initial_population.json"),
        [merge(copy(ic.meta),Dict("trajectory_id"=>ic.id,"split"=>ic.split,
            "initial_state_sha256"=>hashes[i+length(qualification)])) for (i,ic) in enumerate(population)])
    TestSub2NV.write_json(joinpath(folder,"qualification","gpu_force_parity.json"),parity)
    println("GPU_FORMAL_START ",id," batch=",length(ics)," solver=Vern9");flush(stdout)
    q=hcat([ic.q for ic in ics]...)
    base_settings,fine_settings=cfg["gpu_baseline"],cfg["gpu_fine"]
    base=GPUModal.integrate(m,q;periods=cfg["periods"],samples_per_period=cfg["samples_per_period"],
        reltol=base_settings["reltol"],abstol=base_settings["abstol"],
        max_step_fraction=base_settings["max_step_fraction"],label="FORMAL:base")
    fine=GPUModal.integrate(m,q;periods=cfg["periods"],samples_per_period=cfg["samples_per_period"],
        reltol=fine_settings["reltol"],abstol=fine_settings["abstol"],
        max_step_fraction=fine_settings["max_step_fraction"],label="FORMAL:fine")
    # The frozen batch contains all independent QUAL and CAN trajectories. No
    # trajectory selection, truncation, or split-specific tuning occurs here.
    certificates=[save_trajectory(m,ic,base,fine,i,folder,binding,cfg) for (i,ic) in enumerate(ics)]
    canonical=certificates[length(qualification)+1:end]
    TestSub2NV.train_normalizer(folder,canonical,m)
    actual=[count(c->c["split"]==s,canonical) for s in ("train","val","test")]
    actual==cfg["canonical_counts"][id] || error("Population budget mismatch")
    learner=Dict("object_id"=>m.id,"configuration_id"=>m.configuration,"noise_view"=>"clean",
        "state_dimension"=>2m.n,"snapshot_count"=>length(fine.t),"dt_output"=>fine.t[2]-fine.t[1],
        "trajectories"=>[Dict("trajectory_id"=>c["trajectory_id"],"split"=>c["split"],
            "path"=>c["state_path"],"sha256"=>c["state_sha256"]) for c in canonical])
    TestSub2NV.write_json(joinpath(folder,"manifests","learner_manifest.json"),learner)
    TestSub2NV.write_json(info,Dict("object_id"=>m.id,"configuration_id"=>m.configuration,
        "status"=>"qualified","binding"=>binding,"canonical_counts"=>actual,"metadata"=>m.metadata,
        "maximum_state_error"=>maximum(c["scaled_state_error"] for c in canonical),
        "maximum_energy_balance_error"=>maximum(c["fine"]["energy_balance_relative"] for c in canonical),
        "qualification_count"=>length(qualification),"displacement_dof_count"=>m.n,"all_modes_retained"=>m.n,
        "integration"=>"GPU complete invertible modal basis OrdinaryDiffEqVerner.Vern9; physical-state output",
        "generation_finished_utc"=>string(now(UTC))))
    println("CONFIGURATION_QUALIFIED ",id," ",actual);flush(stdout)
end

function main()
    BLAS.set_num_threads(1)
    root=normpath(joinpath(@__DIR__,"..",".."))
    config=joinpath(root,"configs","releases","testsub2_nv_20261004.json")
    cfg=JSON.parsefile(config)
    selected=isempty(ARGS) ? ["shell_nr","shell_ir12","plate"] : ARGS
    all(id->id in ("shell_nr","shell_ir12","plate"),selected) || error("GPU configuration is not a shell or plate")
    release=joinpath(root,"data","releases",cfg["release_id"],"TestSub2")
    isfile(joinpath(release,"release_manifest.json")) && error("Release already frozen; run the verifier instead")
    binding=freeze_sources(root,release,cfg,config)
    for id in selected
        generate_configuration(root,release,id,cfg,binding)
        GC.gc()
    end
    println("GPU_GENERATION_FINISHED; run verify_testsub2_nv_dataset.jl before publication")
end
main()
