function write_json(path,value)
    mkpath(dirname(path))
    open(path,"w") do io
        JSON.print(io,value,2)
    end
    path
end
filehash(path)=open(sha256,path) |> bytes2hex
function stable_seed(cfg,parts...)
    b=sha256(join(string.((cfg["seed"],parts...)),"/"))
    # Positive 52-bit integer: exact in JSON readers using Float64.
    Int(sum(UInt64(b[i])<<(8*(i-1)) for i in 1:6))
end
function config_hash(cfg)
    paths=[joinpath(ROOT,"configs","releases","standard_odes_v2.json"),joinpath(ROOT,"Manifest.toml")]
    append!(paths,sort(filter(p->endswith(p,".jl"),readdir(@__DIR__;join=true))))
    bytes2hex(sha256(join(filehash.(paths),"/")*filehash(cfg["protocol_note"])))
end
function group_specs(cfg,mode)
    groups=Dict{String,Any}[]
    for s0 in cfg["CAN"]
        s=Dict{String,Any}(deepcopy(s0)); s["profile"]="CAN"; s["split"]="Split-I"
        s["condition_id"]="fixed"; s["axis"]=String[]; s["condition_value"]=Float64[]
        s["counts"]=[Int(s["R"]*3/4),Int(s["R"]/8),Int(s["R"]/8)]
        s["resource_id"]="$(s["family"])__CAN__$(s["id"])__Split-I"
        push!(groups,s)
    end
    for c in cfg["COND"], split in ("Split-I","Split-C"), j in cfg["condition_grid_eighths"]
        s=Dict{String,Any}(deepcopy(only(filter(x->x["id"]==c["base"],cfg["CAN"]))))
        s["id"]=c["id"]; s["M"]=c["M"]; s["profile"]="COND"; s["split"]=split
        s["axis"]=[c["axis"]]; s["condition_id"]="r$(j)_8"; s["condition_coordinate_rational"]="$(j)/8"
        a,b=c["range"]; value=Float64((rationalize(a)+(rationalize(b)-rationalize(a))*(j//8)))
        s["parameters"][c["axis"]]=value; s["condition_value"]=[value]
        haskey(c,"ic") && (s["ic"]=c["ic"])
        role=j in cfg["condition_train_eighths"] ? "train" : j in cfg["condition_val_eighths"] ? "val" : "test"
        n=s["family"]=="fput" ? 128 : 256
        s["counts"]=split=="Split-I" ? [3n÷4,n÷8,n÷8] : role=="train" ? [n,0,0] : role=="val" ? [0,n÷4,0] : [0,0,n÷4]
        s["R"]=sum(s["counts"])
        s["resource_id"]="$(s["family"])__COND__$(s["id"])__$(split)"
        push!(groups,s)
    end
    if mode==:smoke
        for s in groups
            s["M"]=min(s["M"],33)
            s["burn"]=min(s["burn"],0.2)
            s["counts"]=[x>0 ? (i==1 ? 16 : 8) : 0 for (i,x) in enumerate(s["counts"])]
            s["R"]=sum(s["counts"])
        end
    end
    groups
end

function split_roles(s,cfg)
    roles=vcat(fill("train",s["counts"][1]),fill("val",s["counts"][2]),fill("test",s["counts"][3]))
    seed=stable_seed(cfg,"split",s["resource_id"],s["condition_id"])
    shuffle!(MersenneTwister(seed),roles)
    roles,seed
end
function components(s)
    d=s["d"]; f=s["family"]
    f=="fput" && return vcat(["q$i" for i in 1:32],["p$i" for i in 1:32])
    f=="axas_haller" && return ["q1","q2","p1","p2"]
    f in ("oscillator","duffing","pendulum","vanderpol") && return ["q","p"]
    ["x$i" for i in 1:d]
end
function provenance(s)
    f=s["family"]
    sources=Dict(
        "duffing"=>["10.1002/9780470977859"],"pendulum"=>["10.1038/s41467-018-07210-0"],
        "vanderpol"=>["10.1063/1.4736859"],"axas_haller"=>["10.1007/s11071-023-08705-2"],
        "fput"=>["10.1063/5.0293702","10.5281/zenodo.15856651","10.5281/zenodo.15873646"],
        "lorenz"=>["10.1175/1520-0469(1963)020<0130:DNF>2.0.CO;2"],"rossler"=>["10.1016/0375-9601(76)90101-8"])
    Dict("model_dois"=>get(sources,f,String[]),"population_source"=>"project_protocol_note_snapshot.md",
        "literature_data_downloaded"=>false,"implementation_source"=>"local_generator_source_sha256",
        "axas_official_blob_sha"=>(f=="axas_haller" ? "dc4c064a0aa168bf72871350a5b7bf687320cd80" : "not_applicable"))
end

function metadata(s,cfg,hash,roles,seeds,split_seed,ids,x0,xrecord,substeps)
    meta=Dict{String,Any}(
        "protocol_id"=>cfg["protocol_id"],"release_id"=>cfg["release_id"],"family_id"=>s["family"],"profile"=>s["profile"],
        "base_object_id"=>s["id"],"resource_id"=>s["resource_id"],"state_components"=>components(s),
        "state_units"=>fill("nondimensional",s["d"]),"state_dim"=>s["d"],"physical_parameters"=>s["parameters"],
        "physical_parameter_binding"=>"complete_record_shared_by_all_trajectories_in_this_condition_shard",
        "condition_parameter_names"=>s["axis"],"condition_values"=>repeat(permutedims(s["condition_value"]),s["R"],1),
        "condition_id"=>s["condition_id"],"condition_coordinate_rational"=>get(s,"condition_coordinate_rational","fixed"),
        "ic_law_id"=>s["ic"],"ic_law_parameters"=>ic_description(s),"ic_seed"=>seeds,"ic_seed_group_id"=>"none_independent",
        "preburn_initial_state"=>x0,"record_initial_state"=>xrecord,"burn_in_time"=>s["burn"],
        "sampling_interval"=>s["tau"],"time_unit"=>(s["family"]=="axas_haller" ? "model_time_m=k=1" : "nondimensional_model_time"),
        "snapshot_count"=>s["M"],"transition_count"=>s["M"]-1,"record_duration"=>(s["M"]-1)*s["tau"],
        "endpoint_policy"=>"closed","layout"=>"trajectory_time_state","solver"=>solver_settings(s;substeps)["method"],
        "solver_parameters"=>solver_settings(s;substeps),"integration_dtype"=>"Float64","storage_dtype"=>"Float32",
        "normalization_policy"=>"none_raw_physical_coordinates","observation_view"=>"clean",
        "noise_reference_split_id"=>"not_applicable","noise_covariance"=>"not_applicable","noise_seed"=>"not_applicable",
        "target_view"=>"clean_full_state","target_reference"=>"state","split_protocol"=>s["split"],"split_id"=>s["resource_id"],
        "split_seed"=>split_seed,"split_roles"=>roles,"trajectory_id"=>ids,"parent_trajectory_id"=>ids,
        "source_references"=>provenance(s),"qualification_artifact_id"=>"qualification.json",
        "configuration_hash"=>hash,"trajectory_count"=>s["R"])
    if s["family"]=="duffing"
        meta["ic_amplitude_scale"]=s["radii"][2]
        meta["nonlinearity_exposure_index"]=s["parameters"]["beta"]*s["radii"][2]^2/s["parameters"]["alpha"]
    elseif s["family"]=="fput"
        meta["boundary_type"]="fixed_q0=q33=0_constants_not_dynamic"
    end
    meta
end

function generate_clean(s,cfg,hash,out,substeps)
    R,M,d=s["R"],s["M"],s["d"]
    roles,split_seed=split_roles(s,cfg)
    ids=["$(s["resource_id"])__$(s["condition_id"])__$(lpad(r,6,'0'))" for r in 1:R]
    seeds=[stable_seed(cfg,"ic",id) for id in ids]
    X=Array{Float32}(undef,R,M,d); x0=zeros(R,d); xrecord=zeros(R,d)
    diag=Vector{Dict{String,Any}}(undef,R); attempts=zeros(Int,R); failures=fill("",R)
    Threads.@threads for r in 1:R
        try
            x,attempts[r]=initial_state(s,seeds[r]); x0[r,:].=x
            A,I=integrate(s,x;substeps)
            xrecord[r,:].=A[:,1]
            info=diagnostics(s,A,I)
            info["energy_residual"]<=cfg["energy_tolerance"] || error("Energy gate: $(info["energy_residual"])")
            info["support_passed"] || error("Support gate")
            err32=0.0
            for j in 1:d, k in 1:M
                v=Float32(A[j,k]); X[r,k,j]=v
                err32=max(err32,abs(Float64(v)-A[j,k]))
            end
            info["float32_max_abs_error"]=err32; diag[r]=info
        catch e
            failures[r]=sprint(showerror,e)
        end
    end
    if any(!isempty,failures)
        write_json(joinpath(out,"failure_$(s["id"])_$(s["condition_id"]).json"),Dict("ids"=>ids,"seeds"=>seeds,"failures"=>failures,"spec"=>s))
        error("Formal trajectory failures: $(count(!isempty,failures)); no resampling performed")
    end
    meta=metadata(s,cfg,hash,roles,seeds,split_seed,ids,x0,xrecord,substeps)
    meta["execution_profile"]=cfg["execution_profile"]
    train=findall(==("train"),roles)
    power=isempty(train) ? zeros(d) : [mean(x->Float64(x)^2,view(X,train,:,j)) for j in 1:d]
    # Fit the noise reference from the published clean observation, before any normalization.
    path=joinpath(out,s["resource_id"],s["condition_id"],"clean.jld2"); mkpath(dirname(path))
    JLD2.jldsave(path;state=X,time=collect(0:M-1).*s["tau"],metadata=meta,diagnostics=diag)
    qualification=Dict("trajectory_count"=>R,"snapshot_count"=>M,"shape"=>[R,M,d],
        "energy_max"=>maximum(v["energy_residual"] for v in diag),
        "energy_q50_q95_q99"=>quantile([v["energy_residual"] for v in diag],[0.5,0.95,0.99]),
        "positive_energy_increment_max"=>maximum(v["positive_energy_increment"] for v in diag),
        "float32_max_abs_error"=>maximum(v["float32_max_abs_error"] for v in diag),
        "ic_attempts"=>sum(attempts),"ic_rejection_rate"=>1-R/sum(attempts),"integration_failures"=>0,
        "finite_passed"=>true,"support_passed"=>true,"train_power"=>power,"all_passed"=>true)
    write_json(joinpath(dirname(path),"qualification.json"),qualification)
    write_json(joinpath(dirname(path),"manifest.json"),meta)
    Dict("spec"=>s,"path"=>replace(relpath(path,out),'\\'=>'/'),"train_power"=>power,"qualification"=>qualification,
         "sha256"=>filehash(path),"bytes"=>filesize(path))
end

function generate_noise!(entries,cfg,out)
    names=unique(e["spec"]["resource_id"] for e in entries)
    for name in names
        group=filter(e->e["spec"]["resource_id"]==name,entries)
        train=filter(e->e["spec"]["counts"][1]>0,group)
        power=reduce(+,e["train_power"] for e in train)./length(train)
        reference=Dict("reference_id"=>name*"__clean_train_power","split_id"=>name,"power"=>power,
            "condition_ids"=>[e["spec"]["condition_id"] for e in train],"condition_mass"=>1/length(train),
            "measure"=>"uniform_condition_uniform_train_trajectory_uniform_full_record_snapshot",
            "definition"=>"uncentered_second_moment_of_published_clean_Float32_state_accumulated_in_Float64",
            "zero_power_components"=>findall(iszero,power))
        write_json(joinpath(out,name,"noise_reference.json"),reference)
        for e in group
            s=e["spec"]; path=joinpath(out,e["path"]); X=JLD2.load(path,"state"); base=JLD2.load(path,"metadata")
            noise_records=Any[]
            for db in (5,15)
                sigma=sqrt.(power).*10.0^(-db/20); seeds=[stable_seed(cfg,"noise",id,db) for id in base["trajectory_id"]]
                Z=similar(X); errpower=zeros(s["R"],s["d"])
                Threads.@threads for r in 1:s["R"]
                    rng=MersenneTwister(seeds[r])
                    for j in 1:s["d"], k in 1:s["M"]
                        Z[r,k,j]=Float32(Float64(X[r,k,j])+sigma[j]*randn(rng))
                        errpower[r,j]+=(Float64(Z[r,k,j])-Float64(X[r,k,j]))^2/s["M"]
                    end
                end
                measured=vec(mean(errpower;dims=1))
                ref_snr=[power[j]==0 ? nothing : 10log10(power[j]/measured[j]) for j in eachindex(power)]
                actual_power=[mean(x->Float64(x)^2,view(X,:,:,j)) for j in eachindex(power)]
                actual_snr=[power[j]==0 ? nothing : 10log10(actual_power[j]/measured[j]) for j in eachindex(power)]
                # Smoke has too few independent samples for the formal 0.15 dB gate.
                tolerance=cfg["execution_profile"]=="smoke" ? 2.5 : cfg["noise_snr_tolerance_db"]
                all(x===nothing || abs(x-db)<=tolerance for x in ref_snr) || error("Noise reference gate failed: $name, $(s["condition_id"]), $ref_snr")
                meta=copy(base); meta["observation_view"]="noise_$(db)db"; meta["noise_seed"]=seeds
                meta["noise_reference_split_id"]=name; meta["noise_covariance"]=Dict("diagonal"=>sigma.^2)
                meta["noise_reference_id"]=reference["reference_id"]; meta["target_reference"]="clean.jld2::state"
                p=joinpath(dirname(path),"noise_$(db)db.jld2")
                JLD2.jldsave(p;observation=Z,metadata=meta)
                write_json(joinpath(dirname(path),"noise_$(db)db_manifest.json"),meta)
                push!(noise_records,Dict("view"=>meta["observation_view"],"path"=>replace(relpath(p,out),'\\'=>'/'),
                    "sha256"=>filehash(p),"bytes"=>filesize(p),"reference_snr_db"=>ref_snr,
                    "condition_actual_snr_db"=>actual_snr,"noise_power"=>measured,"all_passed"=>true))
            end
            e["noise_views"]=noise_records
        end
        println("NOISE PASS ",name); flush(stdout)
    end
end

function verify_release(out;write_result=true)
    manifest=JSON.parsefile(joinpath(out,"release_manifest.json"))
    ids=Set{String}(); seeds=Set{Int}(); n=0; vectors=0; bytes=0
    for e in manifest["objects"]
        s=e["spec"]; path=joinpath(out,e["path"])
        @assert filehash(path)==e["sha256"]
        X=JLD2.load(path,"state"); meta=JLD2.load(path,"metadata"); time=JLD2.load(path,"time")
        @assert size(X)==(s["R"],s["M"],s["d"]) && eltype(X)==Float32 && all(isfinite,X)
        @assert time==collect(0:s["M"]-1).*s["tau"] && all(diff(time).>0)
        @assert [count(==(r),meta["split_roles"]) for r in ("train","val","test")]==s["counts"]
        @assert permutedims(X[:,1,:])==Float32.(permutedims(meta["record_initial_state"]))
        @assert meta["configuration_hash"]==manifest["configuration_hash"]
        @assert meta["transition_count"]==s["M"]-1
        @assert length(meta["trajectory_id"])==s["R"]
        for (id,seed) in zip(meta["trajectory_id"],meta["ic_seed"])
            @assert !(id in ids) && !(seed in seeds)
            push!(ids,id); push!(seeds,seed)
        end
        for v in e["noise_views"]
            vp=joinpath(out,v["path"]); @assert filehash(vp)==v["sha256"]
            Z=JLD2.load(vp,"observation"); vm=JLD2.load(vp,"metadata")
            @assert size(Z)==size(X) && all(isfinite,Z) && eltype(Z)==Float32
            @assert vm["parent_trajectory_id"]==meta["trajectory_id"] && vm["split_roles"]==meta["split_roles"]
            @assert vm["target_reference"]=="clean.jld2::state"
            bytes+=v["bytes"]
        end
        n+=s["R"]; vectors+=s["R"]*s["M"]; bytes+=e["bytes"]
    end
    for rid in unique(e["spec"]["resource_id"] for e in manifest["objects"])
        group=filter(e->e["spec"]["resource_id"]==rid,manifest["objects"])
        reference=JSON.parsefile(joinpath(out,rid,"noise_reference.json"))
        train=filter(e->e["spec"]["counts"][1]>0,group)
        @assert isapprox(reference["power"],reduce(+,e["train_power"] for e in train)./length(train);rtol=1e-14)
        if group[1]["spec"]["profile"]=="COND"
            @assert length(group)==9
            if group[1]["spec"]["split"]=="Split-C"
                @assert length(reference["condition_ids"])==5
                @assert all(count(>(0),e["spec"]["counts"])==1 for e in group)
            end
        end
    end
    result=Dict("all_passed"=>true,"verified_at"=>string(now()),"shards"=>length(manifest["objects"]),
        "resource_count"=>length(unique(e["spec"]["resource_id"] for e in manifest["objects"])),
        "trajectory_count"=>n,"state_vectors"=>vectors,"view_count"=>3length(manifest["objects"]),
        "data_bytes"=>bytes,"configuration_hash"=>manifest["configuration_hash"])
    write_result && write_json(joinpath(out,"verification.json"),result)
    result
end

function generate(mode::Symbol)
    mode in (:smoke,:formal) || error("Unsupported execution mode")
    LinearAlgebra.BLAS.set_num_threads(1)
    cfg=Dict{String,Any}(JSON.parsefile(joinpath(ROOT,"configs","releases","standard_odes_v2.json")))
    cfg["execution_profile"]=string(mode); hash=config_hash(cfg)
    out=mode==:smoke ? joinpath(ROOT,"runs","smoke_tests","standard_odes_v2",hash[1:12]) : joinpath(ROOT,"data","releases",cfg["release_id"])
    mkpath(out); ledger=joinpath(out,"progress.json")
    if isfile(ledger)
        previous=JSON.parsefile(ledger)
        previous["configuration_hash"]==hash || error("Existing output has different source/configuration identity: $out")
    end
    write_json(ledger,Dict("configuration_hash"=>hash,"status"=>"qualifying","execution_profile"=>string(mode)))
    cp(cfg["protocol_note"],joinpath(out,"protocol_note_snapshot.md");force=true)
    cp(joinpath(ROOT,"Manifest.toml"),joinpath(out,"Julia_Manifest.toml");force=true)
    write_json(joinpath(out,"frozen_config.json"),cfg)
    groups=group_specs(cfg,mode)
    probes=Dict{String,Any}(); history=Any[]; K=cfg["fput_initial_substeps"]
    qkey(s)=s["id"]*"/"*s["condition_id"]
    unique_groups=unique(qkey,groups)
    # Freeze the same accepted FPUT substep count across CAN and both COND splits.
    while true
        pass=true
        for s in filter(s->s["family"]=="fput",unique_groups)
            q=qualify(s,cfg;substeps=K,smoke=mode==:smoke); probes[qkey(s)]=q
            pass &= q["all_passed"]
            push!(history,Dict("substeps"=>K,"qualification"=>q))
        end
        write_json(joinpath(out,"fput_refinement_history.json"),history)
        pass && break
        K*=2
        K<=cfg["fput_max_substeps"] || error("FPUT qualification exhausted refinement budget")
    end
    println("FPUT QUALIFIED substeps=",K); flush(stdout)
    for s in filter(s->s["family"]!="fput",unique_groups)
        q=qualify(s,cfg;substeps=K,smoke=mode==:smoke); probes[qkey(s)]=q
        write_json(joinpath(out,"numerical_probes.json"),probes)
        q["all_passed"] || error("Independent numerical qualification failed: $(qkey(s))")
        println("PROBE PASS ",qkey(s)); flush(stdout)
    end
    write_json(joinpath(out,"numerical_probes.json"),probes)
    entries=Any[]
    for (i,s) in enumerate(groups)
        e=generate_clean(s,cfg,hash,out,K); push!(entries,e)
        write_json(ledger,Dict("configuration_hash"=>hash,"status"=>"generating_clean","completed_shards"=>i,"total_shards"=>length(groups)))
        println("CLEAN PASS ",i,"/",length(groups)," ",s["resource_id"],"/",s["condition_id"]," energy=",e["qualification"]["energy_max"]); flush(stdout)
    end
    generate_noise!(entries,cfg,out)
    manifest=Dict("protocol_id"=>cfg["protocol_id"],"release_id"=>cfg["release_id"],"execution_profile"=>string(mode),
        "configuration_hash"=>hash,"note_sha256"=>filehash(cfg["protocol_note"]),"julia_version"=>string(VERSION),
        "threads"=>Threads.nthreads(),"fput_substeps"=>K,"objects"=>entries,
        "numerical_probes"=>"numerical_probes.json","all_passed"=>false,"status"=>"awaiting_readback")
    write_json(joinpath(out,"release_manifest.json"),manifest)
    result=verify_release(out)
    manifest["all_passed"]=true; manifest["status"]="qualified"; manifest["summary"]=result
    write_json(joinpath(out,"release_manifest.json"),manifest)
    write_json(ledger,Dict("configuration_hash"=>hash,"status"=>"complete","summary"=>result))
    println("RELEASE PASS ",JSON.json(result)); println("OUTPUT ",out); flush(stdout)
    out
end
