"""Copy explicitly requested saved-state prefixes; never integrate or overwrite a file."""
module Dataset2Prefix

using JLD2, SHA
import JSON

file_sha(path) = open(io -> bytes2hex(sha256(io)), path)

function copy_prefix(source, destination, frames, expected_sha, trajectory_id)
    isfile(destination) && error("Destination already exists: $destination")
    file_sha(source) == expected_sha || error("Source checksum mismatch")
    saved = JLD2.load(source)
    x, t = saved["x"], saved["t"]
    1 < frames <= size(x, 2) == length(t) || error("Invalid frame count")
    eltype(x) === Float64 && all(isfinite, x) || error("Invalid source states")
    result = Dict{String,Any}(key => saved[key] for key in
        ("split", "state_layout", "units"))
    result["x"] = x[:, 1:frames]
    result["t"] = t[1:frames]
    result["trajectory_id"] = trajectory_id
    result["source_trajectory_id"] = saved["trajectory_id"]
    result["source_snapshot_count"] = length(t)
    mkpath(dirname(destination))
    JLD2.jldopen(destination, "w") do file
        for (key, value) in result
            file[key] = value
        end
    end
    reread = JLD2.load(destination)
    isequal(reread["x"], result["x"]) || error("State readback mismatch")
    isequal(reread["t"], result["t"]) || error("Time readback mismatch")
    reread["split"] == saved["split"] || error("Split changed")
    initial_sha = bytes2hex(sha256(reinterpret(UInt8, x[:, 1])))
    (; source_sha256=expected_sha, sha256=file_sha(destination),
       source_snapshot_count=length(t), snapshot_count=frames,
       state_dimension=size(x, 1), initial_state_sha256=initial_sha,
       time_start=t[1], time_end=t[frames], dt_output=t[2]-t[1],
       full_prefix_readback=true, exact_initial_state=true)
end

function main(args)
    length(args) == 2 || error("Usage: copy_dataset2_prefix.jl REQUESTS.json RECEIPT.json")
    ispath(args[2]) && error("Receipt already exists")
    request = JSON.parsefile(args[1])
    receipts = Any[]
    for row in request["files"]
        result = copy_prefix(row["source"], row["destination"], row["frames"],
            row["source_sha256"], row["trajectory_id"])
        push!(receipts, merge(Dict(pairs(result)), Dict("trajectory_id"=>row["trajectory_id"],
            "source"=>row["source"], "destination"=>row["destination"])))
    end
    open(args[2], "w") do io
        JSON.print(io, Dict("status"=>"passed", "integration_calls"=>0,
            "count"=>length(receipts), "files"=>receipts), 2)
    end
    println("DATASET2_PREFIX_PASSED count=", length(receipts), " integration_calls=0")
end

end

abspath(PROGRAM_FILE) == (@__FILE__) && Dataset2Prefix.main(ARGS)
