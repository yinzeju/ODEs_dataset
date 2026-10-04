function tangent_pattern(m)
    if m.kernel isa DuffingKernel
        return spdiagm(0=>zeros(m.n))
    end
    rows=Int[];cols=Int[]
    for p in m.kernel, j in p.index, i in p.index
        if i>0 && j>0;push!(rows,i);push!(cols,j);end
    end
    K=sparse(rows,cols,ones(length(rows)),m.n,m.n)
    fill!(nonzeros(K),0.)
    return K
end

struct IntegrationCache{M}
    model::M
    omega::Float64
    energy_scale::Float64
    Kbar::SparseMatrixCSC{Float64,Int}
    Cbar::SparseMatrixCSC{Float64,Int}
    Mbar::SparseMatrixCSC{Float64,Int}
    q::Vector{Float64}
    fnl::Vector{Float64}
    damping::Vector{Float64}
    Knl::SparseMatrixCSC{Float64,Int}
    Jbase::SparseMatrixCSC{Float64,Int}
end

function integration_cache(m)
    n=m.n;omega=m.omega[m.reference_mode];D=spdiagm(0=>m.qscale)
    mass_scale=sum(diag(D*m.M*D))/n;energy_scale=mass_scale*omega^2
    Mbar=D*m.M*D/mass_scale;Kbar=D*m.K*D/energy_scale;Cbar=D*m.C*D/(mass_scale*omega)
    pattern=tangent_pattern(m)
    rows,cols,_=findnz(pattern)
    jr=vcat(collect(1:n),n.+rows,2n+1 .+ zeros(Int,n),2n+1)
    jc=vcat(n.+collect(1:n),cols,n.+collect(1:n),2n+1)
    J=sparse(jr,jc,ones(length(jr)),2n+1,2n+1)
    ri,cj,cv=findnz(Cbar)
    for k in eachindex(cv);J[n+ri[k],n+cj[k]]=cv[k];end
    fill!(nonzeros(J),0.)
    for i in 1:n;J[i,n+i]=1.;end
    ri,cj,kv=findnz(Kbar)
    for k in eachindex(kv);J[n+ri[k],cj[k]]=-kv[k];end
    # The C index set need not coincide with the elastic matrix index set.
    ri,cj,cv=findnz(Cbar)
    for k in eachindex(cv);J[n+ri[k],n+cj[k]]=-cv[k];end
    IntegrationCache(m,omega,energy_scale,Kbar,Cbar,Mbar,zeros(n),zeros(n),zeros(n),pattern,J)
end

function mechanical_rhs!(du,u,p,t)
    n=p.model.n;qbar=view(u,1:n);vbar=view(u,n+1:2n)
    @. p.q=qbar*p.model.qscale
    nonlinear!(p.fnl,p.model.kernel,p.q)
    a=view(du,n+1:2n)
    mul!(a,p.Kbar,qbar)
    mul!(p.damping,p.Cbar,vbar)
    @inbounds for i in 1:n
        du[i]=vbar[i]
        a[i]=-(a[i]+p.damping[i]+p.model.qscale[i]*p.fnl[i]/p.energy_scale)
    end
    du[end]=dot(vbar,p.damping)
    nothing
end

function mechanical_jacobian!(J,u,p,t)
    n=p.model.n
    copyto!(nonzeros(J),nonzeros(p.Jbase))
    @inbounds for i in 1:n;p.q[i]=u[i]*p.model.qscale[i];end
    tangent_nonlinear!(p.Knl,p.model.kernel,p.q)
    @inbounds for j in 1:n,k in nzrange(p.Knl,j)
        i=rowvals(p.Knl)[k]
        J[n+i,j]-=nonzeros(p.Knl)[k]*p.model.qscale[i]*p.model.qscale[j]/p.energy_scale
    end
    mul!(p.damping,p.Cbar,view(u,n+1:2n))
    @inbounds for i in 1:n;J[end,n+i]=2p.damping[i];end
    nothing
end

