using Test, LinearAlgebra, Random, JLD2
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
using .TestSub2NV

@testset "Full mechanical contracts" begin
    BLAS.set_num_threads(1)
    root=normpath(joinpath(@__DIR__,"..",".."))
    for (id,n) in (("duffing",8),("beam",33),("shell_nr",1320),("shell_ir12",1320),("plate",606))
        m=load(joinpath(root,"runs","testsub2_nv","models",id*".jld2"),"model")
        @test m.n==n
        @test isposdef(Symmetric(Matrix(m.M)))
        @test norm(m.K-m.K')/norm(m.K)<1e-13
        @test norm(m.C-m.C')/norm(m.C)<1e-13
        @test minimum(eigvals(Symmetric(Matrix(m.C))))>=-1e-7
        rng=Xoshiro(37)
        p=TestSub2NV.integration_cache(m)
        u=vcat(0.01randn(rng,n),0.01randn(rng,n),0.)
        direction=randn(rng,2n+1)
        J=copy(p.Jbase);TestSub2NV.mechanical_jacobian!(J,u,p,0.)
        fp=zeros(2n+1);fm=similar(fp);h=1e-7
        TestSub2NV.mechanical_rhs!(fp,u+h*direction,p,0.)
        TestSub2NV.mechanical_rhs!(fm,u-h*direction,p,0.)
        @test norm((fp-fm)/(2h)-J*direction)/norm(J*direction)<1e-7
        @test fp[1:n]≈u[n+1:2n]+h*direction[n+1:2n]
        @test m.reference_mode==(id=="plate" ? 2 : 1)
    end
end

@testset "Canonical split and amplitude contracts" begin
    root=normpath(joinpath(@__DIR__,"..",".."))
    m=load(joinpath(root,"runs","testsub2_nv","models","duffing.jld2"),"model")
    population=TestSub2NV.initial_conditions(m)
    @test [count(ic->ic.split==s,population) for s in ("train","val","test")]==[12,4,4]
    @test all(isapprox(ic.meta["target_initial_nonlinear_exposure"],ic.meta["initial_nonlinear_exposure"];rtol=1e-12) for ic in population)
    second=TestSub2NV.initial_conditions(m)
    @test all(a.q==b.q for (a,b) in zip(population,second))
    mixtures=filter(ic->ic.meta["ic_family"]=="modal_mixture",population)
    @test all(all(>(0),ic.meta["modal_mixture_coefficients"]) for ic in mixtures)
    @test length(unique(ic.meta["modal_mixture_coefficients"] for ic in mixtures))==length(mixtures)
end
