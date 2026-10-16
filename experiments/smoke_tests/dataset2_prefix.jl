using Test, JLD2, SHA
include(joinpath(@__DIR__, "..", "postprocessing", "copy_dataset2_prefix.jl"))

@testset "Saved-state prefix preservation without integration" begin
    mktempdir() do folder
        source = joinpath(folder, "original.jld2")
        destination = joinpath(folder, "prefix.jld2")
        x = reshape(collect(1.0:30.0), 3, 10)
        JLD2.jldsave(source; x, t=collect(0.0:0.1:0.9), split="train",
            trajectory_id="original", state_layout="state,time", units="test")
        digest = Dataset2Prefix.file_sha(source)
        result = Dataset2Prefix.copy_prefix(source, destination, 9, digest, "canonical")
        @test result.snapshot_count == 9
        @test JLD2.load(destination, "x") == x[:, 1:9]
        @test JLD2.load(destination, "trajectory_id") == "canonical"
        @test Dataset2Prefix.file_sha(source) == digest
        @test_throws ErrorException Dataset2Prefix.copy_prefix(source, destination, 9, digest, "canonical")
        @test_throws ErrorException Dataset2Prefix.copy_prefix(source, joinpath(folder, "bad.jld2"), 9, "wrong", "canonical")
    end
end