function integrate(m,q0;periods=32,samples_per_period=128,reltol=2e-10,
        abstol=2e-12,max_step_fraction=1/256,label="")
    p=integration_cache(m);n=m.n
    u0=vcat(q0./m.qscale,zeros(n+1))
    mass=[spdiagm(0=>ones(n)) spzeros(n,n) spzeros(n,1);
          spzeros(n,n) p.Mbar spzeros(n,1);spzeros(1,n) spzeros(1,n) sparse([1],[1],[1.],1,1)]
    fun=ODEFunction(mechanical_rhs!;jac=mechanical_jacobian!,jac_prototype=copy(p.Jbase),
        mass_matrix=mass,tgrad=(out,u,p,t)->fill!(out,0.))
    times=collect(range(0.,2pi*periods,length=periods*samples_per_period+1))
    problem=ODEProblem(fun,u0,(0.,times[end]),p)
    next_report=Ref(time_ns()+UInt64(30_000_000_000))
    function report_progress!(integrator)
        println("INTEGRATION_PROGRESS ",m.id,"/",m.configuration," ",label,
            " periods=",round(integrator.t/(2pi);digits=3),"/",periods,
            " internal_step=",integrator.dt)
        flush(stdout)
        next_report[]=time_ns()+UInt64(30_000_000_000)
        u_modified!(integrator,false)
    end
    progress=DiscreteCallback((u,t,integrator)->time_ns()>=next_report[],report_progress!;
        save_positions=(false,false))
    elapsed=@elapsed sol=solve(problem,Rodas5P(linsolve=KLUFactorization());
        reltol,abstol,dtmax=2pi*max_step_fraction,saveat=times,
        save_everystep=false,dense=false,maxiters=10^8,callback=progress)
    successful_retcode(sol) || error("Integration failed: $(sol.retcode)")
    y=Array(sol);all(isfinite,y) || error("Nonfinite integration")
    x=vcat(y[1:n,:].*m.qscale,y[n+1:2n,:].*(p.omega.*m.qscale))
    E=zeros(length(times));P=similar(E);fnl=zeros(n)
    for j in axes(x,2)
        q=view(x,1:n,j);v=view(x,n+1:2n,j)
        E[j]=dot(v,m.M*v)/2+dot(q,m.K*q)/2+nonlinear!(fnl,m.kernel,q)
        P[j]=dot(v,m.C*v)
    end
    dissipated=y[end,:].*p.energy_scale
    balance=maximum(abs.(E.+dissipated.-E[1]))/max(E[1],eps())
    growth=maximum(max.(diff(E),0.))/max(E[1],eps())
    diag=Dict{String,Any}("wall_seconds"=>elapsed,"accepted_steps"=>sol.stats.naccept,
        "rejected_steps"=>sol.stats.nreject,"rhs_calls"=>sol.stats.nf,
        "energy_balance_relative"=>balance,"energy_positive_increment_relative"=>growth,
        "minimum_damping_power"=>minimum(P),"initial_energy"=>E[1],"final_energy"=>E[end],
        "reltol"=>reltol,"abstol"=>abstol,"max_step_over_reference_period"=>max_step_fraction,
        "qdot_equals_v_rhs"=>true,"solver"=>"OrdinaryDiffEqRosenbrock.Rodas5P / KLU / analytic Jacobian")
    return (;x,t=times./p.omega,energy=E,power=P,dissipated,diagnostics=diag)
end

function compare_trajectories(m,a,b)
    scale=vcat(m.qscale,m.omega[m.reference_mode].*m.qscale)
    err=0.
    for j in axes(a.x,2)
        delta=(view(a.x,:,j).-view(b.x,:,j))./scale
        ref=view(b.x,:,j)./scale
        err=max(err,norm(delta)/max(1.,norm(ref)))
    end
    return err
end

function mechanical_checks(m)
    rng=Xoshiro(20261004)
    q=1e-3.*m.qscale.*randn(rng,m.n);direction=m.qscale.*randn(rng,m.n)
    f=zeros(m.n);nonlinear!(f,m.kernel,q);f.+=m.K*q
    h=1e-7
    grad=(potential(m,q+h*direction)-potential(m,q-h*direction))/(2h)
    derivative_error=abs(grad-dot(f,direction))/max(abs(dot(f,direction)),1e-10)
    Knl=tangent_pattern(m);tangent_nonlinear!(Knl,m.kernel,q)
    fp=zeros(m.n);fm=similar(fp)
    nonlinear!(fp,m.kernel,q+h*direction);nonlinear!(fm,m.kernel,q-h*direction)
    jacerr=norm((fp-fm)/(2h)-Knl*direction)/max(norm(Knl*direction),1e-10)
    eigen_residual=maximum(norm(m.K*m.modes[:,j]-m.omega[j]^2*m.M*m.modes[:,j])/
        max(norm(m.K*m.modes[:,j]),1.) for j in 1:min(5,m.n))
    derivative_error<1e-5 || error("Energy gradient mismatch $derivative_error")
    jacerr<1e-5 || error("Nonlinear tangent mismatch $jacerr")
    eigen_residual<1e-7 || error("Mode residual $eigen_residual")
    Dict("potential_gradient_relative_error"=>derivative_error,
         "nonlinear_tangent_relative_error"=>jacerr,"mode_equation_relative_residual"=>eigen_residual,
         "first_frequencies_rad_s"=>m.omega[1:min(5,m.n)],"displacement_dof_count"=>m.n)
end
