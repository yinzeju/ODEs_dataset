module GPUPhysical

using LinearAlgebra, SparseArrays, CUDA
using SciMLBase: ODEProblem, solve, successful_retcode, DiscreteCallback, u_modified!
using OrdinaryDiffEqVerner: Vern9
using ..TestSub2NV: nonlinear!, potential
using ..GPUExponential

struct CSR
    ptr::CuVector{Int32}
    col::CuVector{Int32}
    val::CuVector{Float64}
end
function CSR(A)
    At=sparse(transpose(A))
    CSR(CuArray(Int32.(At.colptr)),CuArray(Int32.(rowvals(At))),CuArray(nonzeros(At)))
end

struct Cache{F}
    force::F
    linear::CSR
    inverse_mass::CSR
    damping::CSR
    scale::CuVector{Float64}
    power::CuMatrix{Float64}
    alpha::Float64
    beta::Float64
    omega::Float64
    energy_scale::Float64
end

function mechanical_kernel!(du,u,fnl,power,ap,ac,av,mp,mc,mv,cp,cc,cv,scale,alpha,beta,omega,n,nb)
    index=(blockIdx().x-1)*blockDim().x+threadIdx().x
    if index<=n*nb
        i=mod1(index,n);b=cld(index,n)
        acceleration=0.;damping=0.
        @inbounds begin
            for k in ap[i]:(ap[i+1]-1)
                j=ac[k]
                acceleration+=av[k]*(u[j,b]+beta*omega*u[n+j,b])
            end
            for k in mp[i]:(mp[i+1]-1)
                acceleration-=mv[k]*fnl[mc[k],b]
            end
            for k in cp[i]:(cp[i+1]-1)
                j=cc[k]
                damping+=cv[k]*scale[j]*omega*u[n+j,b]
            end
            du[i,b]=u[n+i,b]
            du[n+i,b]=acceleration-alpha/omega*u[n+i,b]
            power[i,b]=scale[i]*u[n+i,b]*damping
        end
    end
    return
end

function power_kernel!(du,power,energy_scale,n)
    b=blockIdx().x;i=threadIdx().x
    cache=CuStaticSharedArray(Float64,256)
    value=0.
    @inbounds for j in i:256:n;value+=power[j,b];end
    cache[i]=value;sync_threads()
    offset=128
    while offset>0
        if i<=offset;cache[i]+=cache[i+offset];end
        sync_threads();offset÷=2
    end
    if i==1;@inbounds du[2n+1,b]=cache[1]/energy_scale;end
    return
end

function cache(m,nb,energy_scale)
    force,_,_=GPUExponential.cache(m,nb)
    omega=m.omega[m.reference_mode]
    D=spdiagm(0=>m.qscale);Di=spdiagm(0=>1 ./m.qscale)
    # The assembled lumped shell mass has only independent nodal blocks.
    # Inversion preserves those blocks; no mass approximation is introduced.
    Minv=sparse(inv(Matrix(m.M)));dropzeros!(Minv)
    norm(Minv*m.M-I)<1e-9 || error("Mass inverse residual")
    nnz(Minv)<=6m.n || error("Expected independent nodal mass blocks")
    A=-Di*Minv*m.K*D/omega^2
    return Cache(force,CSR(A),CSR(Di*Minv/omega^2),CSR(m.C),CuArray(m.qscale),
        CUDA.zeros(Float64,m.n,nb),m.metadata["rayleigh_mass"],m.metadata["rayleigh_stiffness"],omega,energy_scale)
end

function rhs!(du,u,c,t)
    n=size(c.force.q,1);nb=size(u,2)
    @views @. c.force.q=c.scale*u[1:n,:]
    GPUExponential.force!(c.force,c.force.q)
    a,mi,cd=c.linear,c.inverse_mass,c.damping
    @cuda threads=128 blocks=cld(n*nb,128) mechanical_kernel!(du,u,c.force.force,c.power,
        a.ptr,a.col,a.val,mi.ptr,mi.col,mi.val,cd.ptr,cd.col,cd.val,c.scale,c.alpha,c.beta,c.omega,n,nb)
    @cuda threads=256 blocks=nb power_kernel!(du,c.power,c.energy_scale,n)
    return nothing
