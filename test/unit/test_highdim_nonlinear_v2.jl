using Test

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "highdim_nonlinear_v2_generation.jl"))

@testset "highdim_nonlinear_v2 configuration and dynamics" begin
    formal = hdnd_profile(PROJECT_ROOT, :formal)
    @test formal.split_counts == (train = 320, val = 80, test = 80)
    @test total_trajectory_count(formal) == 480
    @test formal.l96_steps == 2_048
    @test formal.pde_steps == 5_120
    @test maximum(abs.(diff(time_vector(formal.pde_steps, 0.05)) .- 0.05)) <= 8eps(256.0)

    l96 = HDNDL96Spec()
    @test l96.nx == 40
    @test l96.tau == 0.05
    @test l96.reltol == 1.0e-10
    @test hdnd_l96_boundary_check(l96)

    ks = HDNDKSSpec()
    @test ks.nx == 64
    @test ks.dt == 0.01
    @test ks.contour_nodes == 64
    ks_initial = sample_hdnd_ks_initial_condition(MersenneTwister(1), ks)
    @test abs(mean(ks_initial)) <= 1.0e-14
    @test 0.5 <= sqrt(mean(abs2, ks_initial)) <= 1.0

    fhn = HDNDFHNSpec()
    @test fhn.nx == 64
    @test fhn.tau == 0.05
    @test hdnd_fhn_regime_labels(formal, "train") |> length == 320
    labels = hdnd_fhn_regime_labels(formal, "train")
    @test count(==("active"), labels) == 160
    @test count(==("formation"), labels) == 64
    @test count(==("collision"), labels) == 64
    @test count(==("recovery"), labels) == 32
end

@testset "highdim_nonlinear_v2 minimal trajectories" begin
    l96 = HDNDL96Spec()
    l96_initial = sample_hdnd_l96_initial_condition(MersenneTwister(2), l96)
    l96_trajectory = solve_hdnd_l96_trajectory(l96_initial, l96, 0.1, 2)
    @test size(l96_trajectory) == (3, 40)
    @test all(isfinite, l96_trajectory)

    ks = HDNDKSSpec()
    ks_initial = sample_hdnd_ks_initial_condition(MersenneTwister(3), ks)
    ks_trajectory = solve_hdnd_ks_trajectory(ks_initial, ks, 0.1, 2)
    @test size(ks_trajectory) == (3, 64)
    @test maximum(abs.(mean(ks_trajectory; dims = 2))) <= 1.0e-12

    fhn = HDNDFHNSpec()
    fhn_initial = sample_hdnd_fhn_initial_condition(MersenneTwister(4), fhn, "formation")
    fhn_trajectory = solve_hdnd_fhn_trajectory(fhn_initial, fhn, 0.0, 2)
    @test size(fhn_trajectory) == (3, 128)
    @test all(isfinite, fhn_trajectory)
end
