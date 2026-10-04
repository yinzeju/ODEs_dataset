module GPUExponential

using LinearAlgebra, CUDA
using ..TestSub2NV: MechanicalModel, ShellPoint, nonlinear!
include(joinpath(@__DIR__,"gpu_batched.jl"))

# Every mechanical mode is retained. This is an invertible full-state coordinate
# change, followed by Cox--Matthews ETDRK4 with exact linear propagation.

function shell_force_kernel!(force,energy,q,index,B,G,D,ne,nb)
    thread=(blockIdx().x-1)*blockDim().x+threadIdx().x
    if thread<=ne*nb
        e=mod1(thread,ne);trajectory=cld(thread,ne)
        g1=0.;g2=0.;g3=0.;g4=0.;g5=0.;g6=0.;b1=0.;b2=0.;b3=0.
        @inbounds for j in 1:18
            k=index[j,e]
            if k>0
                v=q[k,trajectory]
                g1+=G[1,j,e]*v;g2+=G[2,j,e]*v;g3+=G[3,j,e]*v
                g4+=G[4,j,e]*v;g5+=G[5,j,e]*v;g6+=G[6,j,e]*v
                b1+=B[1,j,e]*v;b2+=B[2,j,e]*v;b3+=B[3,j,e]*v
            end
        end
        z1=g5*g5/2;z2=g6*g6/2;z3=g5*g6+g1*g2+g3*g4
        @inbounds begin
            d1=D[1,1,e]*z1+D[1,2,e]*z2+D[1,3,e]*z3
            d2=D[2,1,e]*z1+D[2,2,e]*z2+D[2,3,e]*z3
            d3=D[3,1,e]*z1+D[3,2,e]*z2+D[3,3,e]*z3
            s1=d1+D[1,1,e]*b1+D[1,2,e]*b2+D[1,3,e]*b3
            s2=d2+D[2,1,e]*b1+D[2,2,e]*b2+D[2,3,e]*b3
            s3=d3+D[3,1,e]*b1+D[3,2,e]*b2+D[3,3,e]*b3
            energy[e,trajectory]=(b1+z1/2)*d1+(b2+z2/2)*d2+(b3+z3/2)*d3
            for j in 1:18
                k=index[j,e]
                if k>0
                    v=B[1,j,e]*d1+B[2,j,e]*d2+B[3,j,e]*d3+
                        g5*G[5,j,e]*s1+g6*G[6,j,e]*s2+
                        (g6*G[5,j,e]+g5*G[6,j,e]+g2*G[1,j,e]+g1*G[2,j,e]+
                         g4*G[3,j,e]+g3*G[4,j,e])*s3
                    CUDA.@atomic force[k,trajectory]+=v
                end
            end
        end
    end
    return
end

function power_kernel!(N,z,decay,wd,omega,n,nb)
    trajectory=blockIdx().x;thread=threadIdx().x
    cache=CuStaticSharedArray(Float64,256)
    value=0.
    @inbounds for j in thread:256:n
        p=wd[j]*imag(z[j,trajectory])-decay[j]*real(z[j,trajectory])
        value+=2decay[j]*p*p/omega
    end
    cache[thread]=value;sync_threads()
    offset=128
    while offset>0
        if thread<=offset;cache[thread]+=cache[thread+offset];end
        sync_threads();offset÷=2
    end
    if thread==1;@inbounds N[n+1,trajectory]=ComplexF64(cache[1],0.);end
    return
end

struct Cache
    phi::CuMatrix{Float64}
    index::CuMatrix{Int32}
    B::CuArray{Float64,3}
    G::CuArray{Float64,3}
    D::CuArray{Float64,3}
    decay::CuVector{Float64}
    wd::CuVector{Float64}
    r::CuMatrix{Float64}
    q::CuMatrix{Float64}
    force::CuMatrix{Float64}
    modalforce::CuMatrix{Float64}
    energy::CuMatrix{Float64}
    omega::Float64
end