end

function integrate(m,Q0;periods=32,samples_per_period=128,reltol=2e-10,abstol=2e-12,
        max_step_fraction=1/256,label="")
    n=m.n;nb=size(Q0,2)
    energy_scale=maximum(potential(m,view(Q0,:,j)) for j in 1:nb)
    energy_scale>0 || error("Positive release energy required")
    c=cache(m,nb,energy_scale)
    u0=CuArray(vcat(Q0./m.qscale,zeros(n+1,nb)))
    warm=similar(u0);rhs!(warm,u0,c,0.);CUDA.synchronize()
    times=collect(range(0.,2pi*periods,length=periods*samples_per_period+1))
    next_report=Ref(time_ns()+UInt64(30_000_000_000))
    function progress!(integrator)
        println("GPU_VERN9_PROGRESS ",m.id,"/",m.configuration," ",label," periods=",
            round(integrator.t/(2pi);digits=3),"/",periods," batch=",nb)
        flush(stdout);next_report[]=time_ns()+UInt64(30_000_000_000)
        u_modified!(integrator,false)
    end
    callback=DiscreteCallback((u,t,integrator)->time_ns()>=next_report[],progress!;save_positions=(false,false))
    problem=ODEProblem(rhs!,u0,(0.,times[end]),c)
    elapsed=@elapsed sol=solve(problem,Vern9();reltol,abstol,dtmax=2pi*max_step_fraction,
        saveat=times,save_everystep=false,dense=false,maxiters=10^8,callback)
    successful_retcode(sol) || error("GPU integration failed: $(sol.retcode)")
    ns=length(times);x=Array{Float64}(undef,2n,ns,nb);diss=zeros(ns,nb)
    for k in 1:ns
        y=Array(sol.u[k]);all(isfinite,y) || error("Nonfinite GPU solution")
        x[1:n,k,:]=y[1:n,:].*m.qscale
        x[n+1:2n,k,:]=y[n+1:2n,:].*(c.omega.*m.qscale)
        diss[k,:]=y[end,:].*energy_scale
    end
    x[1:n,1,:]=Q0;x[n+1:2n,1,:].=0.
    energies=zeros(ns,nb);powers=zeros(ns,nb);work=zeros(n)
    for j in 1:nb,k in 1:ns
        q=view(x,1:n,k,j);v=view(x,n+1:2n,k,j)
        energies[k,j]=dot(v,m.M*v)/2+dot(q,m.K*q)/2+nonlinear!(work,m.kernel,q)
        powers[k,j]=dot(v,m.C*v)
    end
    diagnostics=[Dict{String,Any}("wall_seconds_batch"=>elapsed,"accepted_steps"=>sol.stats.naccept,
        "rejected_steps"=>sol.stats.nreject,"rhs_calls"=>sol.stats.nf,"reltol"=>reltol,"abstol"=>abstol,
        "max_step_over_reference_period"=>max_step_fraction,"initial_energy"=>energies[1,j],
        "final_energy"=>energies[end,j],"energy_balance_relative"=>maximum(abs.(energies[:,j].+diss[:,j].-energies[1,j]))/energies[1,j],
        "minimum_damping_power"=>minimum(powers[:,j]),"displacement_dofs"=>n,
        "solver"=>"Float64 GPU full physical state OrdinaryDiffEqVerner.Vern9",
        "qdot_equals_v_rhs"=>true,"device"=>CUDA.name(CUDA.device()),
        "reproducibility"=>"Frozen Float64 inputs and environment; GPU atomic accumulation is not guaranteed bitwise reproducible") for j in 1:nb]
    return (;x,t=times./c.omega,energy=energies,power=powers,dissipated=diss,diagnostics)
end

end
