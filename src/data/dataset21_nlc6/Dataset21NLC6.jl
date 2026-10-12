# SPDX-License-Identifier: GPL-3.0-only
module Dataset21NLC6
using LinearAlgebra, SparseArrays
using ..Dataset21NACA
const NC=Dataset21NACA

struct Connectors
    B::SparseMatrixCSC{Float64,Int}
    kappa::Vector{Float64}
    damping_cap::Vector{Float64}
    speed::Vector{Float64}
end

function build_connectors(m,cfg)
    n=length(m.active);nn=size(m.mesh.nodes,1);P=zeros(n,8)
    for (j,patch) in enumerate(cfg["patches"])
        nodes=Int.(patch["nodes_one_based"]);weights=Float64.(patch["weights"])
        all(>(0),weights) && isapprox(sum(weights),1.;atol=1e-12) || error("Invalid patch weights")
        for (component,column) in ((2,j),(1,j+4))
            full=zeros(6nn);full[6 .* (nodes.-1).+component]=weights
            P[:,column]=full[m.active]
        end
    end
    B=sparse(hcat((P[:,1]+P[:,2])/2,(P[:,3]+P[:,4])/2,P[:,2]-P[:,1],P[:,4]-P[:,3],
        (P[:,5]+P[:,6])/2,(P[:,7]+P[:,8])/2))
    ports=cfg["ports"]
    return Connectors(B,Float64[p["cubic_stiffness_N_per_m3"] for p in ports],
        Float64[p["damping_cap_N_s_per_m"] for p in ports],Float64[p["saturation_speed_m_per_s"] for p in ports])
end

function damping(p,w)
    return p.damping_cap .* w.^3 ./ (w.^2 .+ p.speed.^2)
end
function damping_tangent(p,w)
    return p.damping_cap .* w.^2 .* (w.^2 .+ 3 .* p.speed.^2) ./ (w.^2 .+ p.speed.^2).^2
end
function connector_values(p,q,v)
    s=transpose(p.B)*q;w=transpose(p.B)*v;d=damping(p,w)
    return (;s,w,force=p.B*(p.kappa.*s.^3+d),potential=sum(p.kappa.*s.^4)/4,
        power=dot(w,d),stiffness=3 .* p.kappa.*s.^2,damping=damping_tangent(p,w))
end

function with_damping(m,cfg)
    aM=cfg["linear_damping"]["aM_per_s"];aK=cfg["linear_damping"]["aK_s"]
    return NC.WingModel(m.mesh,m.active,m.elements,m.slots,m.M,m.K,aM*m.M+aK*m.K,
        m.omega,m.modes,aM,aK,m.qscale)
end

struct StepCache{R}
    radau::R
    U::SparseMatrixCSC{Float64,Int}
    influence::Dict{Float64,Tuple{Matrix{Float64},Matrix{Float64}}}
end
function StepCache(m,p,h)
    return StepCache(NC.RadauCache(m,h),kron(sparse(I,3,3),p.B),
        Dict{Float64,Tuple{Matrix{Float64},Matrix{Float64}}}())
end

function stage_residual(m,backend,p,q,v,Z,h,cache)
    residual,V,W=NC.radau_residual(m,backend,q,v,Z,h,cache.radau)
    for i in 1:3
        @views residual[:,i].+=connector_values(p,q+Z[:,i],V[:,i]).force
    end
    return residual,V,W
end

function small_tangent(p,q,Z,V,h,cache)
    rank=size(p.B,2);T=zeros(3rank,3rank);H=cache.radau.inverse_A/h
    for i in 1:3
        value=connector_values(p,q+Z[:,i],view(V,:,i))
        for j in 1:3,k in 1:rank
            T[(i-1)*rank+k,(j-1)*rank+k]=H[i,j]*value.damping[k]+(i==j ? value.stiffness[k] : 0.)
        end
    end
    return T
end

function port_correction(m,backend,p,q,Z,V,h,cache,residual;consistent=false)
    base=cache.radau
    system=get!(base.systems,h) do
        NC.RadauSystem(m,h,base.roots)
    end
    T=small_tangent(p,q,Z,V,h,cache)
    if consistent
        blocks=SparseMatrixCSC{Float64,Int}[]
        for i in 1:3
            NC.evaluate!(backend,m,q+Z[:,i];tangent=true)
            push!(blocks,m.K+backend.tangent)
        end
        H=base.inverse_A/h
        J=kron(sparse(H*H),m.M)+kron(sparse(H),m.C)+blockdiag(blocks...)+cache.U*sparse(T)*transpose(cache.U)
        return reshape(J\vec(residual),length(q),3)
    end
    W,G=get!(cache.influence,h) do
        n=length(q)
        columns=[vec(NC.radau_chord_correction(reshape(Vector(cache.U[:,j]),n,3),system,base)) for j in axes(cache.U,2)]
        W=hcat(columns...)
        (W,Matrix(transpose(cache.U)*W))
    end
    z=vec(NC.radau_chord_correction(residual,system,base))
    # Exact rank-18 connector tangent; only the shell geometric tangent is frozen.
    z.-=W*((I+T*G)\(T*(transpose(cache.U)*z)))
    return reshape(z,length(q),3)
