# SPDX-License-Identifier: GPL-3.0-only
function initial_state(m,family,target,rng,cfg)
    indices=cfg["initial_conditions"]["families"][family]
    if isempty(indices)
        trace=Any[]
        q,load=static_release(m,target,cfg;trace)
        return q,Dict("family"=>family,"kind"=>"static_release","load_N"=>load,
            "amplitude_m"=>target,"static_newton"=>trace)
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
    receipt["integrator"]=get(cfg["solver"],"integrator","newmark")
    receipt["timing_scope"]="element timings plus eight internal integration steps including transfers and CPU sparse solves; warmed, no disk IO"
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
        push!(rows,Dict("candidate_mode"=>i,"fine_mode"=>j,"mac"=>mac[j],"frequency_relative"=>frequency,
            "fine_mode_sign"=>sign(dot(U[:,i],V[:,j]))))
    end
    static_a=A*(candidate.K\preload(candidate));static_b=B*(fine.K\preload(fine))
    static_error=norm(static_a-static_b)/norm(static_b)
    passed=all(r["mac"]>=cfg["qualification"]["minimum_mac"] &&
        r["frequency_relative"]<=cfg["qualification"]["frequency_relative"] for r in rows) &&
        static_error<=cfg["qualification"]["static_relative"]
    return Dict("passed"=>passed,"modal_comparison"=>rows,"static_relative"=>static_error,
        "maximum_mapping_distance_m"=>maximum(db)),A,B
end

function matched_initial_state(fine,metadata,spatial,cfg)
    if metadata["kind"]=="static_release"
        q,load=static_release(fine,metadata["amplitude_m"],cfg)
        return q,Dict("method"=>"same physical preload shape and displacement amplitude, independent nonlinear static equilibrium",
            "load_N"=>load)
    end
    q=zeros(length(fine.active))
    for (mode,coefficient) in zip(metadata["modes"],metadata["physical_shape_coefficients_m"])
        row=only(filter(r->r["candidate_mode"]==mode,spatial["modal_comparison"]))
        shape=fine.modes[:,row["fine_mode"]]
        q.+=row["fine_mode_sign"]*coefficient.*shape./amplitude(fine,shape)
    end
    return q,Dict("method"=>"same physical coefficients in MAC-matched full-FE initial shapes; every DOF is integrated",
        "amplitude_m"=>amplitude(fine,q))
end

