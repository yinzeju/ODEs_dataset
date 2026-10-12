# SPDX-License-Identifier: GPL-3.0-only
mutable struct StepStatistics
    steps::Int
    newton_iterations::Int
    subdivisions::Int
    max_residual::Float64
    chord_corrections::Int
    consistent_factorizations::Int
end
StepStatistics()=StepStatistics(0,0,0,0.,0,0)

struct NewmarkSystem{F}
    matrix::SparseMatrixCSC{Float64,Int}
    factorization::F
end
function NewmarkSystem(m::WingModel,h::Real)
    matrix=m.K+(2/h)*m.C+(4/h^2)*m.M
    return NewmarkSystem(matrix,cholesky(Symmetric(matrix)))
end
struct NewmarkCache{S}
    systems::Dict{Float64,S}
    scale::Vector{Float64}
end
function NewmarkCache(m::WingModel,h::Real)
    system=NewmarkSystem(m,h)
    return NewmarkCache(Dict(Float64(h)=>system),Vector(max.(abs.(diag(m.K)).*m.qscale,1.)))
end
function newmark_system!(cache,m,h)
    return get!(cache.systems,h) do
        NewmarkSystem(m,h)
    end
end

function consistent_correction(matrix,residual)
    try
        return cholesky(Symmetric(matrix))\residual
    catch exception
        exception isa PosDefException || rethrow()
        return matrix\residual
    end
end

function newmark_step(m,backend,q,v,a,h,solver,statistics;linear=false,cache=nothing)
    beta=0.25;gamma=0.5
    qp=q+h*v+h^2*(0.5-beta)*a;vp=v+h*(1-gamma)*a
    qn=qp+beta*h^2*a
    massfactor=1/(beta*h^2);dampfactor=gamma/(beta*h)
    cached=cache!==nothing
    system=cached ? newmark_system!(cache,m,h) : nothing
    constant=cached ? system.matrix : m.K+dampfactor*m.C+massfactor*m.M
    # Row scales distinguish translational force and rotational moment units.
    scale=cached ? cache.scale : max.(abs.(diag(m.K)).*m.qscale,1.)
    tolerance=solver["newton_relative_tolerance"]
    strategy=get(solver,"tangent_strategy","consistent_lu")
    chord=cached && strategy=="cached_linear_with_consistent_fallback"
    use_consistent=!chord
    for iteration in 1:solver["newton_max_iterations"]
        an=massfactor*(qn-qp);vn=vp+gamma*h*an
        evaluate!(backend,m,qn;tangent=use_consistent,linear)
        residual=m.M*an+m.C*vn+m.K*qn+backend.force
        errornorm=maximum(abs,residual./scale)
        if errornorm<=tolerance
            statistics.steps+=1;statistics.newton_iterations+=iteration-1
            statistics.max_residual=max(statistics.max_residual,errornorm)
            return qn,vn,an
        end
        correction=if use_consistent
            statistics.consistent_factorizations+=1
            strategy=="consistent_lu" ? (constant+backend.tangent)\residual :
                consistent_correction(constant+backend.tangent,residual)
        else
            statistics.chord_corrections+=1
            system.factorization\residual
        end
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
        if !accepted && !use_consistent
            use_consistent=true
            continue
        end
        accepted || error("Newton line search failed; no unconverged step is accepted")
        # A chord iteration solves the SAME nonlinear Newmark residual. The
        # exact tangent is rebuilt if rapid convergence is not observed.
        iteration>=5 && !linear && (use_consistent=true)
    end
    error("Newton did not converge")
end

function advance(m,backend,q,v,a,h,solver,statistics;linear=false,depth=0,cache=nothing)
    try
        q1,v1,a1=newmark_step(m,backend,q,v,a,h,solver,statistics;linear,cache)
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
        qh,vh,ah,d1=advance(m,backend,q,v,a,h/2,solver,statistics;linear,depth=depth+1,cache)
        q1,v1,a1,d2=advance(m,backend,qh,vh,ah,h/2,solver,statistics;linear,depth=depth+1,cache)
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
    strategy=get(cfg["solver"],"tangent_strategy","consistent_lu")
    cache=strategy=="consistent_lu" ? nothing : NewmarkCache(m,dt/substeps)
    started=time_ns();next_log=started+UInt64(60_000_000_000)
    cpu_diagnostic=CPUBackend(m)
    HDF5.h5open(temporary,"w") do file
        state=HDF5.create_dataset(file,"x",HDF5.datatype(Float64),HDF5.dataspace((2n,frames));chunk=(2n,1))
        time=HDF5.create_dataset(file,"t",HDF5.datatype(Float64),HDF5.dataspace((frames,)))
        energy=HDF5.create_dataset(file,"energy",HDF5.datatype(Float64),HDF5.dataspace((frames,)))
        diss=HDF5.create_dataset(file,"dissipated",HDF5.datatype(Float64),HDF5.dataspace((frames,)))
        HDF5.attributes(file)["state_order"]="all independent q, then all independent qdot"
        HDF5.attributes(file)["metadata_json"]=JSON.json(metadata)
        for frame in 1:frames
            if frame>1
                for _ in 1:substeps
                    q,v,a,work=advance(m,backend,q,v,a,dt/substeps,cfg["solver"],statistics;linear,cache)
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
        "tangent_strategy"=>strategy,"chord_corrections"=>statistics.chord_corrections,
        "consistent_factorizations"=>statistics.consistent_factorizations,
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
