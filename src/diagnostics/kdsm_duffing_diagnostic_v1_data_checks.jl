## Purpose and data diagnostics boundary

using Statistics

## Tensor shape diagnostics

function kdsm_dimension_summary(obj::KDSMDuffingDatasetObject)
    return Dict(
        "state_aug" => collect(size(obj.state_aug)),
        "state_phys" => collect(size(obj.state_phys)),
        "forcing_state" => collect(size(obj.forcing_state)),
        "forcing_signal" => collect(size(obj.forcing_signal)),
        "time_grid" => [length(obj.time_grid)],
        "observation_aug" => collect(size(obj.clean_tensors["observation_aug"])),
        "observation_phys" => collect(size(obj.clean_tensors["observation_phys"])),
        "target_phys" => collect(size(obj.clean_tensors["target_phys"])),
        "target_aug" => collect(size(obj.clean_tensors["target_aug"])),
        "target_poly9" => collect(size(obj.clean_tensors["target_poly9"])),
        "target_energy5" => collect(size(obj.clean_tensors["target_energy5"])),
        "split_roles" => [length(obj.split_roles)],
    )
end

## Finite-value diagnostics

function kdsm_state_range_summary(obj::KDSMDuffingDatasetObject)
    return Dict(
        "state_abs_max" => maximum(abs, obj.state_aug),
        "q_min" => minimum(obj.state_phys[1, :, :]),
        "q_max" => maximum(obj.state_phys[1, :, :]),
        "p_min" => minimum(obj.state_phys[2, :, :]),
        "p_max" => maximum(obj.state_phys[2, :, :]),
        "all_finite" => all(isfinite, obj.state_aug) && all(isfinite, obj.forcing_signal),
    )
end

## Harmonic forcing radius diagnostics

function kdsm_harmonic_radius_diagnostics(obj::KDSMDuffingDatasetObject)
    spec = obj.spec
    if spec.forcing.forcing_id == "force_harmonic_1"
        U = obj.forcing_state
        err = maximum(abs.(U[1, :, :].^2 .+ U[2, :, :].^2 .- 1.0))
        return Dict("harmonic_radius_error_max" => err)
    elseif spec.forcing.forcing_id == "force_harmonic_2"
        U = obj.forcing_state
        err1 = maximum(abs.(U[1, :, :].^2 .+ U[2, :, :].^2 .- 1.0))
        err2 = maximum(abs.(U[3, :, :].^2 .+ U[4, :, :].^2 .- 1.0))
        return Dict("harmonic_radius_error_1_max" => err1, "harmonic_radius_error_2_max" => err2)
    end
    return Dict("harmonic_radius_error_max" => 0.0)
end

## Energy target sanity diagnostics

function kdsm_target_consistency_diagnostics(obj::KDSMDuffingDatasetObject)
    state_phys = obj.state_phys
    state_aug = obj.state_aug
    poly9 = obj.clean_tensors["target_poly9"]
    energy5 = obj.clean_tensors["target_energy5"]
    return Dict(
        "observation_aug_error_max" => maximum(abs.(obj.clean_tensors["observation_aug"] .- state_aug)),
        "observation_phys_error_max" => maximum(abs.(obj.clean_tensors["observation_phys"] .- state_phys)),
        "target_phys_error_max" => maximum(abs.(obj.clean_tensors["target_phys"] .- state_phys)),
        "target_aug_error_max" => maximum(abs.(obj.clean_tensors["target_aug"] .- state_aug)),
        "target_poly9_first_two_error_max" => maximum(abs.(poly9[1:2, :, :] .- state_phys)),
        "target_energy5_first_two_error_max" => maximum(abs.(energy5[1:2, :, :] .- state_phys)),
    )
end

## Noise RMS diagnostics

function kdsm_noise_diagnostics(obj::KDSMDuffingDatasetObject)
    summary = Dict{String,Any}()
    for (noisy_name, clean_name) in KDSM_NOISY_TENSOR_SOURCES
        diff = obj.noisy_tensors[noisy_name] .- obj.clean_tensors[clean_name]
        summary[noisy_name] = Dict(
            "source_tensor" => clean_name,
            "rms" => sqrt(mean(abs2, diff)),
            "abs_max" => maximum(abs, diff),
        )
    end
    return summary
end

## Split count diagnostics

function kdsm_split_count_summary(split_roles::AbstractVector{<:AbstractString})
    return Dict(
        "train" => count(==("train"), split_roles),
        "val" => count(==("val"), split_roles),
        "test" => count(==("test"), split_roles),
    )
end

## Metadata completeness diagnostics

function kdsm_manifest_summary(obj::KDSMDuffingDatasetObject)
    state = kdsm_state_range_summary(obj)
    target = kdsm_target_consistency_diagnostics(obj)
    harmonic = kdsm_harmonic_radius_diagnostics(obj)
    return merge(state, target, harmonic)
end

## Release summary diagnostics

function kdsm_finalize_object_diagnostics!(obj::KDSMDuffingDatasetObject)
    obj.diagnostics["dimension_summary"] = kdsm_dimension_summary(obj)
    obj.diagnostics["split_counts"] = kdsm_split_count_summary(obj.split_roles)
    obj.diagnostics["manifest_summary"] = kdsm_manifest_summary(obj)
    obj.diagnostics["noise_diagnostics"] = kdsm_noise_diagnostics(obj)
    obj.diagnostics["passed"] = obj.diagnostics["manifest_summary"]["all_finite"] &&
        obj.diagnostics["manifest_summary"]["observation_aug_error_max"] <= 0.0 &&
        obj.diagnostics["manifest_summary"]["observation_phys_error_max"] <= 0.0 &&
        obj.diagnostics["manifest_summary"]["target_phys_error_max"] <= 0.0 &&
        obj.diagnostics["manifest_summary"]["target_aug_error_max"] <= 0.0
    return obj
end
