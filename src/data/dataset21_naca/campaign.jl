# SPDX-License-Identifier: GPL-3.0-only
partial_qualification(cfg) = get(cfg["qualification"],"acceptance_policy","full") == "user_authorized_partial"
qualification_filename(cfg) = partial_qualification(cfg) ? "partial_authorization.json" : "qualified.json"

function load_config(path)
    relative=relpath(abspath(path),ROOT)
    (relative==".." || startswith(relative,"..\\") || startswith(relative,"../") || isabspath(relative)) && error("Configuration must be inside this project")
    cfg=JSON.parsefile(path)
    cfg["_config_path"]=abspath(path);cfg["_config_sha256"]=filehash(path)
    cfg["source_commit"]==UPSTREAM_COMMIT || error("Source version mismatch")
    cfg["damping"]["target_modes"]==[1,2] || error("This version matches the first two modes")
    cfg["sampling"]["frames"]>=2 || error("At least two frames required")
    cfg["sampling"]["dt_seconds"]>0 || error("Positive output interval required")
    cfg["solver"]["beta"]==0.25 && cfg["solver"]["gamma"]==0.5 || error("Only average-acceleration Newmark is implemented")
    cfg["solver"]["substeps"]>0 || error("Positive internal substep count required")
    get(cfg["solver"],"integrator","newmark") in ("newmark","radau5") || error("Unknown integrator")
    get(cfg["solver"],"tangent_strategy","consistent_lu") in
        ("consistent_lu","consistent_cholesky","cached_linear_with_consistent_fallback") || error("Unknown tangent strategy")
    cfg["compute"]["trajectory_concurrency"]==1 || error("This version streams one trajectory at a time")
    cfg["compute"]["backend"] in ("auto","cpu","gpu") || error("Unknown compute backend")
    if partial_qualification(cfg)
        cfg["qualification"]["user_authorized_skip_remaining"] === true || error("Explicit partial qualification authorization required")
        length(cfg["qualification"]["cases"])==2 || error("Retain exactly the two completed cases")
        isempty(cfg["qualification"]["spatial_cases"]) || error("Partial release cannot claim spatial qualification")
        cfg["solver"]["substeps"]==2 || error("Partial release must retain the completed time-refinement setting")
    elseif get(cfg["qualification"],"spatial_assessment","raw_pointwise")=="modal_response"
        cases=cfg["qualification"]["cases"];spatial=cfg["qualification"]["spatial_cases"]
        length(spatial)>=2 && all(i->1<=i<=length(cases),spatial) || error("At least two independent spatial cases required")
        any(i->cases[i]["family"]==4,spatial) || error("Finite-amplitude mode 4 must receive spatial qualification")
        any(i->cases[i]["family"]==11,spatial) || error("Mixed-mode spatial qualification required")
    end
    occursin(r"^[a-zA-Z0-9_-]+$",cfg["release_id"]) || error("Release identity must be a single safe directory name")
    length(cfg["initial_conditions"]["families"])==12 || error("Twelve initial-condition families required")
    for (name,count) in (("train",96),("validation",24),("test",24))
        cfg["initial_conditions"]["counts"][name]==count || error("Population design requires 96/24/24")
    end
    !cfg["gravity"] && !cfg["rotation"] && !cfg["external_force_after_release"] || error("Only unforced nonrotating dynamics supported")
    cfg["initial_velocity"]==0 && isempty(cfg["noise_views"]) || error("Only zero-velocity clean releases supported")
    return cfg
end

