# These focused numerical checks are prepared, not executed during code-only work.
"--execute-tests" in ARGS || error("Numerical tests are disabled until execution is authorized")
using Test, LinearAlgebra, SparseArrays
include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
const NACA=Dataset21NACA

@testset "Allman source formulation and strain recovery" begin
    nodes=[0.1 0.2 0.3; 0.9 0.25 0.45; 0.3 0.8 0.65]
    M,K,B,G,D,Rb,Rm=NACA.shell_element(nodes,70e9,0.33,2700.,0.0015)
    @test issymmetric(Symmetric(M))
    @test minimum(eigvals(Symmetric(M)))>0
    @test norm(K-K')/norm(K)<1e-12
    recovered=zeros(18,18)
    for (i,j) in ((1,2),(2,3),(3,1))
        membrane=B+(Rm[i]+Rm[j])/2;bending=(Rb[i]+Rb[j])/2
        recovered .+= (membrane'*D*membrane+bending'*D*bending/3)/3
    end
    @test norm(recovered-K)/norm(K)<1e-10
    for d in 1:3
        translation=zeros(18);translation[d:6:18].=1.
        @test norm(K*translation)/norm(K)<1e-12
    end
end

@testset "Newmark linear solution, energy accounting and HDF5 round trip" begin
    mesh=NACA.WingMesh(zeros(1,3),zeros(Int,0,3),Int[],Int[],"synthetic")
    mass=sparse(reshape([1.],1,1));stiffness=sparse(reshape([4.],1,1));damping=sparse(reshape([0.1],1,1))
    m=NACA.WingModel(mesh,[1],NACA.ShellElement[],zeros(Int32,324,0),mass,stiffness,damping,
        [2.],ones(1,1),0.1,0.,[1.])
    cfg=NACA.load_config(joinpath(NACA.ROOT,"configs","releases","dataset21_naca_v1.json"))
    mktempdir() do folder
        path=joinpath(folder,"linear.h5")
        receipt=NACA.integrate_to_file(path,m,[0.01],cfg;frames=101,dt=0.01,substeps=4,linear=true)
        alpha=0.05;wd=sqrt(4-alpha^2)
        exact=0.01exp(-alpha)*(cos(wd)+alpha/wd*sin(wd))
        NACA.HDF5.h5open(path,"r") do f
            @test size(f["x"])==(2,101)
            @test abs(f["x"][1,101]-exact)<1e-7
            @test f["x"][2,1]==0
            @test f["t"][101]==1.
        end
        @test receipt["max_energy_balance_relative"]<1e-5
        @test receipt["sha256"]==NACA.filehash(path)
        cfg["solver"]["tangent_strategy"]="cached_linear_with_consistent_fallback"
        cachedpath=joinpath(folder,"cached_linear.h5")
        cached=NACA.integrate_to_file(cachedpath,m,[0.01],cfg;frames=101,dt=0.01,substeps=4,linear=true)
        @test NACA.trajectory_difference(path,cachedpath,m)<1e-10
        @test cached["consistent_factorizations"]==0
        @test cached["chord_corrections"]>0
    end
end

@testset "Pinned mesh identity and population plan" begin
    original=NACA.read_mesh(joinpath(NACA.source_root(),"examples","NACAWing","Wing.msh"))
    @test size(original.triangles,1)==49968
    @test 6(size(original.nodes,1)-length(original.fixed_nodes))==133920
    cfg=NACA.load_config(joinpath(NACA.ROOT,"configs","releases","dataset21_naca_v1.json"))
    @test cfg["damping"]["target_ratio"]==0.006
    @test cfg["sampling"]["frames"]==4096
    @test (cfg["sampling"]["frames"]-1)*cfg["sampling"]["dt_seconds"]≈3.276
    @test sum(values(cfg["initial_conditions"]["counts"]))==144
end

# GPU parity is part of the independently authorized qualify stage, never loaded here.

@testset "Closest surface mapping preserves six independent fields" begin
    nodes=[0. 0. 0.;1. 0. 0.;0. 1. 0.;0. 0. 2.]
    mesh=NACA.WingMesh(nodes,[1 2 3;1 2 4;1 3 4],[1,2,3],[1],"synthetic")
    points=[0.2 0.3 0.;0.2 0.3 0.4;-0.5 0.5 0.;2. 2. 0.;0. 0. 3.]
    expected=[0.2 0.3 0.;0. 0.3 0.4;0. 0.5 0.;0.5 0.5 0.;0. 0. 2.]
    map,distances=NACA.interpolation(mesh,points)
    nodal=zeros(6size(nodes,1))
    for i in axes(nodes,1),d in 1:3;nodal[6(i-1)+d]=nodes[i,d];end
    mapped=reshape(map*nodal,6,:)'
    @test mapped[:,1:3]≈expected atol=1e-13
    @test distances≈[0.,0.2,0.5,sqrt(4.5),1.] atol=1e-13
    @test map*ones(size(map,2))≈ones(size(map,1))
    @test mapped[:,4:6]==zeros(size(points,1),3)
end