function qualify_campaign(folder,models,cfg)
    m=models["candidate"];qfolder=joinpath(folder,"qualification");mkpath(qfolder)
    # Fail early on spatial accuracy before expensive trajectory generation.
    maps=Dict{String,Any}();spatial_receipts=Dict{String,Any}()
    response_assessment=get(cfg["qualification"],"spatial_assessment","raw_pointwise")=="modal_response"
    for name in ("fine1","fine2")
        println("NACA_QUAL_SPATIAL_LINEAR ",name);flush(stdout)
        receipt,A,B=spatial_linear_checks(m,models[name],cfg)
        writejson(joinpath(qfolder,"spatial_$name.json"),receipt)
        receipt["passed"] || error("Candidate mesh failed spatial linear screening against $name")
        maps[name]=(A,B)
        spatial_receipts[name]=receipt
    end
    # Independently screen all proposed directions at each physical amplitude.
    screened=Float64[];screening=Any[]
    for amplitude in cfg["initial_conditions"]["amplitude_candidates_m"]
        println("NACA_QUAL_AMPLITUDE ",amplitude);flush(stdout)
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
    println("NACA_QUAL_BACKEND amplitude_max_m=",Amax);flush(stdout)
    backend=choose_backend(m,qref,cfg,qfolder)
    cases=haskey(cfg["qualification"],"cases") ?
        [(Int(row["family"]),Float64(row["level"])) for row in cfg["qualification"]["cases"]] :
        [(1,0.10),(1,0.80),(11,0.80),(12,0.80)]
    cases_receipts=Any[];selected_substeps=cfg["solver"]["substeps"];nonlinear_max=0.;omega_effective=0.;spatial_max=0.
    spatial_cases=get(cfg["qualification"],"spatial_cases",collect(eachindex(cases)))
    lifts=response_assessment ? nothing : Dict(name=>interpolation(m.mesh,models[name].mesh.nodes)[1] for name in ("fine1","fine2"))
    fine_backends=Dict{String,Any}();feature_error_max=0.;energy_signal_max=0.;feature_time_max=0.
    for (number,(family,level)) in enumerate(cases)
        println("NACA_QUAL_CASE ",number," family=",family);flush(stdout)
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
        coarse_features=nothing;linear_features=nothing;feature_time_error=nothing;energy_signal=nothing
        if response_assessment
            coarse_features=mechanical_features(path,m);linear_features=mechanical_features(linearpath,m)
            base_features=mechanical_features(joinpath(casefolder,"substeps_$(steps÷2).h5"),m)
            width=max(1,round(Int,2pi/(maximum(m.omega[1:4])*cfg["sampling"]["dt_seconds"])))
            differences=centered_average((base_features.modal_energy-coarse_features.modal_energy)./coarse_features.energy[1],width)
            feature_time_error=maximum(norm(view(differences,:,k)) for k in axes(differences,2))
            signal=nonlinear_energy_features(coarse_features,linear_features,width)
            energy_signal=maximum(norm(view(signal,:,k)) for k in axes(signal,2))
            feature_time_max=max(feature_time_max,feature_time_error)
            number in spatial_cases && (energy_signal_max=max(energy_signal_max,energy_signal))
        end
        # A double-rate full-state output checks spectral content above the release band.
        spectralpath=joinpath(casefolder,"double_rate.h5")
        ensure_trajectory(spectralpath,m,q,cfg;backend,substeps=max(1,steps÷2),
            frames=2(cfg["sampling"]["frames"]-1)+1,dt=cfg["sampling"]["dt_seconds"]/2)
        measured=effective_frequency(spectralpath,m,cfg["qualification"]["spectrum_power_tail_fraction"])
        omega_effective=max(omega_effective,measured)
        for name in (number in spatial_cases ? ("fine1","fine2") : ())
            fine=models[name]
            qfine,initialization=if response_assessment
                matched_initial_state(fine,metadata,spatial_receipts[name],cfg)
            else
                (lifts[name]*full_coordinates(m,q))[fine.active],Dict("method"=>"piecewise-linear interpolation of all six nodal coordinates")
            end
            A,B=maps[name]
            initial_error=norm(A*q-B*qfine)/max(norm(A*q),eps())
            response_assessment && initial_error>cfg["qualification"]["initial_shape_relative"] && error("Cross-grid initial physical shape mismatch")
            writejson(joinpath(casefolder,"initial_$(name).json"),Dict("relative_physical_shape"=>initial_error,"construction"=>initialization))
            if !haskey(fine_backends,name)
                fine_backends[name]=choose_backend(fine,qfine,cfg,joinpath(qfolder,"backend_"*name))
            end
            fine_backend=fine_backends[name]
            fine_steps,fpath,fine_receipt,_=qualify_time(joinpath(casefolder,name),fine,qfine,cfg,fine_backend)
            fine_receipt["max_recovered_strain_component"]<=cfg["initial_conditions"]["maximum_strain_component"] || error("Fine reference dynamic strain gate")
            fine_receipt["final_energy_ratio"]<=cfg["qualification"]["end_energy_fraction"] || error("Fine reference terminal energy gate")
            discrepancy=trajectory_difference(path,fpath,m;map_a=A,map_b=B)
            spatial_max=max(spatial_max,discrepancy)
            spatial_result=Dict{String,Any}("raw_same_clock_state_relative"=>discrepancy,
                "fine_substeps"=>fine_steps,"initialization"=>initialization)
            if response_assessment
                fine_linear_path=joinpath(casefolder,name,"linear.h5")
                ensure_trajectory(fine_linear_path,fine,qfine,cfg;backend=fine_backend,substeps=fine_steps,linear=true)
                indices=Int[row["fine_mode"] for row in spatial_receipts[name]["modal_comparison"]]
                ff=mechanical_features(fpath,fine;mode_indices=indices)
                fl=mechanical_features(fine_linear_path,fine;mode_indices=indices)
                response=response_convergence(coarse_features,linear_features,ff,fl,m,fine,cfg)
                spatial_result["response"]=response
                feature_error_max=max(feature_error_max,response["nonlinear_energy_feature_error"])
                writejson(joinpath(casefolder,"space_$(name).json"),spatial_result)
                response["passed"] || error("Nonlinear frequency/envelope/energy spatial qualification failed")
            else
                writejson(joinpath(casefolder,"space_$(name).json"),spatial_result)
                discrepancy<=cfg["qualification"]["spatial_trajectory_relative"] || error("Nonlinear spatial refinement failed")
            end
        end
        push!(cases_receipts,Dict("family"=>family,"level"=>level,"initial_state"=>metadata,
            "initial_state_sha256"=>bytes2hex(sha256(reinterpret(UInt8,q))),"substeps"=>steps,
            "time_error"=>time_error,"nonlinear_difference"=>nonlinear,"effective_omega"=>measured,
            "nonlinear_energy_signal"=>energy_signal,"temporal_energy_feature_error"=>feature_time_error))
        writejson(joinpath(qfolder,"cases.json"),cases_receipts)
    end
    nonlinear_max>=cfg["qualification"]["minimum_nonlinear_difference"] || error("Insufficient nonlinear exposure")
    if response_assessment
        energy_signal_max>=cfg["qualification"]["minimum_nonlinear_energy_transfer"] || error("Insufficient dynamic nonlinear energy transfer")
        energy_signal_max>=cfg["qualification"]["nonlinear_to_error_ratio"]*max(feature_error_max,feature_time_max) || error("Nonlinear energy transfer is unresolved relative to grid/time error")
    else
        nonlinear_max>=cfg["qualification"]["nonlinear_to_error_ratio"]*max(spatial_max,maximum(r["time_error"] for r in cases_receipts)) || error("Nonlinearity is unresolved relative to spatial/time error")
    end
    permitted=2pi/(cfg["sampling"]["minimum_samples_per_effective_cycle"]*omega_effective)
    cfg["sampling"]["dt_seconds"]<=min(2pi/(64m.omega[1]),permitted) || error("Release sampling does not resolve QUAL effective band")
    # Persist all meshes/source receipts used in qualification, outside the learner view.
    result=Dict("status"=>"qualified","config_sha256"=>cfg["_config_sha256"],
        "models_sha256"=>filehash(joinpath(folder,"models.json")),
        "inputs_sha256"=>filehash(joinpath(folder,"input_fingerprint.json")),
        "amplitude_max_m"=>Amax,"substeps"=>selected_substeps,"effective_omega"=>omega_effective,
        "cases"=>cases_receipts,"backend"=>JSON.parsefile(joinpath(qfolder,"backend.json"))["selected"],
        "spatial_assessment"=>get(cfg["qualification"],"spatial_assessment","raw_pointwise"),
        "raw_same_clock_state_relative_max"=>spatial_max,
        "nonlinear_energy_signal_max"=>(response_assessment ? energy_signal_max : nothing),
        "nonlinear_energy_spatial_error_max"=>(response_assessment ? feature_error_max : nothing),
        "nonlinear_energy_temporal_error_max"=>(response_assessment ? feature_time_max : nothing),
        "physics"=>"full-state unforced nonlinear elastic shell; no modal truncation")
    writejson(joinpath(qfolder,"qualified.json"),result)
    return result
end