function cache(m,nb)
    m.kernel isa Vector{ShellPoint} || error("GPU shell/plate kernel required")
    CUDA.functional() || error("Functional CUDA device required")
    n=m.n;ne=length(m.kernel)
    index=zeros(Int32,18,ne);B=zeros(3,18,ne);G=zeros(6,18,ne);D=zeros(3,3,ne)
    for (e,p) in enumerate(m.kernel)
        index[:,e]=collect(p.index);B[:,:,e]=p.B;G[:,:,e]=p.G;D[:,:,e]=p.D
    end
    decay=(m.metadata["rayleigh_mass"].+m.metadata["rayleigh_stiffness"].*m.omega.^2)./2
    wd=sqrt.(m.omega .^ 2 .- decay .^ 2)
    all(>(0),wd) || error("This full complex modal chart requires underdamped modes")
    c=Cache(CuArray(m.modes),CuArray(index),CuArray(B),CuArray(G),CuArray(D),
        CuArray(decay),CuArray(wd),CUDA.zeros(Float64,n,nb),CUDA.zeros(Float64,n,nb),CUDA.zeros(Float64,n,nb),
        CUDA.zeros(Float64,n,nb),CUDA.zeros(Float64,ne,nb),m.omega[m.reference_mode])
    return c,decay,wd
end

function force!(c,q)
    fill!(c.force,0.)
    ne=size(c.index,2);nb=size(q,2)
    @cuda threads=128 blocks=cld(ne*nb,128) shell_force_kernel!(c.force,c.energy,q,
        c.index,c.B,c.G,c.D,ne,nb)
    return nothing
end

function rhs!(N,z,c)
    n=size(c.phi,1);nb=size(z,2)
    @views @. c.r=real(z[1:n,:])
    if 2<=nb<=8
        GPUBatched.forward!(c.q,c.phi,c.r)
    else
        mul!(c.q,c.phi,c.r)
    end
    force!(c,c.q)
    if 2<=nb<=8
        GPUBatched.transpose!(c.modalforce,c.phi,c.force)
    else
        mul!(c.modalforce,transpose(c.phi),c.force)
    end
    @views @. N[1:n,:]=-im*c.modalforce/(c.wd*c.omega)
    @cuda threads=256 blocks=nb power_kernel!(N,z,c.decay,c.wd,c.omega,n,nb)
    nothing
end

function phis(z)
    if abs(z)<0.5
        p1=zero(z);p2=zero(z);p3=zero(z)
        term=one(z)
        for k in 0:30
            p1+=term/(k+1);p2+=term/((k+1)*(k+2));p3+=term/((k+1)*(k+2)*(k+3))
            term*=z/(k+1)
        end
        return p1,p2,p3
    end
    p1=expm1(z)/z;p2=(p1-1)/z;p3=(p2-1/2)/z
    return p1,p2,p3
end

function coefficients(lambda,h)
    E=exp.(h.*lambda);E2=exp.((h/2).*lambda)
    Q=[h/2*phis(h*l/2)[1] for l in lambda]
    f1=similar(lambda);f2=similar(lambda);f3=similar(lambda)
    for j in eachindex(lambda)
        p1,p2,p3=phis(h*lambda[j])
        f1[j]=h*(p1-3p2+4p3);f2[j]=h*(p2-2p3);f3[j]=h*(-p2+4p3)
    end
    return CuArray.((E,E2,Q,f1,f2,f3))
end

function force_parity(m)
    c,_,_=cache(m,1)
    q=0.2.*m.qscale.*sin.(collect(1:m.n))
    copyto!(c.q,reshape(q,:,1));force!(c,c.q)
    fg=vec(Array(c.force));fc=zeros(m.n)
    ec=nonlinear!(fc,m.kernel,q);eg=sum(Array(c.energy))
    force_error=norm(fg-fc)/max(norm(fc),eps())
    energy_error=abs(eg-ec)/max(abs(ec),eps())
    force_error<1e-11 && energy_error<1e-11 || error("CPU/GPU force mismatch")
    return Dict("force_relative_error"=>force_error,"potential_relative_error"=>energy_error,
        "device"=>string(CUDA.device()),"precision"=>"Float64","all_modes_retained"=>m.n)
end

function step!(z,c,weights,buffers,evaluate! = rhs!)
    E,E2,Q,f1,f2,f3=weights
    N0,Na,Nb,Nc,a,b,cc=buffers
    evaluate!(N0,z,c)
    @. a=E2*z+Q*N0
    evaluate!(Na,a,c)
    @. b=E2*z+Q*Na
    evaluate!(Nb,b,c)
    @. cc=E2*a+Q*(2Nb-N0)
    evaluate!(Nc,cc,c)
    @. z=E*z+f1*N0+2*f2*(Na+Nb)+f3*Nc
    return nothing
