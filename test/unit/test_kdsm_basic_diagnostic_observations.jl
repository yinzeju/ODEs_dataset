using Test

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "observations", "kdsm_basic_diagnostic_observations.jl"))

@testset "kdsm_basic identity observations" begin
    X = reshape(collect(Float64, 1:24), 3, 4, 2)
    tensors = kbasic_build_observations_and_targets(X)
    @test size(tensors["obs_phys"]) == (3, 4, 2)
    @test tensors["obs_phys"] == X
    @test tensors["obs_aug_full"] == X
    @test tensors["target_phys"] == X
end
