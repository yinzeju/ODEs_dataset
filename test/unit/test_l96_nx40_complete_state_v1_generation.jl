using Test

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "l96_nx40_complete_state_v1_generation.jl"))

@testset "l96_nx40_complete_state_v1 contracts" begin
    config = L96CompleteStateConfig()
    @test config.Nx == 40
    @test config.F0 == 8.0
    @test config.dt_internal == 0.005
    @test config.q_save == 10
    @test config.tau == 0.05
    @test config.burn_in_steps == 20_000
    @test config.snapshots == 2_049
    @test l96_boundary_index_check(config)

    splits = l96_split_indices(config)
    @test length(splits["train"]) == 288
    @test length(splits["val"]) == 96
    @test length(splits["test"]) == 96

    windows = l96_window_counts(config, splits)
    @test windows["one_step"]["train"] == 589_824
    @test windows["one_step"]["val"] == 196_608
    @test windows["one_step"]["test"] == 196_608
    @test windows["rollout"]["starts_per_trajectory"] == 1_985
    @test windows["rollout"]["train"] == 571_680
    @test windows["rollout"]["val"] == 190_560
    @test windows["rollout"]["test"] == 190_560
end
