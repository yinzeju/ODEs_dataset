using Test, JLD2
import JSON
include(joinpath(@__DIR__, "..", "..", "src", "data", "dataset2_nv", "Dataset2NV.jl"))

@testset "Dataset2 naming preserves frozen data compatibility" begin
    root = normpath(joinpath(@__DIR__, "..", ".."))
    @test Dataset2NV === TestSub2NV
    model = JLD2.load(joinpath(root, "runs", "testsub2_nv", "models", "duffing.jld2"), "model")
    @test model isa Dataset2NV.MechanicalModel
    @test model.n == 8
    pointer = JSON.parsefile(joinpath(root, "data", "dataset2_active.json"))
    @test pointer["dataset_code"] == "Dataset-2"
    manifest = joinpath(root, pointer["manifest"])
    @test Dataset2NV.file_sha(manifest) == pointer["sha256"]
    folder = joinpath(dirname(manifest), "OSC-DUFFING8", "BASE")
    data = Dataset2NV.load_learner_view(folder, "CAN_train_001")
    @test size(data["x"]) == (16, 4097)
    @test data["split"] == "train"
    @test_throws ErrorException Dataset2NV.load_learner_view(folder, "../audit_only/mechanical_model")
    current = JSON.parsefile(joinpath(root, "configs", "releases", "testsub2_nv_20261004.json"))
    @test current["protocol"] == "Dataset2-NV"
    @test current["scope"] == ["MECH-ODE", "MECH-FE"]
    @test !haskey(current, "hv_generation")
end
