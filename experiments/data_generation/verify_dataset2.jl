# Read back all current Dataset-2 trajectories without integration or model scoring.
using JLD2
import JSON
include(joinpath(@__DIR__, "..", "..", "src", "data", "dataset2_nv", "Dataset2NV.jl"))

function main()
    root = normpath(joinpath(@__DIR__, "..", ".."))
    pointer = JSON.parsefile(joinpath(root, "data", "dataset2_active.json"))
    path = joinpath(root, pointer["manifest"])
    Dataset2NV.file_sha(path) == pointer["sha256"] || error("Release manifest checksum")
    manifest = JSON.parsefile(path)
    checked = 0
    for config in manifest["configurations"]
        folder = joinpath(dirname(path), config["relative_root"])
        learner_path = joinpath(folder, "manifests", "learner_manifest.json")
        Dataset2NV.file_sha(learner_path) == config["learner_manifest_sha256"] || error("Learner manifest checksum")
        learner = JSON.parsefile(learner_path)
        counts = Dict(split => 0 for split in ("train", "val", "test"))
        ids = Set{String}()
        for row in learner["trajectories"]
            row["trajectory_id"] in ids && error("Duplicate trajectory ID")
            push!(ids, row["trajectory_id"])
            data = Dataset2NV.load_learner_view(folder, row["trajectory_id"])
            size(data["x"]) == (66, learner["snapshot_count"]) || error("State shape")
            length(data["t"]) == learner["snapshot_count"] || error("Time shape")
            all(isfinite, data["x"]) && all(isfinite, data["t"]) || error("Nonfinite state/time")
            data["trajectory_id"] == row["trajectory_id"] || error("Serialized ID")
            data["split"] == row["split"] || error("Serialized split")
            maximum(abs.(diff(data["t"]) .- learner["dt_output"])) < 1e-12 || error("Output grid")
            counts[row["split"]] += 1
            checked += 1
        end
        counts == Dict("train"=>96, "val"=>24, "test"=>24) || error("Split counts")
    end
    println("DATASET2_READBACK_PASSED trajectories=", checked, " integration_calls=0")
end

main()
