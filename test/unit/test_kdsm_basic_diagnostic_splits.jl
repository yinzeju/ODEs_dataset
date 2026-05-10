using Test
using TOML

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "splits", "kdsm_basic_diagnostic_splits.jl"))

@testset "kdsm_basic trajectory split" begin
    split_config = TOML.parsefile(joinpath(PROJECT_ROOT, "configs", "splits", "kdsm_basic_diagnostic_v1_split_trajectory_I.toml"))
    roles, counts = kbasic_build_trajectory_split_roles(64, split_config; difficulty = "default")
    @test counts == Dict("train" => 48, "val" => 8, "test" => 8)
    @test count(==("train"), roles) == 48
    @test count(==("val"), roles) == 8
    @test count(==("test"), roles) == 8
    @test all(role -> role in ("train", "val", "test"), roles)
end