end

function step(m,backend,p,q,v,h,solver,statistics,cache)
    Z=h.*v.*transpose(cache.radau.nodes);consistent=false
    for iteration in 1:solver["newton_max_iterations"]
        residual,V,W=stage_residual(m,backend,p,q,v,Z,h,cache)
        errornorm=maximum(abs,residual./cache.radau.scale)
        if errornorm<=solver["newton_relative_tolerance"]
            statistics.steps+=1;statistics.newton_iterations+=iteration-1
            statistics.max_residual=max(statistics.max_residual,errornorm)
            linear_work=0.;connector_work=0.
            for i in 1:3
                velocity=view(V,:,i);weight=h*cache.radau.weights[i]
                linear_work+=weight*dot(velocity,m.C*velocity)
                w=transpose(p.B)*velocity;connector_work+=weight*dot(w,damping(p,w))
            end
            return q+Z[:,3],V[:,3],linear_work,connector_work
        end
        consistent ? (statistics.consistent_factorizations+=1) : (statistics.chord_corrections+=1)
        correction=port_correction(m,backend,p,q,Z,V,h,cache,residual;consistent)
        all(isfinite,correction) || error("NLC6 Newton nonfinite correction")
        accepted=false
        for weight in (1.,0.5,0.25,0.125,0.0625,0.03125)
            trial=Z-weight*correction
            rr,_,_=stage_residual(m,backend,p,q,v,trial,h,cache)
            if maximum(abs,rr./cache.radau.scale)<errornorm
                Z=trial;accepted=true;break
            end
        end
        if !accepted && !consistent
            consistent=true;continue
        end
        accepted || error("NLC6 Newton line search failed")
        iteration>=get(solver,"maximum_chord_iterations",10) && (consistent=true)
    end
    error("NLC6 Newton did not converge")
end

function advance(m,backend,p,q,v,h,solver,statistics,cache;depth=0)
    try
        return step(m,backend,p,q,v,h,solver,statistics,cache)
    catch exception
        exception isa InterruptException && rethrow()
        retryable=exception isa ErrorException && startswith(exception.msg,"NLC6 Newton")
        retryable && depth<solver["maximum_bisections"] || rethrow()
        statistics.subdivisions+=1
        qh,vh,d0a,dna=advance(m,backend,p,q,v,h/2,solver,statistics,cache;depth=depth+1)
        q1,v1,d0b,dnb=advance(m,backend,p,qh,vh,h/2,solver,statistics,cache;depth=depth+1)
        return q1,v1,d0a+d0b,dna+dnb
    end
end

function initial_condition(m,p,cfg)
    trial=cfg["trial"];indices=Int.(trial["modes"]);fractions=Float64.(trial["linear_energy_fractions"])
    signs=Float64.(trial["signs"])
    @assert isapprox(sum(fractions),1.;atol=1e-12) && all(>(0),fractions)
    shape=m.modes[:,indices]*(signs.*sqrt.(2 .* fractions)./m.omega[indices])
    E2=dot(shape,m.K*shape)/2;E4=sum(p.kappa.*(transpose(p.B)*shape).^4)/4
    scale=sqrt(trial["connector_energy_ratio"]*E2/E4)
    return scale*shape,scale.*signs.*sqrt.(2 .* fractions)./m.omega[indices]
end

