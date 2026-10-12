# SPDX-License-Identifier: GPL-3.0-only
function initial_state(m,family,target,rng,cfg)
    indices=cfg["initial_conditions"]["families"][family]
    if isempty(indices)
        q,load=static_release(m,target,cfg)
        return q,Dict("family"=>family,"kind"=>"static_release","load_N"=>load,"amplitude_m"=>target)
    end
    coefficients=length(indices)==1 ? [1.] : [rand(rng,Bool) ? 0.5+rand(rng) : -0.5-rand(rng) for _ in indices]
    # Normalize each shape by physical translation amplitude before mixing.
    shapes=hcat([m.modes[:,i]/amplitude(m,m.modes[:,i]) for i in indices]...)
    q=shapes*coefficients
    factor=target/amplitude(m,q);q*=factor
    return q,Dict("family"=>family,"kind"=>"modal_displacement","modes"=>indices,
        "physical_shape_coefficients_m"=>coefficients*factor,"amplitude_m"=>target)
end

function ensure_trajectory(path,m,q,cfg;kwargs...)
    # A frozen run fingerprint is enforced by run_stage; IC and stage identifiers
    # additionally prevent accidentally reusing another completed trajectory.
    key=bytes2hex(sha256(reinterpret(UInt8,q)))
    if isfile(path)
        receipt=JSON.parsefile(path*".json")
        receipt["sha256"]==filehash(path) || error("Trajectory checksum mismatch")
        receipt["initial_state_sha256"]==key || error("Reused trajectory has a different initial state")
        receipt["frames"]==get(kwargs,:frames,cfg["sampling"]["frames"]) || error("Cached frame count mismatch")
        receipt["dt_seconds"]==get(kwargs,:dt,cfg["sampling"]["dt_seconds"]) || error("Cached output interval mismatch")
        receipt["substeps"]==get(kwargs,:substeps,cfg["solver"]["substeps"]) || error("Cached substep count mismatch")
        receipt["linear"]==get(kwargs,:linear,false) || error("Cached model type mismatch")
        return receipt
    end
    receipt=integrate_to_file(path,m,q,cfg;kwargs...)
    receipt["initial_state_sha256"]=key
    writejson(path*".json",receipt)
    return receipt
end

function derivative_checks(m,q,cfg)
    backend=CPUBackend(m);evaluate!(backend,m,q)
    direction=m.qscale.*sin.(collect(1:length(q)))
    direction./=norm(direction./m.qscale)
    h=1e-6*max(norm(q./m.qscale),1e-5)
    analytic=backend.tangent*direction
    plus=CPUBackend(m);minus=CPUBackend(m)
    evaluate!(plus,m,q+h*direction;tangent=false)
    evaluate!(minus,m,q-h*direction;tangent=false)
    difference=(plus.force-minus.force)/(2h)
    tangent_error=norm(difference-analytic)/max(norm(analytic),eps())
    total_force=m.K*q+backend.force
    energy_derivative=(potential(m,q+h*direction)-potential(m,q-h*direction))/(2h)
    energy_error=abs(energy_derivative-dot(total_force,direction))/max(abs(dot(total_force,direction)),1e-10)
    tangent_error<1e-5 && energy_error<1e-5 || error("Finite-element derivative checks failed")
    zero=CPUBackend(m);zeroq=zeros(length(q));evaluate!(zero,m,zeroq)
    norm(zero.force)==0 && norm(zero.tangent)==0 || error("Nonzero nonlinear force/tangent at reference")
    return Dict("tangent_relative"=>tangent_error,"energy_gradient_relative"=>energy_error)
end

