using Test
using TOML

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "windows", "kdsm_basic_diagnostic_windows.jl"))

@testset "kdsm_basic window metadata" begin
    windows = TOML.parsefile(joinpath(PROJECT_ROOT, "configs", "windows", "kdsm_basic_diagnostic_v1_windows.toml"))
    roles = vcat(fill("train", 48), fill("val", 8), fill("test", 8))
    metadata = kbasic_window_metadata(256, roles, windows)
    @test metadata["one_step"]["counts"]["train"] == 48 * 256
    @test metadata["rollout"]["counts"]["16"]["test"] == 8 * (256 - 16 + 1)
    @test metadata["rollout"]["horizons"] == [1, 2, 4, 8, 16]
end