function integrate(path,m,backend,p,q0,cfg)
    temporary=path*".partial.h5"
    (ispath(path)||ispath(temporary)) && error("Trial output exists; use a fresh attempt")
    mkpath(dirname(path));frames=cfg["sampling"]["frames"];dt=cfg["sampling"]["dt_candidate_s"]
    solver=cfg["trial"]["solver"];substeps=solver["substeps"]
    n=length(q0);2n<=cfg["maximum_state_dimension"] || error("State cap")
    q=copy(q0);v=zeros(n);diagnostic_backend=NC.CPUBackend(m)
    value=connector_values(p,q,v);E0=NC.potential(m,q)+value.potential
    statistics=NC.StepStatistics();cache=StepCache(m,p,dt/substeps)
    dissipated_linear=0.;dissipated_connector=0.;max_balance=0.;max_strain=0.
    started=time_ns();next_log=started+UInt64(15_000_000_000)
    startup_intervals=round(Int,solver["startup_duration_s"]/dt)
    last_energy=E0;total_connector_initial=value.potential
    NC.HDF5.h5open(temporary,"w") do file
        ds=Dict{String,Any}()
        for name in ("t","energy","dissipated","dissipated_linear","dissipated_connector","connector_potential","strain_max")
            ds[name]=NC.HDF5.create_dataset(file,name,NC.HDF5.datatype(Float64),NC.HDF5.dataspace((frames,)))
        end
        x=NC.HDF5.create_dataset(file,"x",NC.HDF5.datatype(Float64),NC.HDF5.dataspace((2n,frames));chunk=(2n,1))
        s=NC.HDF5.create_dataset(file,"connector_displacement",NC.HDF5.datatype(Float64),NC.HDF5.dataspace((6,frames)))
        w=NC.HDF5.create_dataset(file,"connector_velocity",NC.HDF5.datatype(Float64),NC.HDF5.dataspace((6,frames)))
        NC.HDF5.attributes(file)["state_order"]="all independent q, then all independent qdot"
        NC.HDF5.attributes(file)["model_code"]=cfg["model_code"]
        NC.HDF5.attributes(file)["status"]=get(cfg,"qualification_status","single_trial_not_a_qualified_dataset")
        for frame in 1:frames
            if frame>1
                count=substeps*(frame<=startup_intervals+1 ? solver["startup_refinement"] : 1)
                for _ in 1:count
                    q,v,d0,dn=advance(m,backend,p,q,v,dt/count,solver,statistics,cache)
                    dissipated_linear+=d0;dissipated_connector+=dn
                end
            end
            all(isfinite,q) && all(isfinite,v) || error("Nonfinite trial state")
            geo=NC.evaluate!(diagnostic_backend,m,q;tangent=false);cv=connector_values(p,q,v)
            E=dot(v,m.M*v)/2+dot(q,m.K*q)/2+geo.energy+cv.potential
            D=dissipated_linear+dissipated_connector
            max_balance=max(max_balance,abs(E+D-E0)/E0);max_strain=max(max_strain,geo.strain);last_energy=E
            x[:,frame]=vcat(q,v);s[:,frame]=cv.s;w[:,frame]=cv.w
            for (name,val) in (("t",(frame-1)*dt),("energy",E),("dissipated",D),
                ("dissipated_linear",dissipated_linear),("dissipated_connector",dissipated_connector),
                ("connector_potential",cv.potential),("strain_max",geo.strain))
                ds[name][frame]=val
            end
            if max_strain>cfg["solver_proposal"]["maximum_strain_component"] || max_balance>cfg["solver_proposal"]["energy_balance_relative_target"]
                failure=Dict("status"=>"quarantined_physics_gate","frame"=>frame,"time_s"=>(frame-1)*dt,
                    "max_strain"=>max_strain,"max_energy_balance_relative"=>max_balance,
                    "strain_limit"=>cfg["solver_proposal"]["maximum_strain_component"],
                    "energy_balance_limit"=>cfg["solver_proposal"]["energy_balance_relative_target"])
                NC.writejson(joinpath(dirname(path),"physics_failure.json"),failure)
                NC.JLD2.jldsave(joinpath(dirname(path),"physics_failure_state.jld2");q,v,frame)
                error("NLC6 physics gate: "*NC.JSON.json(failure))
            end
            if time_ns()>=next_log || frame==frames
                println("NLC6_PROGRESS frame=",frame,"/",frames," energy_ratio=",E/E0,
                    " balance=",max_balance," strain=",max_strain);flush(stdout)
                NC.writejson(joinpath(dirname(path),"progress.json"),Dict("frame"=>frame,"frames"=>frames,
                    "energy_ratio"=>E/E0,"energy_balance"=>max_balance,"max_strain"=>max_strain,
                    "elapsed_seconds"=>(time_ns()-started)/1e9))
                next_log=time_ns()+UInt64(15_000_000_000)
            end
        end
    end
    mv(temporary,path)
    receipt=Dict("status"=>"integrated_pending_readback","frames"=>frames,"state_dimension"=>2n,
        "dt_seconds"=>dt,"initial_energy"=>E0,"initial_connector_potential"=>total_connector_initial,
        "final_energy_ratio"=>last_energy/E0,"max_energy_balance_relative"=>max_balance,
        "max_recovered_strain_component"=>max_strain,"newton_iterations"=>statistics.newton_iterations,
        "internal_steps"=>statistics.steps,"consistent_factorizations"=>statistics.consistent_factorizations,
        "chord_corrections"=>statistics.chord_corrections,"step_bisections"=>statistics.subdivisions,
        "max_newton_scaled_residual"=>statistics.max_residual,"wall_seconds"=>(time_ns()-started)/1e9,
        "sha256"=>NC.filehash(path),"solver"=>solver,
        "backend"=>string(typeof(backend)),"physics_checks_passed"=>max_balance<=1e-4 && max_strain<=0.001 && last_energy/E0<=0.4)
    NC.writejson(path*".json",receipt)
    return receipt
end
end
