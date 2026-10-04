module GPUModal

using LinearAlgebra, CUDA
using SciMLBase: ODEProblem, solve, successful_retcode, DiscreteCallback, u_modified!
using OrdinaryDiffEqVerner: Vern9
using ..TestSub2NV: nonlinear!, potential
using ..GPUExponential

struct Cache{F}
    force::F
    physical::CuMatrix{ComplexF64}
    coordinate_scale::CuVector{Float64}
    derivative_scale::CuVector{Float64}
    lambda::CuVector{ComplexF64}
end

function rhs!(dz,z,p,t)
    @. p.physical=z*p.coordinate_scale
    GPUExponential.rhs!(dz,p.physical,p.force)
    @. dz=p.lambda*z+dz/p.derivative_scale
    return nothing
end

function integrate(m,Q0;periods=32,samples_per_period=128,reltol=2e-10,abstol=2e-12,
        max_step_fraction=1/256,label="")
    n=m.n;nb=size(Q0,2)
    c,decay,wd=GPUExponential.cache(m,nb)
    # All n modes form an invertible basis. Scale each complex coordinate by
    # its full physical-state column norm; this controls units and conditioning.
    scales=[1/(norm(view(m.modes,:,j)./m.qscale)*max(1.,m.omega[j]/c.omega)) for j in 1:n]
    r=m.modes'*(m.M*Q0)
    reconstruction_error=maximum(norm((m.modes*r[:,j]-Q0[:,j])./m.qscale) for j in 1:nb)
    reconstruction_error<1e-8 || error("Full modal reconstruction failed")
    z0=CuArray(vcat(complex.(r,(decay./wd).*r)./scales,zeros(ComplexF64,1,nb)))
    energy_scale=maximum(potential(m,view(Q0,:,j)) for j in 1:nb)
    lambda=vcat(complex.(-decay,-wd)./c.omega,0.)
    p=Cache(c,similar(z0),CuArray(vcat(scales,1.)),CuArray(vcat(scales,energy_scale)),CuArray(lambda))
    warm=similar(z0);rhs!(warm,z0,p,0.);CUDA.synchronize()
    times=collect(range(0.,2pi*periods,length=periods*samples_per_period+1))
    next_report=Ref(time_ns()+UInt64(30_000_000_000))
    function progress!(integrator)
        println("GPU_MODAL_PROGRESS ",m.id,"/",m.configuration," ",label," periods=",
            round(integrator.t/(2pi);digits=3),"/",periods," batch=",nb," dt=",integrator.dt,
            " accepted=",integrator.stats.naccept," rejected=",integrator.stats.nreject)
        flush(stdout);next_report[]=time_ns()+UInt64(30_000_000_000)
        u_modified!(integrator,false)
    end
    callback=DiscreteCallback((u,t,integrator)->time_ns()>=next_report[],progress!;save_positions=(false,false))
    elapsed=@elapsed sol=solve(ODEProblem(rhs!,z0,(0.,times[end]),p),Vern9();reltol,abstol,
        dtmax=2pi*max_step_fraction,saveat=times,save_everystep=false,dense=false,maxiters=10^8,callback)
    successful_retcode(sol) || error("GPU modal integration failed: $(sol.retcode)")
    ns=length(times);x=Array{Float64}(undef,2n,ns,nb);diss=zeros(ns,nb)
    for k in 1:ns
        @. p.physical=sol.u[k]*p.coordinate_scale
        @views @. c.r=real(p.physical[1:n,:])
        mul!(c.q,c.phi,c.r);x[1:n,k,:]=Array(c.q)
        @views @. c.r=c.wd*imag(p.physical[1:n,:])-c.decay*real(p.physical[1:n,:])
        mul!(c.q,c.phi,c.r);x[n+1:2n,k,:]=Array(c.q)
        diss[k,:]=real.(Array(view(sol.u[k],n+1,:))).*energy_scale
    end
    all(isfinite,x) || error("Nonfinite GPU modal solution")
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
        "minimum_damping_power"=>minimum(powers[:,j]),"displacement_dofs"=>n,"all_modes_retained"=>n,
        "full_modal_reconstruction_error"=>reconstruction_error,
        "solver"=>"Float64 GPU full invertible modal coordinates OrdinaryDiffEqVerner.Vern9",
        "qdot_equals_v_rhs"=>true,"device"=>CUDA.name(CUDA.device()),
        "reproducibility"=>"Frozen Float64 inputs and environment; GPU atomic accumulation is not guaranteed bitwise reproducible") for j in 1:nb]
    return (;x,t=times./c.omega,energy=energies,power=powers,dissipated=diss,diagnostics)
end

end
