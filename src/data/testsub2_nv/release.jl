function write_json(path,data)
    mkpath(dirname(path))
    open(path*".tmp","w") do io;JSON.print(io,data,2);end
    mv(path*".tmp",path;force=true)
    return path
end

file_sha(path)=bytes2hex(open(sha256,path))

function stable_rng(parts...)
    hash=sha256(join(string.(parts),"/"))
    seed=zero(UInt64)
    for b in hash[1:8];seed=(seed<<8)|UInt64(b);end
    return Xoshiro(seed)
end

function initial_conditions(m;resource="CAN")
    result=NamedTuple[]
    static=m.id=="VK-BEAM-CC" || m.configuration=="NR"
    if static
        amplitudes=m.id=="VK-BEAM-CC" ?
            Dict("train"=>[0.0015,0.002,0.0025],"val"=>[0.0018],"test"=>[0.0016,0.0022]) :
            Dict("train"=>[0.0105,0.012,0.0135],"val"=>[0.011],"test"=>[0.010,0.0125])
        resource=="QUAL" && (amplitudes=Dict("qual"=>[m.id=="VK-BEAM-CC" ? 0.0023 : 0.0128]))
        for split in sort!(collect(keys(amplitudes))), (i,amp) in enumerate(amplitudes[split])
            q,load,res=static_release(m,amp)
            push!(result,(split=split,id="$(resource)_$(split)_$(lpad(i,3,'0'))",q=q,
                meta=Dict{String,Any}("ic_family"=>"static","probe_amplitude"=>amp,
                    "static_point_load_N"=>load,"static_relative_residual"=>res,
                    "initial_amplitudes"=>[amp],"modal_mixture_coefficients"=>Float64[])))
        end
        return result
    end
    ode=m.id=="OSC-DUFFING8";targets=ode ? [1,2,3] : m.id=="VK-PLATE-SQUARE" ? [2,3] : [1,2]
    nf=length(targets)+1
    budgets=resource=="QUAL" ? [("qual",nf)] : [("train",3nf),("val",nf),("test",nf)]
    for (split,count) in budgets, i in 1:count
        family=mod1(i,nf);level=cld(i,nf)
        rng=stable_rng("TestSub2-NV-20261004",m.id,m.configuration,resource,split,i,
            family,level,"mixture","clean")
        coeff=family==nf ? 0.25 .+ rand(rng,length(targets)) : Float64.(collect(1:length(targets)).==family)
        coeff./=norm(coeff)
        direction=m.modes[:,targets]*coeff
        if ode
            exposure=split=="train" ? [0.01,0.07,0.20][level] : split=="val" ? 0.045 : split=="test" ? 0.135 : 0.11
            if family==nf;exposure*=0.96+0.08rand(rng);end
            alpha=m.kernel.alpha
            amplitude=sqrt(exposure*norm((m.K*direction)./m.qscale)/norm((alpha.*direction.^3)./m.qscale))
            q=amplitude.*direction
            meta=Dict{String,Any}("target_initial_nonlinear_exposure"=>exposure)
        else
            # Reference displacements are a few millimetres; CAN amplitude levels
            # and all split-specific positive mixtures are declared before solving.
            anchor=m.id=="VK-PLATE-SQUARE" ? 0.006 : 0.004
            factor=split=="train" ? [0.6,0.8,1.0][level] : split=="val" ? 0.9 : split=="test" ? 0.98 : 1.04
            amplitude=anchor*factor
            q=amplitude.*direction./maximum(abs.(direction[m.translations]))
            meta=Dict{String,Any}("maximum_initial_translation_m"=>amplitude,
                "amplitude_calibration"=>"predeclared CAN physical displacement; source anchor, not strict replay")
        end
        meta["ic_family"]=family==nf ? "modal_mixture" : "mode"
        meta["target_modes"]=targets;meta["modal_mixture_coefficients"]=coeff
        meta["initial_amplitudes"]=[amplitude];meta["amplitude_level"]=level
        f=zeros(m.n);nonlinear!(f,m.kernel,q)
        meta["initial_nonlinear_exposure"]=norm(f./m.qscale)/max(norm((m.K*q)./m.qscale),eps())
        push!(result,(split=split,id="$(resource)_$(split)_$(lpad(i,3,'0'))",q=q,meta=meta))
    end
    return result
end

