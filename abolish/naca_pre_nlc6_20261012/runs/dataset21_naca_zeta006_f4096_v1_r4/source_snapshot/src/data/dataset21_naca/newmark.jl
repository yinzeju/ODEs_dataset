# SPDX-License-Identifier: GPL-3.0-only
mutable struct StepStatistics
    steps::Int
    newton_iterations::Int
    subdivisions::Int
    max_residual::Float64
end
StepStatistics()=StepStatistics(0,0,0,0.)

function newmark_step(m,backend,q,v,a,h,solver,statistics;linear=false)
    beta=0.25;gamma=0.5
    qp=q+h*v+h^2*(0.5-beta)*a;vp=v+h*(1-gamma)*a
    qn=qp+beta*h^2*a
    massfactor=1/(beta*h^2);dampfactor=gamma/(beta*h)
    constant=m.K+dampfactor*m.C+massfactor*m.M
    # Row scales distinguish translational force and rotational moment units.
    scale=max.(abs.(diag(m.K)).*m.qscale,1.)
    tolerance=solver["newton_relative_tolerance"]
    for iteration in 1:solver["newton_max_iterations"]
        an=massfactor*(qn-qp);vn=vp+gamma*h*an
        evaluate!(backend,m,qn;tangent=true,linear)
        residual=m.M*an+m.C*vn+m.K*qn+backend.force
        errornorm=maximum(abs,residual./scale)
        if errornorm<=tolerance
            statistics.steps+=1;statistics.newton_iterations+=iteration-1
            statistics.max_residual=max(statistics.max_residual,errornorm)
            return qn,vn,an
        end
        correction=(constant+backend.tangent)\residual
        all(isfinite,correction) || error("Nonfinite Newton correction")
        accepted=false
        for weight in (1.,0.5,0.25,0.125,0.0625,0.03125)
            trial=qn-weight*correction
            at=massfactor*(trial-qp);vt=vp+gamma*h*at
            evaluate!(backend,m,trial;tangent=false,linear)
            trial_residual=m.M*at+m.C*vt+m.K*trial+backend.force
            if maximum(abs,trial_residual./scale)<errornorm
                qn=trial;accepted=true;break
            end
        end
        accepted || error("Newton line search failed; no unconverged step is accepted")
    end
    error("Newton did not converge")
end

function advance(m,backend,q,v,a,h,solver,statistics;linear=false,depth=0)
    try
        q1,v1,a1=newmark_step(m,backend,q,v,a,h,solver,statistics;linear)
        # Integrate physical damping power on internal steps, not output frames.
        dissipated=h*(dot(v,m.C*v)+dot(v1,m.C*v1))/2
        return q1,v1,a1,dissipated
    catch exception
        exception isa InterruptException && rethrow()
        # Hardware, allocation and programming faults must not be hidden by retries.
        retryable=exception isa ErrorException &&
            (startswith(exception.msg,"Newton ") || startswith(exception.msg,"Nonfinite Newton"))
        retryable && depth<solver["maximum_bisections"] || rethrow()
        statistics.subdivisions+=1
        qh,vh,ah,d1=advance(m,backend,q,v,a,h/2,solver,statistics;linear,depth=depth+1)
        q1,v1,a1,d2=advance(m,backend,qh,vh,ah,h/2,solver,statistics;linear,depth=depth+1)
        return q1,v1,a1,d1+d2
    end
end