function input_fingerprint(cfg)
    files=Dict{String,String}()
    for directory in (joinpath(ROOT,"src","data","dataset21_naca"),joinpath(ROOT,"configs","environments","dataset21_naca"))
        for (parent,_,names) in walkdir(directory),name in names
            endswith(name,".jl") || endswith(name,".toml") || name in ("LICENSE","NOTICE.md") || continue
            path=joinpath(parent,name);files[portable_relative(path,ROOT)]=filehash(path)
        end
    end
    for path in (cfg["_config_path"],joinpath(ROOT,cfg["protocol_snapshot"]),joinpath(ROOT,"configs","references","naca_sources.json"),
        joinpath(ROOT,"experiments","data_generation","run_dataset21_naca.jl"),
        joinpath(ROOT,"experiments","data_generation","prepare_dataset21_naca_sources.py"))
        files[portable_relative(path,ROOT)]=filehash(path)
    end
    if haskey(cfg,"qualification_decision_note")
        path=joinpath(ROOT,cfg["qualification_decision_note"])
        files[portable_relative(path,ROOT)]=filehash(path)
    end
    return files
end

function bind_inputs(folder,cfg)
    manifest=joinpath(ROOT,"configs","environments","dataset21_naca","Manifest.toml")
    isfile(manifest) || error("Resolve the isolated environment before execution; no dependency resolution was run during preparation")
    current=input_fingerprint(cfg);path=joinpath(folder,"input_fingerprint.json")
    if isfile(path)
        Dict(JSON.parsefile(path))==current || error("Inputs changed; use a new release_id rather than overwrite a run")
    else
        mkpath(folder);writejson(path,current)
    end
    for (relative,hash) in current
        source=joinpath(ROOT,relative);target=joinpath(folder,"source_snapshot",relative)
        if isfile(target)
            filehash(target)==hash || error("Source snapshot mismatch")
        else
            mkpath(dirname(target));cp(source,target)
        end
    end
end

