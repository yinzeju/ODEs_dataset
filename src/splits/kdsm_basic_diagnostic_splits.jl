## Define trajectory-level split protocol

using Random

function kbasic_split_counts(split_config::AbstractDict, difficulty::AbstractString)
    key = difficulty == "smoke" ? "smoke_counts" : "default_counts"
    counts = split_config[key]
    return Dict(
        "train" => Int(counts["train"]),
        "val" => Int(counts["val"]),
        "test" => Int(counts["test"]),
    )
end

## Generate deterministic train-val-test roles

function kbasic_build_trajectory_split_roles(
    R::Integer,
    split_config::AbstractDict;
    difficulty::AbstractString = "default",
)
    counts = kbasic_split_counts(split_config, difficulty)
    counts["train"] + counts["val"] + counts["test"] == R ||
        throw(ArgumentError("split counts must sum to R"))
    rng = MersenneTwister(Int(split_config["seed"]))
    order = collect(1:Int(R))
    shuffle!(rng, order)
    roles = fill("unassigned", Int(R))
    train_stop = counts["train"]
    val_stop = train_stop + counts["val"]
    roles[order[1:train_stop]] .= "train"
    roles[order[(train_stop + 1):val_stop]] .= "val"
    roles[order[(val_stop + 1):end]] .= "test"
    kbasic_validate_split_roles(roles, counts)
    return roles, counts
end

## Validate split counts

function kbasic_validate_split_roles(roles::AbstractVector{<:AbstractString}, counts::AbstractDict)
    all(role -> role in ("train", "val", "test"), roles) ||
        throw(ArgumentError("split_roles contains an invalid role"))
    for role in ("train", "val", "test")
        count(==(role), roles) == counts[role] ||
            throw(ArgumentError("split role count mismatch for $(role)"))
    end
    return true
end

## Prevent window-level leakage

function kbasic_split_indices(roles::AbstractVector{<:AbstractString})
    return Dict(role => findall(==(role), roles) for role in ("train", "val", "test"))
end