"""Stream physical q/v snapshots to HDF5; no complete trajectory lives on the GPU."""
function integrate_to_file(path,m,q0,cfg; backend=CPUBackend(m),substeps=cfg["solver"]["substeps"],
        linear=false,frames=cfg["sampling"]["frames"],dt=cfg["sampling"]["dt_seconds"],metadata=Dict())
    isfile(path) && error("Refusing to overwrite trajectory: $path")
    temporary=path*".partial.h5"
    isfile(temporary) && error("Partial output exists; retain it for failure diagnosis: $temporary")
    mkpath(dirname(path));n=length(q0);v=zeros(n);q=copy(q0)
    evaluate!(backend,m,q;tangent=false,linear)
    a=-(m.M\(m.K*q+backend.force))
    E0=linear ? dot(q,m.K*q)/2 : potential(m,q)
    E0>0 || error("Positive initial energy required")
    statistics=StepStatistics();dissipated=0.;max_balance=0.;max_strain=0.;lastE=E0
    started=time_ns();next_log=started+UInt64(60_000_000_000)
    cpu_diagnostic=CPUBackend(m)
    HDF5.h5open(temporary,"w") do file
        state=HDF5.create_dataset(file,"x",HDF5.datatype(Float64),HDF5.dataspace((2n,frames));chunk=(2n,min(16,frames)))
        time=HDF5.create_dataset(file,"t",HDF5.datatype(Float64),HDF5.dataspace((frames,)))
        energy=HDF5.create_dataset(file,"energy",HDF5.datatype(Float64),HDF5.dataspace((frames,)))
        diss=HDF5.create_dataset(file,"dissipated",HDF5.datatype(Float64),HDF5.dataspace((frames,)))
        HDF5.attributes(file)["state_order"]="all independent q, then all independent qdot"
        HDF5.attributes(file)["metadata_json"]=JSON.json(metadata)
        for frame in 1:frames
            if frame>1
                for _ in 1:substeps
                    q,v,a,work=advance(m,backend,q,v,a,dt/substeps,cfg["solver"],statistics;linear)
                    dissipated+=work
                end
            end
            all(isfinite,q) && all(isfinite,v) || error("Nonfinite mechanical state")
            diagnostic=evaluate!(cpu_diagnostic,m,q;tangent=false,linear)
            E=dot(v,m.M*v)/2+dot(q,m.K*q)/2+diagnostic.energy
            max_balance=max(max_balance,abs(E+dissipated-E0)/E0)
            max_strain=max(max_strain,diagnostic.strain);lastE=E
            state[:,frame]=vcat(q,v);time[frame]=(frame-1)*dt;energy[frame]=E;diss[frame]=dissipated
            if time_ns()>=next_log
                println("NACA_PROGRESS file=",basename(path)," frame=",frame,"/",frames,
                    " energy_ratio=",E/E0," balance=",max_balance)
                flush(stdout);next_log=time_ns()+UInt64(60_000_000_000)
            end
        end
    end
    result=Dict("status"=>"integrated_not_yet_qualified","frames"=>frames,"dt_seconds"=>dt,
        "state_dimension"=>2n,"substeps"=>substeps,"linear"=>linear,"initial_energy"=>E0,
        "final_energy_ratio"=>lastE/E0,"max_energy_balance_relative"=>max_balance,
        "max_recovered_strain_component"=>max_strain,"internal_steps"=>statistics.steps,
        "newton_iterations"=>statistics.newton_iterations,"step_bisections"=>statistics.subdivisions,
        "max_newton_scaled_residual"=>statistics.max_residual,"wall_seconds"=>(time_ns()-started)/1e9)
    mv(temporary,path)
    result["sha256"]=filehash(path);writejson(path*".json",result)
    return result
end

function trajectory_difference(a,b,m; map_a=nothing,map_b=nothing)
    HDF5.h5open(a,"r") do fa
        HDF5.h5open(b,"r") do fb
            size(fa["x"],2)==size(fb["x"],2) || error("Frame count mismatch")
            ta=read(fa["t"]);tb=read(fb["t"])
            maximum(abs,ta-tb)<1e-12 || error("Time grid mismatch")
            n=size(fa["x"],1)÷2; nb=size(fb["x"],1)÷2
            # A trajectory-wide reference norm avoids division by displacement zero crossings.
            numerator=0.;denominator=0.
            for k in eachindex(ta)
                x=fa["x"][:,k];y=fb["x"][:,k]
                if map_a!==nothing
                    x=vcat(map_a*x[1:n],map_a*x[n+1:end]/m.omega[1])
                    y=vcat(map_b*y[1:nb],map_b*y[nb+1:end]/m.omega[1])
                else
                    scale=vcat(m.qscale,m.omega[1].*m.qscale);x=x./scale;y=y./scale
                end
                numerator=max(numerator,norm(x-y));denominator=max(denominator,norm(y))
            end
            return numerator/max(denominator,eps())
        end
    end
end
