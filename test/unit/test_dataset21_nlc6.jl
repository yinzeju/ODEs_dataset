using Test,LinearAlgebra,SparseArrays
include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
include(joinpath(@__DIR__,"..","..","src","data","dataset21_nlc6","Dataset21NLC6.jl"))
const NC=Dataset21NACA
const NL=Dataset21NLC6

function model()
    mesh=NC.WingMesh(zeros(1,3),zeros(Int,0,3),Int[],Int[],"synthetic")
    M=sparse([1.2 .1;.1 .8]);K=sparse([5. -.7;-.7 9.]);C=.02M+.003K
    return NC.WingModel(mesh,[1,2],NC.ShellElement[],zeros(Int32,324,0),M,K,C,
        [2.,3.],Matrix{Float64}(I,2,2),.02,.003,ones(2))
end

@testset "NLC6 passive forces and exact mechanical stage tangents" begin
    m=model();p=NL.Connectors(sparse([1. .2;-.3 1.]),[30.,50.],[.1,.2],[.1,.2])
    q=[.05,.08];v=[.04,-.02];d=NL.connector_values(p,q,v)
    @test d.potential>0 && d.power>=0
    @test NL.damping(p,zeros(2))==zeros(2)
    @test NL.damping_tangent(p,zeros(2))==zeros(2)
    for j in 1:2
        eps=1e-6;e=zeros(2);e[j]=eps
        value=NL.connector_values(p,q,v)
        grad=(NL.connector_values(p,q+e,v).potential-NL.connector_values(p,q-e,v).potential)/(2eps)
        @test isapprox(grad,(p.B*(p.kappa.*value.s.^3))[j];rtol=1e-8)
    end
    h=.03;cache=NL.StepCache(m,p,h);backend=NC.CPUBackend(m)
    Z=[.001 .004 .005;-.002 -.001 .002]
    residual,V,_=NL.stage_residual(m,backend,p,q,v,Z,h,cache)
    correction=NL.port_correction(m,backend,p,q,Z,V,h,cache,residual)
    direct=NL.port_correction(m,backend,p,q,Z,V,h,cache,residual;consistent=true)
    @test norm(correction-direct)/norm(direct)<1e-11
    J=zeros(6,6);eps=1e-7
    for j in 1:6
        e=zeros(2,3);e[j]=eps
        rp,_,_=NL.stage_residual(m,backend,p,q,v,Z+e,h,cache)
        rm,_,_=NL.stage_residual(m,backend,p,q,v,Z-e,h,cache)
        J[:,j]=vec((rp-rm)/(2eps))
    end
    @test norm(J*vec(correction)-vec(residual))/norm(residual)<1e-8
    @test isposdef(Symmetric(Matrix(p.B*Diagonal(d.stiffness)*transpose(p.B))))
    solver=Dict("newton_relative_tolerance"=>1e-13,"newton_max_iterations"=>20,"maximum_bisections"=>6,"maximum_chord_iterations"=>10)
    function solve(h)
        q=[.05,.08];v=zeros(2);E0=dot(q,m.K*q)/2+NL.connector_values(p,q,v).potential
        stats=NC.StepStatistics();cache=NL.StepCache(m,p,h);work=0.
        for _ in 1:round(Int,1/h)
            q,v,d0,dn=NL.advance(m,backend,p,q,v,h,solver,stats,cache);work+=d0+dn
        end
        E=dot(v,m.M*v)/2+dot(q,m.K*q)/2+NL.connector_values(p,q,v).potential
        return vcat(q,v),abs(E+work-E0)/E0,E/E0
    end
    x,error,ratio=solve(.01);fine,ef,rf=solve(.005)
    @test norm(x-fine)/norm(fine)<1e-8
    @test error<1e-8 && ef<error
    @test 0<ratio<1 && 0<rf<1
end
