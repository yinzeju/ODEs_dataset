## Purpose and observation-chain boundary

## Build observation_aug

kdsm_observation_aug(state_aug::AbstractArray{<:Real,3}) = Array{Float64}(state_aug)

## Build observation_phys

kdsm_observation_phys(state_phys::AbstractArray{<:Real,3}) = Array{Float64}(state_phys)

## Build target_phys

kdsm_target_phys(state_phys::AbstractArray{<:Real,3}) = Array{Float64}(state_phys)

## Build target_aug

kdsm_target_aug(state_aug::AbstractArray{<:Real,3}) = Array{Float64}(state_aug)

## Build target_poly9

function kdsm_target_poly9(state_phys::AbstractArray{<:Real,3})
    size(state_phys, 1) == 2 || throw(ArgumentError("state_phys must have first dimension 2"))
    Y = Array{Float64}(undef, 9, size(state_phys, 2), size(state_phys, 3))
    @inbounds for r in axes(state_phys, 3), m in axes(state_phys, 2)
        q = Float64(state_phys[1, m, r])
        p = Float64(state_phys[2, m, r])
        Y[1, m, r] = q
        Y[2, m, r] = p
        Y[3, m, r] = q^2
        Y[4, m, r] = q * p
        Y[5, m, r] = p^2
        Y[6, m, r] = q^3
        Y[7, m, r] = q^2 * p
        Y[8, m, r] = q * p^2
        Y[9, m, r] = p^3
    end
    return Y
end

## Build target_energy5

function kdsm_target_energy5(state_phys::AbstractArray{<:Real,3}, spec::KDSMDuffingObjectSpec)
    size(state_phys, 1) == 2 || throw(ArgumentError("state_phys must have first dimension 2"))
    Y = Array{Float64}(undef, 5, size(state_phys, 2), size(state_phys, 3))
    @inbounds for r in axes(state_phys, 3), m in axes(state_phys, 2)
        q = Float64(state_phys[1, m, r])
        p = Float64(state_phys[2, m, r])
        kinetic = 0.5 * p^2
        potential = 0.5 * spec.alpha * q^2 + 0.25 * spec.beta * q^4
        Y[1, m, r] = q
        Y[2, m, r] = p
        Y[3, m, r] = kinetic
        Y[4, m, r] = potential
        Y[5, m, r] = kinetic + potential
    end
    return Y
end

## Target and observation dimension checks

function kdsm_build_clean_observations_and_targets(
    state_aug::AbstractArray{<:Real,3},
    state_phys::AbstractArray{<:Real,3},
    spec::KDSMDuffingObjectSpec,
)
    tensors = Dict{String,Any}(
        "observation_aug" => kdsm_observation_aug(state_aug),
        "observation_phys" => kdsm_observation_phys(state_phys),
        "target_phys" => kdsm_target_phys(state_phys),
        "target_aug" => kdsm_target_aug(state_aug),
        "target_poly9" => kdsm_target_poly9(state_phys),
        "target_energy5" => kdsm_target_energy5(state_phys, spec),
    )
    kdsm_validate_observation_target_tensors(tensors, state_aug, state_phys)
    return tensors
end

function kdsm_validate_observation_target_tensors(
    tensors::AbstractDict,
    state_aug::AbstractArray{<:Real,3},
    state_phys::AbstractArray{<:Real,3},
)
    size(tensors["observation_aug"]) == size(state_aug) ||
        throw(ArgumentError("observation_aug shape mismatch"))
    size(tensors["observation_phys"]) == size(state_phys) ||
        throw(ArgumentError("observation_phys shape mismatch"))
    size(tensors["target_phys"]) == size(state_phys) ||
        throw(ArgumentError("target_phys shape mismatch"))
    size(tensors["target_aug"]) == size(state_aug) ||
        throw(ArgumentError("target_aug shape mismatch"))
    size(tensors["target_poly9"], 1) == 9 ||
        throw(ArgumentError("target_poly9 must have first dimension 9"))
    size(tensors["target_energy5"], 1) == 5 ||
        throw(ArgumentError("target_energy5 must have first dimension 5"))
    maximum(abs.(tensors["observation_aug"] .- state_aug)) <= 0.0 ||
        throw(ArgumentError("clean observation_aug must equal state_aug"))
    maximum(abs.(tensors["observation_phys"] .- state_phys)) <= 0.0 ||
        throw(ArgumentError("clean observation_phys must equal state_phys"))
    maximum(abs.(tensors["target_phys"] .- state_phys)) <= 0.0 ||
        throw(ArgumentError("target_phys must equal state_phys"))
    maximum(abs.(tensors["target_aug"] .- state_aug)) <= 0.0 ||
        throw(ArgumentError("target_aug must equal state_aug"))
    return true
end
