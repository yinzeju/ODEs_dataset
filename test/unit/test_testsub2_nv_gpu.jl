using Test, LinearAlgebra, JLD2, CUDA
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_exponential.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_physical.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_modal.jl"))

nonlinear_scalar!(N,z,unused)=(@. N=z*z; nothing)

function scalar_solution(nsteps)
    z=CuArray(reshape(ComplexF64[0.2],1,1))
    weights=GPUExponential.coefficients(ComplexF64[-1.],1/nsteps)
    buffers=ntuple(_->similar(z),7)
    for k in 1:nsteps
        GPUExponential.step!(z,nothing,weights,buffers,nonlinear_scalar!)
    end
    return only(Array(z))
end

function main()
    BLAS.set_num_threads(2)
    CUDA.allowscalar(false)
    @testset "GPU ETDRK4 and complete mechanical coordinate transform" begin
        @test CUDA.functional()
        @test GPUExponential.phis(0.0im)==(1.0+0im,0.5+0im,1/6+0im)
        exact=1/(1+4exp(1.))
        e4=abs(scalar_solution(4)-exact);e8=abs(scalar_solution(8)-exact)
        @test e8<1e-7
        @test 12<e4/e8<20
        root=normpath(joinpath(@__DIR__,"..",".."))
        for id in ("shell_nr","shell_ir12","plate")
            m=load(joinpath(root,"runs","testsub2_nv","models",id*".jld2"),"model")
            println("SPECTRAL_RANGE ",id," omega_min=",minimum(m.omega)," omega_max=",maximum(m.omega),
                " reference=",m.omega[m.reference_mode])
            parity=GPUExponential.force_parity(m)
            @test parity["force_relative_error"]<1e-11
            @test parity["potential_relative_error"]<1e-11
            c,decay,wd=GPUExponential.cache(m,1)
            q=0.001.*m.qscale.*sin.(collect(1:m.n))
            v=0.0002.*m.qscale.*c.omega.*cos.(collect(1:m.n))
            r=m.modes'*(m.M*q);p=m.modes'*(m.M*v)
            z=CuArray(reshape(vcat(complex.(r,(p.+decay.*r)./wd),0.),:,1))
            N=similar(z);GPUExponential.rhs!(N,z,c)
            dz=complex.(-decay,-wd).*Array(z)[1:m.n,1]+c.omega.*Array(N)[1:m.n,1]
            qdot=m.modes*real.(dz)
            vdot=m.modes*(wd.*imag.(dz).-decay.*real.(dz))
            force=zeros(m.n);TestSub2NV.nonlinear!(force,m.kernel,q)
            expected=-(m.M\(m.K*q+m.C*v+force))
            @test norm(qdot-v)/norm(v)<1e-9
            @test norm(vdot-expected)/norm(expected)<1e-9
            @test norm(m.modes*r-q)/norm(q)<1e-10
            physical=GPUPhysical.cache(m,1,1.)
            u=CuArray(reshape(vcat(q./m.qscale,v./(c.omega.*m.qscale),0.),:,1))
            du=similar(u);GPUPhysical.rhs!(du,u,physical,0.)
            derivative=Array(du)
            @test norm(derivative[1:m.n,1].*(c.omega.*m.qscale)-v)/norm(v)<1e-12
            acceleration=derivative[m.n+1:2m.n,1].*(c.omega^2 .*m.qscale)
            @test norm(acceleration-expected)/norm(expected)<1e-11
            @test isapprox(derivative[end,1]*c.omega,dot(v,m.C*v);rtol=1e-12)
            scales=1 ./ (1 .+ collect(1:m.n)./m.n)
            scaled=copy(z);@views scaled[1:m.n,:]./=CuArray(scales)
            modal_cache=GPUModal.Cache(c,similar(z),CuArray(vcat(scales,1.)),
                CuArray(vcat(scales,2.)),CuArray(vcat(complex.(-decay,-wd)./c.omega,0.)))
            modal_du=similar(scaled);GPUModal.rhs!(modal_du,scaled,modal_cache,0.)
            modal_derivative=Array(modal_du)
            unscaled=c.omega.*scales.*modal_derivative[1:m.n,1]
            @test norm(unscaled-dz)/norm(dz)<1e-12
            @test isapprox(real(modal_derivative[end,1])*2c.omega,dot(v,m.C*v);rtol=1e-12)
            for nb in (7,18)
                input=reshape(sin.(collect(1:m.n*nb)),m.n,nb)
                device_input=CuArray(input);device_output=similar(device_input)
                GPUExponential.GPUBatched.forward!(device_output,c.phi,device_input)
                @test norm(Array(device_output)-m.modes*input)/norm(m.modes*input)<1e-12
                GPUExponential.GPUBatched.transpose!(device_output,c.phi,device_input)
                @test norm(Array(device_output)-m.modes'*input)/norm(m.modes'*input)<1e-12
            end
        end
    end
end
main()