function prepare_models(folder,cfg,gmsh)
    if haskey(cfg,"reuse_prepared_models_from")
        parent_id=cfg["reuse_prepared_models_from"]
        occursin(r"^[a-zA-Z0-9_-]+$",parent_id) || error("Invalid model reuse identity")
        parent=joinpath(ROOT,"runs",parent_id)
        if isfile(joinpath(parent,"prepared.json"))
            old_inputs=JSON.parsefile(joinpath(parent,"input_fingerprint.json"))
            config_path=only(filter(p->startswith(p,"configs/releases/") && endswith(p,".json"),collect(keys(old_inputs))))
            old_config=JSON.parsefile(joinpath(parent,"source_snapshot",config_path))
            for key in ("material","damping","mesh","source_commit")
                old_config[key]==cfg[key] || error("Prepared model reuse changes $key")
            end
            for name in ("allman.jl","mesh.jl","mechanics.jl")
                relative="src/data/dataset21_naca/"*name
                old_inputs[relative]==filehash(joinpath(ROOT,relative)) || error("Assembly implementation changed: $name")
            end
            # load_models verifies every model against its prepared hash binding.
            reused=load_models(parent)
            2length(reused["candidate"].active)<=get(cfg["mesh"],"state_dimension_hard_max",30000) || error("Reused formal model exceeds the user's state cap")
            for name in ("models","meshes","models.json","source_modal_comparison.json","gmsh_version.json","prepared.json")
                ispath(joinpath(folder,name)) && error("Refusing to overwrite prepared model reuse target")
                cp(joinpath(parent,name),joinpath(folder,name))
            end
            writejson(joinpath(folder,"prepared_model_reuse.json"),Dict("parent_release"=>parent_id,
                "parent_inputs_sha256"=>filehash(joinpath(parent,"input_fingerprint.json")),
                "models_sha256"=>filehash(joinpath(folder,"models.json")),
                "reason"=>"Identical geometry, assembly source, materials, damping and mode configuration; qualification reruns independently"))
            println("NACA_PREPARED_MODELS_REUSED ",parent_id);flush(stdout)
            return JSON.parsefile(joinpath(folder,"models.json"))
        end
        println("NACA_PREPARED_MODELS_PARENT_UNAVAILABLE rebuilding from frozen sources");flush(stdout)
    end
    reference=read_mesh(joinpath(source_root(),"examples","NACAWing","Wing.msh"))
    6(size(reference.nodes,1)-length(reference.fixed_nodes))==133920 || error("Pinned reference DOF count mismatch")
    size(reference.triangles,1)==49968 || error("Pinned reference element count mismatch")
    receipt=Dict{String,Any}()
    gmsh_version=strip(read(`$gmsh -version`,String))
    writejson(joinpath(folder,"gmsh_version.json"),Dict("version"=>gmsh_version,"executable"=>gmsh))
    for name in ("candidate","fine1","fine2")
        println("NACA_PREPARE_MESH ",name);flush(stdout)
        output=joinpath(folder,"models",name*".jld2")
        if isfile(output)
            model=JLD2.load(output,"model")
        else
            mesh=generate_mesh(joinpath(folder,"meshes",name),cfg["mesh"][name],gmsh)
            model=assemble(mesh,cfg)
            mkpath(dirname(output));temporary=output*".tmp"
            JLD2.jldsave(temporary;model);mv(temporary,output)
        end
        name=="candidate" && 2length(model.active)>get(cfg["mesh"],"state_dimension_hard_max",30000) &&
            error("Formal candidate exceeds the user's hard state-dimension cap")
        low,high=cfg["mesh"]["state_dimension_soft_range"]
        receipt[name]=Dict("sha256"=>filehash(output),"mesh_sha256"=>model.mesh.source_sha256,
            "n_q"=>length(model.active),"state_dimension"=>2length(model.active),
            "elements"=>length(model.elements),"omega_rad_s"=>model.omega,
            "rayleigh_aM_per_s"=>model.aM,"rayleigh_aK_s"=>model.aK,
            "in_soft_dimension_range"=>low<=2length(model.active)<=high)
    end
    writejson(joinpath(folder,"models.json"),receipt)
    source_frequency_error=maximum(abs.(receipt["fine2"]["omega_rad_s"][1:4]./
        cfg["qualification"]["source_frequency_reference_rad_s"].-1))
    writejson(joinpath(folder,"source_modal_comparison.json"),Dict("relative_max"=>source_frequency_error,
        "reference"=>"rounded public damped frequencies, used as an approximate source check"))
    source_frequency_error<=cfg["qualification"]["source_frequency_relative"] || error("Fine source geometry failed the public frequency comparison")
    writejson(joinpath(folder,"prepared.json"),Dict("status"=>"prepared",
        "models_sha256"=>filehash(joinpath(folder,"models.json")),
        "source_modal_comparison_sha256"=>filehash(joinpath(folder,"source_modal_comparison.json"))))
    return receipt
end

function load_models(folder; candidate_only=false)
    prepared=JSON.parsefile(joinpath(folder,"prepared.json"))
    prepared["status"]=="prepared" || error("Model preparation did not complete")
    prepared["models_sha256"]==filehash(joinpath(folder,"models.json")) || error("Prepared model binding changed")
    prepared["source_modal_comparison_sha256"]==filehash(joinpath(folder,"source_modal_comparison.json")) || error("Source comparison changed")
    receipt=JSON.parsefile(joinpath(folder,"models.json"))
    models=Dict{String,WingModel}()
    for name in (candidate_only ? ("candidate",) : ("candidate","fine1","fine2"))
        path=joinpath(folder,"models",name*".jld2")
        filehash(path)==receipt[name]["sha256"] || error("Model artifact changed")
        models[name]=JLD2.load(path,"model")
    end
    return models
end

