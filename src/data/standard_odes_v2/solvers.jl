function solver_settings(s; fine=false, substeps=8)
    f=s["family"]
    f in ("linear_diagonal","rotation","oscillator") && return Dict("method"=>"analytic_from_initial_state","implementation"=>"StandardODEsV2")
    f=="fput" && return Dict("method"=>"Yoshida4_velocity_Verlet","substeps"=>substeps*(fine ? 2 : 1),"internal_step"=>s["tau"]/(substeps*(fine ? 2 : 1)))
    h=Dict("duffing"=>0.0005,"pendulum"=>0.004,"vanderpol"=>0.004,"axas_haller"=>0.02,"lorenz"=>0.002,"rossler"=>0.004)[f]
    chaotic=f in ("lorenz","rossler")
    Dict("method"=>"Dormand-Prince DP5(4)","package"=>"OrdinaryDiffEqLowOrderRK","version"=>string(pkgversion(OrdinaryDiffEqLowOrderRK)),
         "reltol"=>(chaotic ? 1e-10 : 1e-11)/(fine ? 10 : 1),"abstol"=>(chaotic ? 1e-12 : 1e-13)/(fine ? 10 : 1),
         "dtmax"=>h/(fine ? 2 : 1),"output_policy"=>"tstops_at_every_output_no_interpolation","energy_integral"=>"same_solver_augmented_signed_rate")
end

function analytic_trajectory(m,x0,times)
    X=zeros(length(x0),length(times)); integral=zeros(length(times)); p=m.parameters
    for (k,t) in enumerate(times)
        if family(m)==:linear_diagonal
            X[:,k].=x0.*exp.([p.a1,p.a2,p.a3,p.a4].*t)
        elseif family(m)==:rotation
            c=cos(p.omega*t); z=sin(p.omega*t)
            X[1,k]=exp(-p.gamma*t)*(c*x0[1]-z*x0[2])
            X[2,k]=exp(-p.gamma*t)*(z*x0[1]+c*x0[2])
        else
            g=p.gamma; w=sqrt(p.omega0^2-g*g); c=cos(w*t); z=sin(w*t)
            b=-(g*x0[2]+p.omega0^2*x0[1])/w
            X[1,k]=exp(-g*t)*(x0[1]*c+(x0[2]+g*x0[1])/w*z)
            X[2,k]=exp(-g*t)*(x0[2]*c+b*z)
            i0=-expm1(-2g*t)/(2g)
            ic=expm1(complex(-2g,2w)*t)/complex(-2g,2w)
            integral[k]=-2g*((x0[2]^2+b*b)*i0/2+(x0[2]^2-b*b)*real(ic)/2+x0[2]*b*imag(ic))
        end
    end
    X,integral
end

function verlet!(q,p,a,beta,h)
    acceleration!(a,q,beta)
    @. p+=h/2*a
    @. q+=h*p
    acceleration!(a,q,beta)
    @. p+=h/2*a
end
function symplectic_trajectory(m,x0,tau,M,K)
    X=Matrix{Float64}(undef,64,M); X[:,1].=x0
    q=copy(x0[1:32]); p=copy(x0[33:64]); a=zeros(32)
    w1=1/(2-cbrt(2.0)); w0=-cbrt(2.0)*w1; h=tau/K
    for j in 2:M
        for _ in 1:K
            verlet!(q,p,a,m.parameters.beta,w1*h)
            verlet!(q,p,a,m.parameters.beta,w0*h)
            verlet!(q,p,a,m.parameters.beta,w1*h)
        end
        X[1:32,j].=q; X[33:64,j].=p
    end
    X,zeros(M)
end

function integrate(s,x0; fine=false, substeps=8, M=s["M"], burn=s["burn"])
    m=model(s); times=collect(0:M-1).*s["tau"]; opts=solver_settings(s;fine,substeps)
    if family(m) in (:linear_diagonal,:rotation,:oscillator)
        X,I=analytic_trajectory(m,x0,times)
    elseif family(m)==:fput
        X,I=symplectic_trajectory(m,x0,s["tau"],M,opts["substeps"])
    else
        saves=times.+burn
        prob=ODEProblem(augmented_rhs!,vcat(x0,0.0),(0.0,last(saves)),m)
        sol=solve(prob,DP5();reltol=opts["reltol"],abstol=opts["abstol"],dtmax=opts["dtmax"],
            saveat=saves,tstops=saves,save_start=(burn==0),save_end=true,
            save_everystep=false,dense=false,maxiters=100_000_000)
        SciMLBase.successful_retcode(sol) || error("Integration failed: $(s["id"]), $(sol.retcode)")
        length(sol.t)==M || error("Snapshot count mismatch")
        maximum(abs.(sol.t.-saves))<1e-11 || error("Output time mismatch")
        A=Array(sol); X=A[1:s["d"],:]; I=vec(A[end,:]); I.-=I[1]
    end
    all(isfinite,X) || error("Nonfinite state for $(s["id"])")
    X,I
end

