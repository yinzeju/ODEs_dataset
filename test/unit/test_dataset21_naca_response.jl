"--execute-tests" in ARGS || error("Explicit execution authorization required")
using Test,LinearAlgebra,SparseArrays
include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
const NACA=Dataset21NACA

function diagnostic_model(omega)
    mesh=NACA.WingMesh(zeros(4,3),zeros(Int,0,3),Int[],Int[],"synthetic")
    mass=sparse(I,4,4);stiffness=spdiagm(0=>omega.^2)
    return NACA.WingModel(mesh,[1,7,13,19],NACA.ShellElement[],zeros(Int32,324,0),
        mass,stiffness,spzeros(4,4),omega,Matrix{Float64}(I,4,4),0.,0.,ones(4))
end
function analytic_trace(path,m,times)
    amplitude=[.1,.04,.025,.01]
    q=amplitude.*cos.(m.omega.*transpose(times))
    v=-amplitude.*m.omega.*sin.(m.omega.*transpose(times))
    energy=vec(sum(v.^2+m.omega.^2 .*q.^2;dims=1))./2
    NACA.HDF5.h5open(path,"w") do file
        file["x"]=vcat(q,v);file["t"]=times;file["energy"]=energy
    end
end

@testset "Phase-resolved convergence retains accumulated phase drift" begin
    m=diagnostic_model(1.01.*[2.,3.,4.,5.]);fine=diagnostic_model([2.,3.,4.,5.])
    times=collect(0.:.01:20.)
    cfg=NACA.load_config(joinpath(NACA.ROOT,"configs/releases/dataset21_naca_v1_r5.json"))
    cfg["sampling"]["dt_seconds"]=.01
    cfg["qualification"]["phase_rate_relative"]=.03
    cfg["qualification"]["envelope_relative"]=.05
    cfg["qualification"]["spatial_energy_absolute"]=.05
    mktempdir() do folder
        a=joinpath(folder,"coarse.h5");b=joinpath(folder,"fine.h5")
        analytic_trace(a,m,times);analytic_trace(b,fine,times)
        coarse_features=NACA.mechanical_features(a,m);fine_features=NACA.mechanical_features(b,fine)
        result=NACA.response_convergence(coarse_features,coarse_features,fine_features,fine_features,m,fine,cfg)
        @test result["passed"]
        @test result["envelope_relative"]<1e-12
        @test result["normalized_energy_absolute"]<1e-12
        @test all(abs(row["rate_relative"]-.01)<1e-12 for row in result["phase"])
        @test maximum(row["maximum_active_cumulative_phase_difference_rad"] for row in result["phase"])>.9
        @test NACA.trajectory_difference(a,b,m)>.05
        @test result["nonlinear_energy_signal"]==0
        @test result["nonlinear_energy_feature_error"]==0
    end
    @test NACA.centered_average(reshape(collect(0.:4.),1,:),3)≈reshape([.5,1.,2.,3.,3.5],1,:)
end

@testset "Matched FE initial coefficients retain physical signs" begin
    fine=diagnostic_model([2.,3.,4.,5.]);fine.modes[:,2].*=-1
    metadata=Dict("kind"=>"modal_displacement","modes"=>[1,2,3,4],
        "physical_shape_coefficients_m"=>[.001,-.002,.003,-.004])
    rows=[Dict("candidate_mode"=>j,"fine_mode"=>j,"fine_mode_sign"=>(j==2 ? -1 : 1)) for j in 1:4]
    q,_=NACA.matched_initial_state(fine,metadata,Dict("modal_comparison"=>rows),Dict())
    @test q≈[.001,-.002,.003,-.004]
end
