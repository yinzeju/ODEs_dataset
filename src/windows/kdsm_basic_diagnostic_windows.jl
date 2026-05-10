## Define one-step window metadata

function kbasic_one_step_counts(M::Integer, split_counts::AbstractDict)
    return Dict(role => Int(count) * Int(M) for (role, count) in split_counts)
end

## Define decoded rollout horizon metadata

function kbasic_rollout_counts(M::Integer, horizons::AbstractVector, split_counts::AbstractDict)
    counts = Dict{String,Any}()
    for h in Int.(horizons)
        kbasic_validate_horizon(M, h)
        counts[string(h)] = Dict(role => Int(count) * (Int(M) - h + 1) for (role, count) in split_counts)
    end
    return counts
end

## Validate horizon start indices

function kbasic_validate_horizon(M::Integer, horizon::Integer)
    1 <= horizon <= M || throw(ArgumentError("invalid rollout horizon $(horizon) for M=$(M)"))
    return true
end

## Attach split-local window counts

function kbasic_window_metadata(M::Integer, split_roles::AbstractVector{<:AbstractString}, window_config::AbstractDict)
    split_counts = Dict(role => count(==(role), split_roles) for role in ("train", "val", "test"))
    horizons = Int.(window_config["rollout"]["horizons"])
    return Dict{String,Any}(
        "one_step" => Dict(
            "lag" => Int(window_config["one_step"]["lag"]),
            "counts" => kbasic_one_step_counts(M, split_counts),
        ),
        "rollout" => Dict(
            "horizons" => horizons,
            "counts" => kbasic_rollout_counts(M, horizons, split_counts),
            "valid_start_rule" => "0 <= s and s + h <= M",
        ),
        "split_convention" => String(window_config["split_convention"]),
    )
end
