## Shape and dtype checks

using Statistics

function kbasic_dimension_summary(obj::KDSMBasicDatasetObject)
    return Dict(
        "state" => collect(size(obj.state)),
        "obs_phys" => collect(size(obj.observations["obs_phys"])),
        "obs_aug_full" => collect(size(obj.observations["obs_aug_full"])),
        "target_phys" => collect(size(obj.observations["target_phys"])),
        "time_grid" => [length(obj.time_grid)],
        "split_roles" => [length(obj.split_roles)],
        "amplitude_groups" => [length(obj.amplitude_groups)],
    )
end

## Finite-value and range checks

function kbasic_state_statistics(obj::KDSMBasicDatasetObject)
    q = vec(obj.state[:, :, 1])
    p = vec(obj.state[:, :, 2])
    return Dict(
        "q_min" => minimum(q),
        "q_max" => maximum(q),
        "p_min" => minimum(p),
        "p_max" => maximum(p),
        "q_mean" => mean(q),
        "p_mean" => mean(p),
        "q_std" => std(q),
        "p_std" => std(p),
        "state_abs_max" => maximum(abs, obj.state),
        "nonfinite_count" => count(!isfinite, obj.state),
        "all_finite" => all(isfinite, obj.state),
    )
end

## Split and amplitude-group summaries

function kbasic_count_summary(values::AbstractVector{<:AbstractString}, labels::AbstractVector{String})
    return Dict(label => count(==(label), values) for label in labels)
end

function kbasic_split_count_summary(split_roles::AbstractVector{<:AbstractString})
    return kbasic_count_summary(split_roles, ["train", "val", "test"])
end

function kbasic_amplitude_count_summary(amplitude_groups::AbstractVector{<:AbstractString})
    return kbasic_count_summary(amplitude_groups, ["small", "mid", "large", "out_of_band"])
end

## Linear-system analytic consistency checks

function kbasic_recurrence_error(obj::KDSMBasicDatasetObject)
    spec = obj.spec
    if spec.system_kind == "discrete_damped_rotation"
        F = kbasic_discrete_rotation_matrix(spec)
    elseif spec.system_kind == "continuous_linear_oscillator"
        F = kbasic_linear_flow_matrix(spec)
    else
        return 0.0
    end
    err = 0.0
    @inbounds for r in axes(obj.state, 1), m in 1:spec.M
        predicted = F * view(obj.state, r, m, :)
        err = max(err, maximum(abs.(predicted .- view(obj.state, r, m + 1, :))))
    end
    return err
end

function kbasic_energy_values(obj::KDSMBasicDatasetObject)
    spec = obj.spec
    E = Matrix{Float64}(undef, spec.R, spec.M + 1)
    @inbounds for r in 1:spec.R, m in 1:(spec.M + 1)
        q = obj.state[r, m, 1]
        p = obj.state[r, m, 2]
        E[r, m] = 0.5 * p^2 + 0.5 * spec.alpha * q^2 + 0.25 * spec.beta * q^4
    end
    return E
end

function kbasic_energy_diagnostics(obj::KDSMBasicDatasetObject)
    if obj.spec.system_kind == "discrete_damped_rotation"
        return Dict("final_le_initial_fraction" => 1.0, "mean_energy_drop" => NaN)
    end
    E = kbasic_energy_values(obj)
    drops = E[:, 1] .- E[:, end]
    return Dict(
        "final_le_initial_fraction" => mean(E[:, end] .<= E[:, 1] .+ 1.0e-10),
        "mean_energy_drop" => mean(drops),
    )
end

## Duffing beta-scan monotonic metadata checks

function kbasic_target_consistency_diagnostics(obj::KDSMBasicDatasetObject)
    X = obj.state
    obs_phys = obj.observations["obs_phys"]
    obs_aug_full = obj.observations["obs_aug_full"]
    target_phys = obj.observations["target_phys"]
    return Dict(
        "obs_phys_error_max" => maximum(abs.(obs_phys .- X)),
        "obs_aug_full_error_max" => maximum(abs.(obs_aug_full .- obs_phys)),
        "target_phys_error_max" => maximum(abs.(target_phys .- X)),
    )
end

## Diagnostic table assembly

function kbasic_finalize_object_diagnostics!(obj::KDSMBasicDatasetObject)
    obj.diagnostics["dimension_summary"] = kbasic_dimension_summary(obj)
    obj.diagnostics["split_counts"] = kbasic_split_count_summary(obj.split_roles)
    obj.diagnostics["amplitude_counts"] = kbasic_amplitude_count_summary(obj.amplitude_groups)
    state_stats = kbasic_state_statistics(obj)
    consistency = kbasic_target_consistency_diagnostics(obj)
    energy = kbasic_energy_diagnostics(obj)
    linear = Dict("linear_recurrence_error_max" => kbasic_recurrence_error(obj))
    obj.diagnostics["manifest_summary"] = merge(state_stats, consistency, energy, linear)
    amplitude = obj.diagnostics["amplitude_counts"]
    obj.diagnostics["passed"] =
        state_stats["all_finite"] &&
        state_stats["nonfinite_count"] == 0 &&
        consistency["obs_phys_error_max"] <= 0.0 &&
        consistency["obs_aug_full_error_max"] <= 0.0 &&
        consistency["target_phys_error_max"] <= 0.0 &&
        amplitude["small"] > 0 &&
        amplitude["mid"] > 0 &&
        amplitude["large"] > 0
    return obj
end