function solve_certified(m,ic,cfg,folder,binding)
    canonical=ic.split in ("train","val","test")
    relative=canonical ? joinpath("can","clean",ic.split,ic.id*".jld2") :
        joinpath("qualification",ic.id*".jld2")
    statepath=joinpath(folder,relative)
    certificate=joinpath(folder,"qualification",ic.id*"_certificate.json")
    if isfile(certificate) && isfile(statepath)
        previous=JSON.parsefile(certificate)
        if get(previous,"binding","")==binding && get(previous,"passed",false) &&
                get(previous,"state_sha256","")==file_sha(statepath)
            println("REUSE ",m.id,"/",m.configuration," ",ic.id);flush(stdout)
            return Dict{String,Any}(previous)
        end
    end
    println("SOLVE_START ",m.id,"/",m.configuration," ",ic.id);flush(stdout)
    base=cfg["baseline"];fine=cfg["fine"]
    a=integrate(m,ic.q;periods=cfg["periods"],samples_per_period=cfg["samples_per_period"],
        reltol=base["reltol"],abstol=base["abstol"],max_step_fraction=base["max_step_fraction"],label=ic.id*":base")
    println("BASE_DONE ",m.id,"/",m.configuration," ",ic.id," seconds=",a.diagnostics["wall_seconds"],
        " steps=",a.diagnostics["accepted_steps"]);flush(stdout)
    b=integrate(m,ic.q;periods=cfg["periods"],samples_per_period=cfg["samples_per_period"],
        reltol=fine["reltol"],abstol=fine["abstol"],max_step_fraction=fine["max_step_fraction"],label=ic.id*":fine")
    state_error=compare_trajectories(m,a,b)
    passed=state_error<=cfg["maximum_scaled_state_error"] &&
        max(a.diagnostics["energy_balance_relative"],b.diagnostics["energy_balance_relative"])<=cfg["maximum_relative_energy_balance_error"] &&
        b.diagnostics["minimum_damping_power"]>=-1e-12
    cert=Dict{String,Any}("trajectory_id"=>ic.id,"split"=>ic.split,"binding"=>binding,
        "passed"=>passed,"scaled_state_error"=>state_error,
        "baseline"=>a.diagnostics,"fine"=>b.diagnostics,"state_path"=>replace(relative,'\\'=>'/'),
        "snapshot_count"=>length(b.t),"state_dimension"=>2m.n)
    mkpath(dirname(certificate))
    if !passed
        write_json(certificate,cert)
        error("Qualification failed $(m.id)/$(m.configuration)/$(ic.id): state=$state_error energy=$(b.diagnostics["energy_balance_relative"])")
    end
    mkpath(dirname(statepath))
    jldopen(statepath*".tmp","w") do f
        f["x"]=b.x;f["t"]=b.t;f["trajectory_id"]=ic.id;f["split"]=ic.split
        f["state_layout"]="rows=[all q; all v], columns=time; active DOFs in node order"
        f["units"]=m.metadata["units"]
    end
    mv(statepath*".tmp",statepath;force=true)
    auditdir=joinpath(folder,"audit_only","energy");mkpath(auditdir)
    jldopen(joinpath(auditdir,ic.id*".jld2"),"w") do f
        f["energy"]=b.energy;f["dissipated"]=b.dissipated;f["damping_power"]=b.power
    end
    metadata=merge(copy(ic.meta),Dict("trajectory_id"=>ic.id,"object_id"=>m.id,
        "configuration_id"=>m.configuration,"resource"=>canonical ? "CAN" : "QUAL",
        "split"=>ic.split,"reference_period"=>2pi/m.omega[m.reference_mode],
        "dt_output"=>b.t[2]-b.t[1],"snapshot_count"=>length(b.t),"state_layout"=>"col(q,v)",
        "physical_units"=>m.metadata["units"],"mesh_id"=>m.metadata["mesh_id"],
        "noise_view"=>"clean","qualification_certificate"=>relpath(certificate,folder)))
    write_json(joinpath(folder,"audit_only","trajectory_manifests",ic.id*".json"),metadata)
    cert["state_sha256"]=file_sha(statepath)
    write_json(certificate,cert)
    println("QUALIFIED ",m.id,"/",m.configuration," ",ic.id," state_error=",state_error,
        " energy=",b.diagnostics["energy_balance_relative"]," seconds=",a.diagnostics["wall_seconds"]+b.diagnostics["wall_seconds"]);flush(stdout)
    return cert
end

function train_normalizer(folder,certificates,m)
    total=zeros(2m.n);square=zeros(2m.n);count=0
    for cert in certificates
        cert["split"]=="train" || continue
        x=jldopen(joinpath(folder,cert["state_path"]),"r") do f;f["x"];end
        total .+= vec(sum(x;dims=2));square .+= vec(sum(abs2,x;dims=2));count+=size(x,2)
    end
    mu=total./count;std=sqrt.(max.(square./count.-mu.^2,0.))
    floor=1e-12.*vcat(m.qscale,m.omega[m.reference_mode].*m.qscale)
    std=max.(std,floor)
    jldopen(joinpath(folder,"can","train_normalizer.jld2"),"w") do f
        f["mean"]=mu;f["scale"]=std;f["fitted_split"]="train";f["snapshot_count"]=count
        f["convention"]="population standard deviation with fixed physical scale floor; raw states unchanged"
    end
end

function load_learner_view(folder,trajectory_id)
    folder=abspath(folder)
    manifest=JSON.parsefile(joinpath(folder,"manifests","learner_manifest.json"))
    files=filter(row->row["trajectory_id"]==trajectory_id,manifest["trajectories"])
    length(files)==1 || error("Unknown or non-learner trajectory")
    row=only(files);path=normpath(joinpath(folder,row["path"]))
    isabspath(row["path"]) && error("Absolute manifest path rejected")
    rel=relpath(path,abspath(folder))
    startswith(rel,"..") && error("Path escape rejected")
    startswith(replace(rel,'\\'=>'/'),"can/clean/") || error("Audit access rejected")
    file_sha(path)==row["sha256"] || error("Trajectory checksum mismatch")
    return jldopen(path,"r") do f
        Dict(key=>f[key] for key in ("x","t","trajectory_id","split","state_layout","units"))
    end
end