end

function integrate(m,Q0;substeps=8,periods=32,samples_per_period=128,label="")
    nb=size(Q0,2);n=m.n;c,decay,wd=cache(m,nb)
    modal=m.modes'*(m.M*Q0)
    reconstruction=m.modes*modal
    reconstruction_error=maximum(norm((reconstruction[:,i]-Q0[:,i])./m.qscale) for i in 1:nb)
    reconstruction_error<1e-8 || error("Full modal inverse mismatch")
    z=CuArray(vcat(complex.(modal,(decay./wd).*modal),zeros(ComplexF64,1,nb)))
    lambda=vcat(complex.(-decay,-wd)./c.omega,0.)
    h=2pi/(samples_per_period*substeps)
    weights=coefficients(lambda,h)
    N0=similar(z);Na=similar(z);Nb=similar(z);Nc=similar(z)
    a=similar(z);b=similar(z);cc=similar(z)
    buffers=(N0,Na,Nb,Nc,a,b,cc)
    ns=periods*samples_per_period+1
    x=Array{Float64}(undef,2n,ns,nb);diss=zeros(ns,nb)
    x[1:n,1,:]=Q0;x[n+1:2n,1,:].=0
    # Compile the complete kernel path before reporting integration time.
    rhs!(N0,z,c);CUDA.synchronize()
    started=time_ns();next_report=started+UInt64(30_000_000_000)
    for k in 1:(ns-1)*substeps
        step!(z,c,weights,buffers)
        if k%substeps==0
            output=k÷substeps+1
            zh=Array(z)
            all(isfinite,zh) || error("Nonfinite exponential solution at reference period $(k/(samples_per_period*substeps)); substeps=$substeps")
            # Dense transforms use the same full modal basis as the GPU stages.
            @views @. c.r=real(z[1:n,:])
            mul!(c.q,c.phi,c.r)
            x[1:n,output,:]=Array(c.q)
            @views @. c.r=c.wd*imag(z[1:n,:])-c.decay*real(z[1:n,:])
            mul!(c.q,c.phi,c.r)
            x[n+1:2n,output,:]=Array(c.q)
            diss[output,:]=real.(zh[end,:])
        end
        if time_ns()>=next_report
            println("GPU_PROGRESS ",m.id,"/",m.configuration," ",label," periods=",
                round(k/(samples_per_period*substeps);digits=3),"/",periods," batch=",nb)
            flush(stdout);next_report=time_ns()+UInt64(30_000_000_000)
        end
    end
    CUDA.synchronize();elapsed=(time_ns()-started)/1e9
    times=collect(range(0.,2pi*periods/c.omega,length=ns))
    energies=zeros(ns,nb);powers=zeros(ns,nb);work=zeros(n)
    for j in 1:nb,k in 1:ns
        q=view(x,1:n,k,j);v=view(x,n+1:2n,k,j)
        energies[k,j]=dot(v,m.M*v)/2+dot(q,m.K*q)/2+nonlinear!(work,m.kernel,q)
        powers[k,j]=dot(v,m.C*v)
    end
    diagnostics=[Dict{String,Any}("wall_seconds_batch"=>elapsed,"substeps_per_output"=>substeps,
        "maximum_internal_step_over_reference_period"=>1/(samples_per_period*substeps),
        "initial_energy"=>energies[1,j],"final_energy"=>energies[end,j],
        "energy_balance_relative"=>maximum(abs.(energies[:,j].+diss[:,j].-energies[1,j]))/energies[1,j],
        "minimum_damping_power"=>minimum(powers[:,j]),"full_modal_reconstruction_error"=>reconstruction_error,
        "all_modes_retained"=>n,"solver"=>"Float64 GPU full-state Cox-Matthews ETDRK4",
        "qdot_equals_v_rhs"=>true,"device"=>string(CUDA.device())) for j in 1:nb]
    return (;x,t=times,energy=energies,power=powers,dissipated=diss,diagnostics)
end

end
