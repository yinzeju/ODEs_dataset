## Define identity physical observation

function kbasic_obs_phys(X::AbstractArray{<:Real,3})
    return Array{Float64}(X)
end

## Define no-forcing augmented observation alias

function kbasic_obs_aug_full(X::AbstractArray{<:Real,3})
    return Array{Float64}(X)
end

## Define physical target tensor

function kbasic_target_phys(X::AbstractArray{<:Real,3})
    return Array{Float64}(X)
end

## Validate observation-target dimensions

function kbasic_build_observations_and_targets(X::AbstractArray{<:Real,3})
    tensors = Dict{String,Any}(
        "obs_phys" => kbasic_obs_phys(X),
        "obs_aug_full" => kbasic_obs_aug_full(X),
        "target_phys" => kbasic_target_phys(X),
    )
    kbasic_validate_observation_target_tensors(tensors, X)
    return tensors
end

## Validate identity relations for no-forcing objects

function kbasic_validate_observation_target_tensors(tensors::AbstractDict, X::AbstractArray{<:Real,3})
    size(X, 3) == 2 || throw(ArgumentError("state tensor must have channel dimension 2"))
    size(tensors["obs_phys"]) == size(X) || throw(ArgumentError("obs_phys shape mismatch"))
    size(tensors["obs_aug_full"]) == size(X) || throw(ArgumentError("obs_aug_full shape mismatch"))
    size(tensors["target_phys"]) == size(X) || throw(ArgumentError("target_phys shape mismatch"))
    maximum(abs.(tensors["obs_phys"] .- X)) <= 0.0 ||
        throw(ArgumentError("obs_phys must equal state"))
    maximum(abs.(tensors["obs_aug_full"] .- X)) <= 0.0 ||
        throw(ArgumentError("obs_aug_full must equal state"))
    maximum(abs.(tensors["target_phys"] .- X)) <= 0.0 ||
        throw(ArgumentError("target_phys must equal state"))
    return true
end