function population(m,cfg,Amax,qual)
    rows=Any[];states=Vector{Float64}[];seen=Set(String(r["initial_state_sha256"]) for r in qual["cases"])
    levels=cfg["initial_conditions"]["levels"];jitter=cfg["initial_conditions"]["relative_jitter"]
    counters=Dict("train"=>0,"validation"=>0,"test"=>0)
    for family in 1:12,k in 1:12
        split=k<=8 ? "train" : k<=10 ? "validation" : "test"
        identity="$(cfg["release_id"])/$(cfg["initial_conditions"]["seed"])/$family/$k"
        seed=parse(UInt64,bytes2hex(sha256(identity))[1:16];base=16)
        rng=Xoshiro(seed)
        level=levels[mod1(k+family,3)]*(1+jitter*(2rand(rng)-1))
        q,metadata=initial_state(m,family,Amax*level,rng,cfg)
        hash=bytes2hex(sha256(reinterpret(UInt8,q)))
        hash in seen && error("Duplicate initial state across population/QUAL")
        push!(seen,hash)
        metadata["split"]=split;metadata["seed_hex"]=string(seed;base=16)
        counters[split]+=1
        metadata["id"]="CAN_$(split)_$(lpad(counters[split],3,'0'))"
        metadata["initial_state_sha256"]=hash
        push!(rows,metadata);push!(states,q)
    end
    return rows,states
end

function accepted_qualification(folder,cfg)
    path=joinpath(folder,"qualification",qualification_filename(cfg))
    q=JSON.parsefile(path)
    expected=partial_qualification(cfg) ? "user_authorized_partial" : "qualified"
    q["status"]==expected && q["config_sha256"]==cfg["_config_sha256"] || error("Missing or stale qualification")
    q["models_sha256"]==filehash(joinpath(folder,"models.json")) || error("Qualification/model binding changed")
    q["inputs_sha256"]==filehash(joinpath(folder,"input_fingerprint.json")) || error("Qualification/source binding changed")
    if partial_qualification(cfg)
        length(q["cases"])==2 && q["substeps"]==2 || error("Partial evidence scope mismatch")
        q["user_authorized_skip_remaining"] === true || error("Missing user authorization")
        for (relative,hash) in q["retained_evidence_sha256"]
            evidence=normpath(joinpath(ROOT,relative))
            startswith(portable_relative(evidence,ROOT),"runs/") || error("Invalid evidence path")
            filehash(evidence)==hash || error("Retained evidence changed: $relative")
        end
    end
    return q
end