function diagnostics(s,X,integral)
    m=model(s); M=size(X,2)
    energies=[energy(view(X,:,j),m) for j in 1:M]
    residual=maximum(abs.(energies.-energies[1].-integral))/(s["E"]+abs(energies[1]))
    f=s["family"]; support=true; margin=0.0
    if f=="pendulum"
        ratio=maximum(energies)/(2m.parameters.omega0^2)
        limit=s["ic"]=="pendulum_can" ? 0.995 : 0.95
        margin=limit-ratio
        support=maximum(abs,view(X,1,:))<pi && margin > -1e-10
    elseif f=="axas_haller"
        margin=0.5-maximum(sqrt.(X[1,:].^2 .+ X[2,:].^2))
        support=margin>0
    end
    out=Dict{String,Any}("energy_residual"=>residual,"positive_energy_increment"=>max(0.0,maximum(diff(energies))),
        "initial_energy"=>energies[1],"final_energy"=>energies[end],"support_passed"=>support,"support_margin"=>margin,
        "state_max_abs"=>maximum(abs,X),"finite_passed"=>true)
    if f=="fput"
        Q=MODES'*X[1:32,:]; P=MODES'*X[33:64,:]
        modes=(P.^2 .+ (FREQUENCIES.*Q).^2)./2
        out["linear_modal_energy_initial"]=vec(modes[:,1]); out["linear_modal_energy_mean"]=vec(mean(modes;dims=2))
        out["linear_modal_energy_final"]=vec(modes[:,end]); out["initial_linear_energy"]=sum(modes[:,1])
        out["max_bond_extension"]=maximum(abs,diff(vcat(zeros(1,M),X[1:32,:],zeros(1,M));dims=1))
        out["fixed_endpoint_error"]=0.0 # Endpoints are constants in acceleration!, never dynamic state.
    end
    out
end

state_error(X,Y,D)=maximum(norm(view(X,:,k).-view(Y,:,k))/(D+norm(view(Y,:,k))) for k in axes(X,2))

function occupancy_stats(X)
    d,M=size(X); mu=vec(mean(X;dims=2)); rms=sqrt.(vec(mean(abs2,X;dims=2)))
    lag=min(10,M-1)
    ac=[cor(view(X,j,1:M-lag),view(X,j,lag+1:M)) for j in 1:d]
    Dict("mean"=>mu,"rms"=>rms,"lag_correlation"=>ac,
         "q05"=>[quantile(view(X,j,:),0.05) for j in 1:d],"q95"=>[quantile(view(X,j,:),0.95) for j in 1:d])
end
function statistical_error(a,b,D)
    max(maximum(abs.(a["mean"].-b["mean"])./(D.+b["rms"])),
        maximum(abs.(a["rms"].-b["rms"])./(D.+b["rms"])),
        maximum(abs.(a["lag_correlation"].-b["lag_correlation"])),
        maximum(abs.(a["q05"].-b["q05"])./(D.+b["rms"])),
        maximum(abs.(a["q95"].-b["q95"])./(D.+b["rms"])))
end

function qualify(s,cfg;substeps=8,smoke=false)
    records=Any[]; f=s["family"]; local_mode=f in ("lorenz","rossler","fput")
    for i in 1:cfg["probe_count"]
        seed=stable_seed(cfg,"probe",s["id"],get(s,"condition_id","fixed"),i)
        x0,attempts=initial_state(s,seed)
        X,I=integrate(s,x0;substeps)
        Y,J=integrate(s,x0;fine=true,substeps)
        err=0.0; restart_errors=Float64[]
        if local_mode
            duration=f=="fput" ? cfg["fput_restart_duration"] : cfg["chaotic_restart_duration"]
            n=min(s["M"],round(Int,duration/s["tau"])+1)
            for k in unique(round.(Int,range(1,size(X,2)-n+1;length=5)))
                A,_=integrate(s,X[:,k];substeps,M=n,burn=0)
                B,_=integrate(s,X[:,k];fine=true,substeps,M=n,burn=0)
                push!(restart_errors,state_error(A,B,s["D"]))
                # Restarted one-step result agrees with the recorded numerical flow.
                push!(restart_errors,state_error(A[:,1:2],X[:,k:k+1],s["D"]))
            end
            err=maximum(restart_errors)
        else
            err=state_error(X,Y,s["D"])
        end
        base_diag=diagnostics(s,X,I); fine_diag=diagnostics(s,Y,J)
        sa=occupancy_stats(X); sb=occupancy_stats(Y)
        stats_error=local_mode ? statistical_error(sa,sb,s["D"]) : 0.0
        passed=err<=cfg["state_tolerance"] && base_diag["energy_residual"]<=cfg["energy_tolerance"] &&
            fine_diag["energy_residual"]<=cfg["energy_tolerance"] && base_diag["support_passed"] && fine_diag["support_passed"] &&
            stats_error<=cfg["long_statistics_tolerance"]
        push!(records,Dict("probe_id"=>"probe_$(seed)","seed"=>seed,"initial_state"=>x0,"ic_attempts"=>attempts,
            "state_error"=>err,"comparison"=>(local_mode ? "local_restart_and_one_step" : "full_record"),
            "restart_errors"=>restart_errors,"statistics_error"=>stats_error,"base_statistics"=>sa,"fine_statistics"=>sb,
            "base_diagnostics"=>base_diag,"fine_diagnostics"=>fine_diag,"passed"=>passed))
    end
    Dict("object_id"=>s["id"],"condition_id"=>get(s,"condition_id","fixed"),"solver"=>solver_settings(s;substeps),
        "fine_solver"=>solver_settings(s;fine=true,substeps),"D_num"=>fill(s["D"],s["d"]),"E_num"=>s["E"],
        "records"=>records,"all_passed"=>all(r["passed"] for r in records))
end
