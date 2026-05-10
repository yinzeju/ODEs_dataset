## Purpose and dataset-object boundary

struct KDSMDuffingDatasetObject
    spec::KDSMDuffingObjectSpec
    trajectory_ids::Vector{String}
    initial_conditions::Matrix{Float64}
    trajectory_metadata::Vector{Dict{String,Any}}
    time_grid::Vector{Float64}
    state_aug::Array{Float64,3}
    state_phys::Array{Float64,3}
    forcing_state::Array{Float64,3}
    forcing_signal::Array{Float64,3}
    split_roles::Vector{String}
    clean_tensors::Dict{String,Any}
    noisy_tensors::Dict{String,Any}
    noise_scale_metadata::Dict{String,Any}
    diagnostics::Dict{String,Any}
end

## Metadata attachment

function kdsm_object_metadata(obj::KDSMDuffingDatasetObject)
    spec = obj.spec
    return Dict(
        "release_id" => spec.release_id,
        "object_id" => spec.object_id,
        "regime_id" => spec.regime_id,
        "forcing_id" => spec.forcing.forcing_id,
        "obs_modes" => ["obs_aug_full", "obs_phys_only"],
        "target_modes" => ["target_phys", "target_aug", "target_poly9", "target_energy5"],
        "default_observation" => spec.default_observation,
        "default_target" => spec.default_target,
        "recommended_downstream_input" => spec.recommended_downstream_input,
        "duffing_params" => kdsm_duffing_parameter_metadata(spec),
        "forcing_params" => spec.forcing.params,
        "tau" => spec.tau,
        "M" => spec.M,
        "R" => spec.R,
        "noise_level" => spec.noise_level_id,
        "noise_sigma" => spec.noise_sigma,
        "split_protocol" => "split_trajectory_I",
        "intended_diagnostics" => spec.intended_diagnostics,
    )
end

## Object-level consistency checks

function kdsm_validate_dataset_object(obj::KDSMDuffingDatasetObject)
    spec = obj.spec
    d_x = kdsm_state_dim(spec)
    d_u = kdsm_forcing_state_dim(spec.forcing)
    size(obj.state_aug) == (d_x, spec.M + 1, spec.R) ||
        throw(ArgumentError("state_aug has wrong shape for $(spec.object_id)"))
    size(obj.state_phys) == (2, spec.M + 1, spec.R) ||
        throw(ArgumentError("state_phys has wrong shape for $(spec.object_id)"))
    size(obj.forcing_state) == (d_u, spec.M + 1, spec.R) ||
        throw(ArgumentError("forcing_state has wrong shape for $(spec.object_id)"))
    size(obj.forcing_signal) == (1, spec.M + 1, spec.R) ||
        throw(ArgumentError("forcing_signal has wrong shape for $(spec.object_id)"))
    length(obj.time_grid) == spec.M + 1 ||
        throw(ArgumentError("time_grid length mismatch for $(spec.object_id)"))
    length(obj.split_roles) == spec.R ||
        throw(ArgumentError("split_roles length mismatch for $(spec.object_id)"))
    all(isfinite, obj.state_aug) || throw(ArgumentError("state_aug contains non-finite values"))
    all(isfinite, obj.forcing_signal) || throw(ArgumentError("forcing_signal contains non-finite values"))
    return true
end