function choose_backend(m,q,cfg,folder)
    preference=cfg["compute"]["backend"]
    if preference=="cpu" || !isdefined(@__MODULE__,:GPUBackend) || !CUDA.functional()
        preference=="gpu" && error("GPU backend was requested but could not be loaded")
        writejson(joinpath(folder,"backend.json"),Dict("selected"=>"cpu","reason"=>"CPU requested or CUDA unavailable"))
        return CPUBackend(m)
    end
    gpu,receipt=benchmark_gpu(m,q,cfg)
    selected=preference=="gpu" || receipt["newmark_cpu_seconds"]>=cfg["compute"]["minimum_gpu_speedup"]*receipt["newmark_gpu_seconds"]
    receipt["selected"]=selected ? "gpu" : "cpu"
    receipt["timing_scope"]="element timings plus eight internal Newmark steps including transfers and CPU sparse solves; warmed, no disk IO"
    writejson(joinpath(folder,"backend.json"),receipt)
    return selected ? gpu : CPUBackend(m)
end

function qualify_time(folder,m,q,cfg,backend)
    maximum_substeps=cfg["solver"]["maximum_qualification_substeps"]
    base=cfg["solver"]["substeps"]
    attempts=Any[]
    while 2base<=maximum_substeps
        p0=joinpath(folder,"substeps_$base.h5");p1=joinpath(folder,"substeps_$(2base).h5")
        r0=ensure_trajectory(p0,m,q,cfg;backend,substeps=base)
        r1=ensure_trajectory(p1,m,q,cfg;backend,substeps=2base)
        state_error=trajectory_difference(p0,p1,m)
        passed=state_error<=cfg["qualification"]["temporal_state_relative"] &&
            r1["max_energy_balance_relative"]<=cfg["qualification"]["energy_balance_relative"]
        push!(attempts,Dict("base_substeps"=>base,"fine_substeps"=>2base,"state_error"=>state_error,
            "fine_energy_balance"=>r1["max_energy_balance_relative"],"passed"=>passed))
        writejson(joinpath(folder,"time_refinement.json"),attempts)
        passed && return 2base,p1,r1,state_error
        base*=2
    end
    error("Time refinement failed at configured maximum; no tolerance is relaxed")
end

"""Hann-windowed full-state spectrum, accumulated in small channel blocks."""
function effective_frequency(path,m,tail_fraction)
    HDF5.h5open(path,"r") do file
        nframes=size(file["x"],2);times=read(file["t"]);dt=times[2]-times[1]
        window=0.5 .- 0.5cos.(2pi.*(0:nframes-1)./(nframes-1))
        power=zeros(nframes÷2+1);scales=vcat(m.qscale,m.omega[1].*m.qscale)
        for first in 1:64:length(scales)
            rows=first:min(first+63,length(scales));x=file["x"][rows,:]./scales[rows]
            x.-=mean(x;dims=2);x.*=window'
            spectrum=FFTW.rfft(x,2)
            power .+= vec(sum(abs2,spectrum;dims=1))
        end
        power[1]=0.;sum(power)>0 || error("No dynamic spectral power")
        index=searchsortedfirst(cumsum(power),(1-tail_fraction)*sum(power))
        return 2pi*(index-1)/(nframes*dt)
    end
end

function spatial_linear_checks(candidate,fine,cfg)
    indices=unique(round.(Int,range(1,size(candidate.mesh.nodes,1);length=min(160,size(candidate.mesh.nodes,1)))))
    coordinates=candidate.mesh.nodes[indices,:]
    A,da=interpolation(candidate.mesh,coordinates);B,db=interpolation(fine.mesh,coordinates)
    maximum(db)<=cfg["qualification"]["maximum_mapping_distance_m"] || error("Geometric interpolation distance")
    translation_rows=[6(i-1)+d for i in eachindex(indices) for d in 1:3]
    A=A[translation_rows,candidate.active];B=B[translation_rows,fine.active]
    U=A*candidate.modes[:,1:4];V=B*fine.modes
    used=Set{Int}();rows=Any[]
    for i in 1:4
        mac=[abs2(dot(U[:,i],V[:,j]))/(sum(abs2,U[:,i])*sum(abs2,V[:,j])) for j in axes(V,2)]
        for j in used;mac[j]=-Inf;end
        j=argmax(mac);push!(used,j)
        frequency=abs(candidate.omega[i]/fine.omega[j]-1)
        push!(rows,Dict("candidate_mode"=>i,"fine_mode"=>j,"mac"=>mac[j],"frequency_relative"=>frequency))
    end
    static_a=A*(candidate.K\preload(candidate));static_b=B*(fine.K\preload(fine))
    static_error=norm(static_a-static_b)/norm(static_b)
    passed=all(r["mac"]>=cfg["qualification"]["minimum_mac"] &&
        r["frequency_relative"]<=cfg["qualification"]["frequency_relative"] for r in rows) &&
        static_error<=cfg["qualification"]["static_relative"]
    return Dict("passed"=>passed,"modal_comparison"=>rows,"static_relative"=>static_error,
        "maximum_mapping_distance_m"=>maximum(db)),A,B