function generate_population(folder,m,cfg)
    2length(m.active)<=get(cfg["mesh"],"state_dimension_hard_max",30000) || error("Formal state-dimension cap")
    qual=accepted_qualification(folder,cfg)
    release=joinpath(ROOT,"data","releases",cfg["release_id"])
    isfile(joinpath(release,"release_manifest.json")) && error("Release already published; use verify stage")
    mkpath(release)
    rows,states=population(m,cfg,qual["amplitude_max_m"],qual)
    writejson(joinpath(folder,"population.json"),rows)
    backend=qual["backend"]=="gpu" ? GPUBackend(m) : CPUBackend(m)
    outputs=Any[]
    for (row,q) in zip(rows,states)
        path=joinpath(release,row["split"],row["id"]*".h5")
        public_metadata=Dict("id"=>row["id"],"split"=>row["split"],"units"=>"m/rad then m/s/rad/s",
            "qualification_status"=>qual["status"])
        receipt=ensure_trajectory(path,m,q,cfg;backend,substeps=qual["substeps"],metadata=public_metadata)
        passed=receipt["max_energy_balance_relative"]<=cfg["qualification"]["energy_balance_relative"] &&
            receipt["final_energy_ratio"]<=cfg["qualification"]["end_energy_fraction"] &&
            receipt["max_recovered_strain_component"]<=cfg["initial_conditions"]["maximum_strain_component"]
        receipt["physical_gates_passed"]=passed
        receipt["qualification_status"]=qual["status"]
        writejson(path*".json",receipt)
        passed || error("Formal trajectory $(row["id"]) failed; no replacement or retuning is permitted")
        push!(outputs,Dict("id"=>row["id"],"split"=>row["split"],"initial_state_sha256"=>row["initial_state_sha256"],
            "path"=>portable_relative(path,release),"sha256"=>receipt["sha256"]))
        writejson(joinpath(folder,"formal_progress.json"),outputs)
    end
    # Freeze an allowlist before publishing the root manifest.
    writejson(joinpath(release,"learner_manifest.json"),Dict("schema"=>"dataset21.naca.learner.v1",
        "state_dimension"=>2length(m.active),"frames"=>cfg["sampling"]["frames"],
        "dt_seconds"=>cfg["sampling"]["dt_seconds"],"trajectories"=>outputs,
        "qualification_status"=>qual["status"]))
    normalizer=fit_train_normalizer(release,outputs,2length(m.active))
    JLD2.jldsave(joinpath(release,"train_normalizer.jld2");normalizer)
    # Keep source matrices and IC details outside the learner view.
    audit=joinpath(release,"audit_only");mkpath(audit)
    for name in ("input_fingerprint.json","models.json","population.json")
        cp(joinpath(folder,name),joinpath(audit,name);force=true)
    end
    cp(joinpath(folder,"models","candidate.jld2"),joinpath(audit,"mechanical_model.jld2");force=true)
    cp(joinpath(folder,"qualification",qualification_filename(cfg)),joinpath(audit,"qualification.json");force=true)
    isdir(joinpath(audit,"source_snapshot")) || cp(joinpath(folder,"source_snapshot"),joinpath(audit,"source_snapshot"))
    verify_release(release,m,cfg;published=false)
    catalog=Dict{String,String}()
    for (parent,_,files) in walkdir(release),name in files
        path=joinpath(parent,name);catalog[portable_relative(path,release)]=filehash(path)
    end
    writejson(joinpath(release,"artifact_manifest.json"),catalog)
    writejson(joinpath(release,"release_manifest.json"),Dict("status"=>(partial_qualification(cfg) ? "dataset-generated-partial-qualification" : "dataset-qualified"),
        "qualification_status"=>qual["status"],
        "release_id"=>cfg["release_id"],"dataset_code"=>"Dataset-2.1/FE-NACA-WING",
        "model_sha256"=>filehash(joinpath(audit,"mechanical_model.jld2")),
        "artifact_manifest_sha256"=>filehash(joinpath(release,"artifact_manifest.json")),
        "frames"=>cfg["sampling"]["frames"],"trajectories"=>144,
        "qualification_scope"=>(partial_qualification(cfg) ?
            "User authorized generation with only two retained mode-1 QUAL cases; remaining independent QUAL and nonlinear spatial certification waived. Per-trajectory Newton convergence, strain, energy and readback checks retained." :
            "independent spatial/time QUAL; per-trajectory convergence, strain, energy and readback gates")))
    verify_release(release,m,cfg)
    writejson(joinpath(ROOT,"data","dataset21_naca_active.json"),Dict("manifest"=>portable_relative(joinpath(release,"release_manifest.json"),ROOT),
        "sha256"=>filehash(joinpath(release,"release_manifest.json"))))
end

function fit_train_normalizer(release,rows,dimension)
    count=0;average=zeros(dimension);M2=zeros(dimension)
    for row in rows
        row["split"]=="train" || continue
        HDF5.h5open(joinpath(release,row["path"]),"r") do file
            for first in 1:32:size(file["x"],2)
                x=file["x"][:,first:min(first+31,size(file["x"],2))]
                for column in eachcol(x)
                    count+=1;delta=column-average;average.+=delta/count;M2.+=delta.*(column-average)
                end
            end
        end
    end
    deviation=sqrt.(M2/count)
    constant_channels=findall(<=(eps()),deviation);deviation[constant_channels].=1.
    return Dict("mean"=>average,"std"=>deviation,"constant_channels"=>constant_channels,
        "count"=>count,"source_split"=>"train","population_std"=>true)
end

