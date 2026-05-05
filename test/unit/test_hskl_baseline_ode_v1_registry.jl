## HSKL baseline ODE v1 registry invariants

using Test

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "hskl_baseline_ode_v1_generation.jl"))

@testset "HSKL baseline ODE v1 registry" begin
    systems = hskl_system_specs()
    profiles = hskl_difficulty_profiles()

    @test HSKL_BENCHMARK_VERSION == "hskl_baseline_ode_v1"
    @test HSKL_OBSERVATION_MODE == "full_state"
    @test HSKL_NOISE_LEVEL == "clean"
    @test length(systems) == 11
    @test Set(system.system_id for system in systems) == Set([
        "linear_diagonal",
        "linear_rotation_contraction",
        "linear_jordan_nonnormal",
        "damped_linear_oscillator",
        "van_der_pol",
        "duffing",
        "lotka_volterra",
        "fitzhugh_nagumo",
        "lorenz63",
        "rossler",
        "lorenz96",
    ])

    @test haskey(profiles, "medium")
    @test profiles["medium"]["M"] == 1024
    @test window_feasibility(profiles["medium"])["window_feasible"]

    for system in systems
        @test system.state_dim > 0
        @test system.dt > 0
        @test !isempty(system.regimes)
        @test all(regime -> haskey(regime, "parameter_regime"), system.regimes)
    end
end