end

function qualify_campaign(folder,models,cfg)
    m=models["candidate"];qfolder=joinpath(folder,"qualification");mkpath(qfolder)
    # Fail early on spatial accuracy before expensive trajectory generation.
    maps=Dict{String,Any}()
    for name in ("fine1","fine2")
        receipt,A,B=spatial_linear_checks(m,models[name],cfg)
        writejson(joinpath(qfolder,"spatial_$name.json"),receipt)
        receipt["passed"] || error("Candidate mesh failed spatial linear screening against $name")
        maps[name]=(A,B)
    end
    # Independently screen all proposed directions at each physical amplitude.
    screened=Float64[];screening=Any[]
    for amplitude in cfg["initial_conditions"]["amplitude_candidates_m"]
        strain=0.;failure=nothing
        for family in 1:12
            try
                q,_=initial_state(m,family,amplitude,Xoshiro(9000+family),cfg)
                b=CPUBackend(m);d=evaluate!(b,m,q;tangent=false);strain=max(strain,d.strain)
            catch exception
                exception isa InterruptException && rethrow()
                failure=sprint(showerror,exception);break
            end
        end
        passed=failure===nothing && strain<=cfg["initial_conditions"]["maximum_strain_component"]
        push!(screening,Dict("amplitude_m"=>amplitude,"maximum_recovered_strain_component"=>strain,"passed"=>passed,"failure"=>failure))
        passed && push!(screened,amplitude)
    end
    writejson(joinpath(qfolder,"amplitude_screening.json"),screening)
    isempty(screened) && error("No amplitude passed strain screening")
    Amax=maximum(screened)
    qref,_=initial_state(m,11,0.7Amax,Xoshiro(9011),cfg)
    writejson(joinpath(qfolder,"derivatives.json"),derivative_checks(m,qref,cfg))
    backend=choose_backend(m,qref,cfg,qfolder)
    cases=[(1,0.10),(1,0.80),(11,0.80),(12,0.80)]
    cases_receipts=Any[];selected_substeps=cfg["solver"]["substeps"];nonlinear_max=0.;omega_effective=0.;spatial_max=0.
    lifts=Dict(name=>interpolation(m.mesh,models[name].mesh.nodes)[1] for name in ("fine1","fine2"))
    for (number,(family,level)) in enumerate(cases)
        q,metadata=initial_state(m,family,level*Amax,Xoshiro(19000+family),cfg)
        casefolder=joinpath(qfolder,"case_$number");mkpath(casefolder)
        steps,path,receipt,time_error=qualify_time(casefolder,m,q,cfg,backend)
        if number==1 && !(backend isa CPUBackend)
            cpupath=joinpath(casefolder,"cpu_reference.h5")
            ensure_trajectory(cpupath,m,q,cfg;substeps=steps)
            device_error=trajectory_difference(cpupath,path,m)
            writejson(joinpath(casefolder,"cpu_gpu_trajectory.json"),Dict("relative"=>device_error))
            device_error<=cfg["qualification"]["temporal_state_relative"]/10 || error("CPU/GPU trajectory disagreement")
        end
        selected_substeps=max(selected_substeps,steps)
        receipt["final_energy_ratio"]<=cfg["qualification"]["end_energy_fraction"] || error("QUAL terminal energy gate")
        receipt["max_recovered_strain_component"]<=cfg["initial_conditions"]["maximum_strain_component"] || error("QUAL dynamic strain gate")
        linearpath=joinpath(casefolder,"linear.h5")
        ensure_trajectory(linearpath,m,q,cfg;substeps=steps,linear=true)
        nonlinear=trajectory_difference(linearpath,path,m);nonlinear_max=max(nonlinear_max,nonlinear)
        # A double-rate full-state output checks spectral content above the release band.
        spectralpath=joinpath(casefolder,"double_rate.h5")
        ensure_trajectory(spectralpath,m,q,cfg;backend,substeps=steps,
            frames=2(cfg["sampling"]["frames"]-1)+1,dt=cfg["sampling"]["dt_seconds"]/2)
        measured=effective_frequency(spectralpath,m,cfg["qualification"]["spectrum_power_tail_fraction"])
        omega_effective=max(omega_effective,measured)
        for name in ("fine1","fine2")
            fine=models[name]
            lift=lifts[name]
            qfine=(lift*full_coordinates(m,q))[fine.active]
            fpath=joinpath(casefolder,"$(name).h5")
            fine_steps,fpath,fine_receipt,_=qualify_time(joinpath(casefolder,name),fine,qfine,cfg,CPUBackend(fine))
            A,B=maps[name]
            discrepancy=trajectory_difference(path,fpath,m;map_a=A,map_b=B)
            spatial_max=max(spatial_max,discrepancy)
            writejson(joinpath(casefolder,"space_$(name).json"),Dict("relative"=>discrepancy,
                "fine_substeps"=>fine_steps,"initialization"=>"all six global nodal coordinates interpolated from candidate"))
            discrepancy<=cfg["qualification"]["spatial_trajectory_relative"] || error("Nonlinear spatial refinement failed")
        end
        push!(cases_receipts,Dict("family"=>family,"level"=>level,"initial_state"=>metadata,
            "initial_state_sha256"=>bytes2hex(sha256(reinterpret(UInt8,q))),"substeps"=>steps,
            "time_error"=>time_error,"nonlinear_difference"=>nonlinear,"effective_omega"=>measured))
        writejson(joinpath(qfolder,"cases.json"),cases_receipts)
    end
    nonlinear_max>=cfg["qualification"]["minimum_nonlinear_difference"] || error("Insufficient nonlinear exposure")
    nonlinear_max>=cfg["qualification"]["nonlinear_to_error_ratio"]*max(spatial_max,maximum(r["time_error"] for r in cases_receipts)) || error("Nonlinearity is unresolved relative to spatial/time error")
    permitted=2pi/(cfg["sampling"]["minimum_samples_per_effective_cycle"]*omega_effective)
    cfg["sampling"]["dt_seconds"]<=min(2pi/(64m.omega[1]),permitted) || error("Release sampling does not resolve QUAL effective band")
    # Persist all meshes/source receipts used in qualification, outside the learner view.
    result=Dict("status"=>"qualified","config_sha256"=>cfg["_config_sha256"],
        "models_sha256"=>filehash(joinpath(folder,"models.json")),
        "inputs_sha256"=>filehash(joinpath(folder,"input_fingerprint.json")),
        "amplitude_max_m"=>Amax,"substeps"=>selected_substeps,"effective_omega"=>omega_effective,
        "cases"=>cases_receipts,"backend"=>JSON.parsefile(joinpath(qfolder,"backend.json"))["selected"],
        "physics"=>"full-state unforced nonlinear elastic shell; no modal truncation")
    writejson(joinpath(qfolder,"qualified.json"),result)
    return result
end
