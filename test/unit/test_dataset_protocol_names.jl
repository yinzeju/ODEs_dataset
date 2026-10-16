using Test, JLD2
import JSON
include(joinpath(@__DIR__, "..", "..", "src", "data", "dataset2_nv", "Dataset2NV.jl"))

@testset "Dataset2 naming preserves frozen data compatibility" begin
    root = normpath(joinpath(@__DIR__, "..", ".."))
    @test Dataset2NV === TestSub2NV
    model = Dataset2NV.beam_model(; elements=12)
    @test model isa Dataset2NV.MechanicalModel
    @test model.n == 33
    pointer = JSON.parsefile(joinpath(root, "data", "dataset2_active.json"))
    @test pointer["dataset_code"] == "Dataset-2"
    manifest = joinpath(root, pointer["manifest"])
    @test Dataset2NV.file_sha(manifest) == pointer["sha256"]
    folder = joinpath(dirname(manifest), "VK-BEAM-CC", "BASE")
    data = Dataset2NV.load_learner_view(folder, "SKDM9_train_001")
    @test size(data["x"]) == (66, 8193)
    @test data["split"] == "train"
    @test_throws ErrorException Dataset2NV.load_learner_view(folder, "../audit_only/mechanical_model")
    current = JSON.parsefile(joinpath(root, "configs", "releases", "dataset2_structural_v2.json"))
    @test current["protocol"] == "Dataset-2"
    @test current["scope"] == ["MECH-FE"]
    @test !haskey(current, "hv_generation")
end