function verify_release(release,m,cfg;published=true)
    manifest=JSON.parsefile(joinpath(release,"learner_manifest.json"))
    expected=partial_qualification(cfg) ? "user_authorized_partial" : "qualified"
    manifest["qualification_status"]==expected || error("Learner qualification label mismatch")
    counts=Dict("train"=>0,"validation"=>0,"test"=>0);ids=Set{String}()
    for row in manifest["trajectories"]
        id=row["initial_state_sha256"];id in ids && error("Duplicate population initial state");push!(ids,id)
        counts[row["split"]]+=1;path=joinpath(release,row["path"])
        filehash(path)==row["sha256"] || error("Trajectory integrity")
        HDF5.h5open(path,"r") do file
            size(file["x"])==(2length(m.active),cfg["sampling"]["frames"]) || error("State shape")
            t=read(file["t"]);maximum(abs,t-collect(0:length(t)-1)*cfg["sampling"]["dt_seconds"])<1e-12 || error("Time grid")
            initial=file["x"][:,1];all(iszero,initial[length(m.active)+1:end]) || error("Nonzero initial velocity")
            bytes2hex(sha256(reinterpret(UInt8,initial[1:length(m.active)])))==id || error("Initial state integrity")
            for first in 1:32:length(t)
                all(isfinite,file["x"][:,first:min(first+31,length(t))]) || error("Nonfinite stored state")
            end
        end
        receipt=JSON.parsefile(path*".json");receipt["physical_gates_passed"] || error("Missing physical certificate")
    end
    all(counts[k]==v for (k,v) in cfg["initial_conditions"]["counts"]) || error("Incomplete trajectory population")
    saved=JLD2.load(joinpath(release,"train_normalizer.jld2"),"normalizer")
    recomputed=fit_train_normalizer(release,manifest["trajectories"],2length(m.active))
    saved["mean"]==recomputed["mean"] && saved["std"]==recomputed["std"] || error("Train-only normalizer mismatch")
    if published
        root=JSON.parsefile(joinpath(release,"release_manifest.json"))
        root["qualification_status"]==expected || error("Release qualification label mismatch")
        root["status"]==(partial_qualification(cfg) ? "dataset-generated-partial-qualification" : "dataset-qualified") || error("Release status overstates qualification")
        filehash(joinpath(release,"artifact_manifest.json"))==root["artifact_manifest_sha256"] || error("Catalog integrity")
        for (relative,hash) in JSON.parsefile(joinpath(release,"artifact_manifest.json"))
            filehash(joinpath(release,relative))==hash || error("Artifact integrity: $relative")
        end
    end
    return Dict("status"=>"passed","counts"=>counts,"frames"=>cfg["sampling"]["frames"])
end

function run_stage(stage,cfg;gmsh="gmsh")
    folder=joinpath(ROOT,"runs",cfg["release_id"])
    if stage=="verify"
        # Readback uses the producing configuration, not later notebook edits.
        cfg=load_config(joinpath(folder,"source_snapshot",portable_relative(cfg["_config_path"],ROOT)))
    else
        bind_inputs(folder,cfg)
    end
    # A directory lock prevents concurrent writers without touching other experiments.
    lockpath=joinpath(folder,"execution.lock")
    ispath(lockpath) && error("Execution lock exists: $lockpath")
    mkdir(lockpath)
    try
        if stage=="prepare"
            return prepare_models(folder,cfg,gmsh)
        end
        models=load_models(folder;candidate_only=partial_qualification(cfg))
        if stage=="qualify"
            partial_qualification(cfg) && error("User suspended further independent qualification")
            return qualify_campaign(folder,models,cfg)
        elseif stage=="generate"
            return generate_population(folder,models["candidate"],cfg)
        elseif stage=="verify"
            return verify_release(joinpath(ROOT,"data","releases",cfg["release_id"]),models["candidate"],cfg)
        end
        error("Unknown stage $stage")
    catch exception
        writejson(joinpath(folder,"failure_$(time_ns()).json"),Dict("stage"=>stage,
            "status"=>"failed","error"=>sprint(showerror,exception),"config_sha256"=>cfg["_config_sha256"]))
        rethrow()
    finally
        rm(lockpath) # Empty lock only; generated data and failed partials are retained.
    end
end
