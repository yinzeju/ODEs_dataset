## Purpose and noise protocol

using Random
using Statistics

## Select clean source tensors

const KDSM_NOISY_TENSOR_SOURCES = Dict(
    "observation_aug_noisy" => "observation_aug",
    "observation_phys_noisy" => "observation_phys",
    "target_phys_noisy" => "target_phys",
    "target_aug_noisy" => "target_aug",
    "target_poly9_noisy" => "target_poly9",
    "target_energy5_noisy" => "target_energy5",
)

## Estimate channel scales from train trajectories

function kdsm_channel_scales(
    tensor::AbstractArray{<:Real,3},
    train_indices::AbstractVector{<:Integer},
)
    scales = Vector{Float64}(undef, size(tensor, 1))
    @inbounds for i in axes(tensor, 1)
        values = Float64[]
        sizehint!(values, size(tensor, 2) * length(train_indices))
        for r in train_indices, m in axes(tensor, 2)
            push!(values, Float64(tensor[i, m, r]))
        end
        s = std(values)
        scales[i] = isfinite(s) && s > 0.0 ? s : 1.0
    end
    return scales
end

## Generate seeded Gaussian perturbations

function kdsm_noisy_tensor(
    clean::AbstractArray{<:Real,3},
    scales::AbstractVector{<:Real},
    sigma::Real,
    rng::AbstractRNG,
)
    noisy = Array{Float64}(clean)
    sigma == 0 && return noisy, zeros(Float64, size(clean))
    noise = randn(rng, size(clean))
    @inbounds for i in axes(noise, 1)
        noise[i, :, :] .*= Float64(sigma) * Float64(scales[i])
    end
    noisy .+= noise
    return noisy, noise
end

## Build noisy observation tensors

function kdsm_apply_noise_protocol(
    clean_tensors::AbstractDict{String,<:Any},
    split_roles::AbstractVector{<:AbstractString},
    spec::KDSMDuffingObjectSpec,
)
    train_indices = findall(==("train"), split_roles)
    isempty(train_indices) && throw(ArgumentError("noise scale estimation requires train trajectories"))
    rng = MersenneTwister(spec.generation_seed + kdsm_stable_string_seed(spec.object_id) + 4099)
    noisy_tensors = Dict{String,Any}()
    scale_metadata = Dict{String,Any}()
    noise_summary = Dict{String,Any}()

    for (noisy_name, clean_name) in KDSM_NOISY_TENSOR_SOURCES
        clean = clean_tensors[clean_name]
        scales = kdsm_channel_scales(clean, train_indices)
        noisy, noise = kdsm_noisy_tensor(clean, scales, spec.noise_sigma, rng)
        noisy_tensors[noisy_name] = noisy
        scale_metadata[clean_name] = scales
        noise_summary[noisy_name] = Dict(
            "source_tensor" => clean_name,
            "sigma" => spec.noise_sigma,
            "channel_scale_min" => minimum(scales),
            "channel_scale_max" => maximum(scales),
            "noise_rms" => sqrt(mean(abs2, noise)),
            "relative_noise_rms_mean" => spec.noise_sigma,
        )
    end

    ## Clean source tensors are never mutated; noisy versions are additive fields.
    return noisy_tensors, scale_metadata, noise_summary
end

## Noise reproducibility checks

function kdsm_validate_noise_protocol(
    clean_tensors::AbstractDict,
    noisy_tensors::AbstractDict,
    spec::KDSMDuffingObjectSpec,
)
    for (noisy_name, clean_name) in KDSM_NOISY_TENSOR_SOURCES
        size(noisy_tensors[noisy_name]) == size(clean_tensors[clean_name]) ||
            throw(ArgumentError("$(noisy_name) shape does not match $(clean_name)"))
        all(isfinite, noisy_tensors[noisy_name]) ||
            throw(ArgumentError("$(noisy_name) contains non-finite values"))
        if spec.noise_sigma == 0.0
            maximum(abs.(noisy_tensors[noisy_name] .- clean_tensors[clean_name])) <= 0.0 ||
                throw(ArgumentError("clean noisy tensor $(noisy_name) must equal source"))
        end
    end
    return true
end
