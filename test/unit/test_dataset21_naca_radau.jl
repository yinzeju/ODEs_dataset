"--execute-tests" in ARGS || error("Explicit execution authorization required")
using Test,LinearAlgebra,SparseArrays,Random
include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
const NACA=Dataset21NACA

function synthetic_model(M,K,C)
    n=size(M,1)
    mesh=NACA.WingMesh(zeros(1,3),zeros(Int,0,3),Int[],Int[],"synthetic")
    return NACA.WingModel(mesh,collect(1:n),NACA.ShellElement[],zeros(Int32,324,0),
        sparse(M),sparse(K),sparse(C),fill(2.,n),Matrix{Float64}(I,n,n),0.,0.,ones(n))
end

@testset "Radau tableau and mechanical stage decoupling" begin
    A,c,b=NACA.radau_tableau()
    @test A*ones(3)≈c
    @test b≈A[3,:]
    for k in 0:4;@test dot(b,c.^k)≈1/(k+1);end
    m=synthetic_model([2. .1 0.;.1 1. .1;0. .1 3.],
        [9. -2. 0.;-2. 7. -1.;0. -1. 5.],
        [.2 .01 0.;.01 .3 .02;0. .02 .4])
    h=.03;cache=NACA.RadauCache(m,h)
    residual=randn(Xoshiro(17),3,3)
    correction=NACA.radau_chord_correction(residual,cache.systems[h],cache)
    direct=kron(sparse(cache.inverse_A^2/h^2),m.M)+
        kron(sparse(cache.inverse_A/h),m.C)+kron(sparse(I,3,3),m.K)
    @test norm(vec(correction)-direct\vec(residual))/norm(correction)<1e-12
end

@testset "Radau analytic decay and strongly overdamped initial layer" begin
    cfg=NACA.load_config(joinpath(NACA.ROOT,"configs/releases/dataset21_naca_v1_r5.json"))
    cfg["solver"]["integrator"]="radau5"
    cfg["solver"]["newton_relative_tolerance"]=1e-13
    m=synthetic_model(ones(1,1),fill(4.,1,1),fill(.1,1,1))
    mktempdir() do folder
        path=joinpath(folder,"oscillator.h5")
        receipt=NACA.integrate_to_file(path,m,[.01],cfg;frames=101,dt=.01,substeps=1,linear=true)
        alpha=.05;wd=sqrt(4-alpha^2)
        expected=.01exp(-alpha)*(cos(wd)+alpha/wd*sin(wd))
        NACA.HDF5.h5open(path,"r") do f
            @test abs(f["x"][1,101]-expected)<1e-11
        end
        @test receipt["max_energy_balance_relative"]<1e-8
        stiff=synthetic_model(ones(1,1),fill(1e8,1,1),fill(1e8,1,1))
        stiffpath=joinpath(folder,"stiff.h5")
        NACA.integrate_to_file(stiffpath,stiff,[.01],cfg;frames=11,dt=.001,substeps=1,linear=true)
        slow=-2e8/(1e8+sqrt(1e16-4e8));fast=(-1e8-sqrt(1e16-4e8))/2
        cs=-.01fast/(slow-fast);cf=.01-cs
        NACA.HDF5.h5open(stiffpath,"r") do f
            @test abs(f["x"][1,11]-(cs*exp(.01slow)+cf*exp(.01fast)))<1e-10
            @test abs(f["x"][2,2]-(slow*cs*exp(.001slow)+fast*cf*exp(.001fast)))<1e-6
        end
    end
end

struct DuffingBackend
    force::Vector{Float64}
    tangent::SparseMatrixCSC{Float64,Int}
end
function NACA.evaluate!(backend::DuffingBackend,m,q;tangent=true,linear=false)
    backend.force[1]=100q[1]^3
    tangent && (backend.tangent[1,1]=300q[1]^2)
    return (energy=25q[1]^4,strain=0.)
end
@testset "Radau consistent nonlinear stage Jacobian" begin
    m=synthetic_model(ones(1,1),fill(4.,1,1),zeros(1,1))
    backend=DuffingBackend(zeros(1),spzeros(1,1));h=.05;cache=NACA.RadauCache(m,h)
    q=[.2];v=[.1];Z=reshape([.001,.003,.005],1,3)
    residual,_,_=NACA.radau_residual(m,backend,q,v,Z,h,cache)
    correction=NACA.radau_consistent_correction(m,backend,q,Z,h,cache,residual)
    direction=reshape([.3,-.2,.4],1,3);epsilon=1e-6
    rp,_,_=NACA.radau_residual(m,backend,q,v,Z+epsilon*direction,h,cache)
    rm,_,_=NACA.radau_residual(m,backend,q,v,Z-epsilon*direction,h,cache)
    # Reconstruct the stage Jacobian through independent directional differences.
    jac=zeros(3,3)
    for j in 1:3
        e=zeros(1,3);e[j]=epsilon
        plus,_,_=NACA.radau_residual(m,backend,q,v,Z+e,h,cache)
        minus,_,_=NACA.radau_residual(m,backend,q,v,Z-e,h,cache)
        jac[:,j]=vec((plus-minus)/(2epsilon))
    end
    @test norm(jac*vec(correction)-vec(residual))/norm(residual)<1e-8
    @test norm(jac*vec(direction)-vec((rp-rm)/(2epsilon)))/norm(rp-rm)*2epsilon<1e-8
end
