## Dataset object boundary

struct KDSMBasicDatasetObject
    spec::KDSMBasicObjectSpec
    trajectory_ids::Vector{String}
    initial_conditions::Matrix{Float64}
    amplitude_groups::Vector{String}
    trajectory_metadata::Vector{Dict{String,Any}}
    time_grid::Vector{Float64}
    state::Array{Float64,3}
    observations::Dict{String,Any}
    split_roles::Vector{String}
    window_metadata::Dict{String,Any}
    system_metadata::Dict{String,Any}
    diagnostics::Dict{String,Any}
end

function kbasic_object_metadata(obj::KDSMBasicDatasetObject)
    spec = obj.spec
    return Dict(
        "release_id" => spec.release_id,
        "object_id" => spec.object_id,
        "regime_id" => spec.regime_id,
        "system_family" => spec.system_kind,
        "forcing_type" => "force_none",
        "state_dimension" => 2,
        "observation_keys" => ["obs_phys", "obs_aug_full"],
        "target_keys" => ["target_phys"],
        "default_observation" => spec.default_observation,
        "default_target" => spec.default_target,
        "recommended_downstream_input" => spec.recommended_downstream_input,
        "parameters" => kbasic_parameter_metadata(spec),
        "tau" => spec.tau,
        "M" => spec.M,
        "R" => spec.R,
        "split_name" => "kdsm_basic_split_trajectory_I",
        "solver_name" => spec.solver_name,
        "solver_tolerances" => Dict("method" => spec.solver_name, "fixed_step" => spec.tau),
        "noise_level" => 0.0,
        "initial_condition_seed" => spec.generation_seed,
        "initial_condition_policy" => spec.ic_policy,
        "array_layout" => "trajectory_by_time_by_channel",
        "system_metadata" => obj.system_metadata,
        "window_metadata" => obj.window_metadata,
        "intended_diagnostics" => spec.intended_diagnostics,
    )
end

function kbasic_validate_dataset_object(obj::KDSMBasicDatasetObject)
    spec = obj.spec
    size(obj.state) == (spec.R, spec.M + 1, 2) ||
        throw(ArgumentError("state tensor has wrong shape for $(spec.object_id)"))
    size(obj.observations["obs_phys"]) == size(obj.state) ||
        throw(ArgumentError("obs_phys has wrong shape for $(spec.object_id)"))
    size(obj.observations["obs_aug_full"]) == size(obj.state) ||
        throw(ArgumentError("obs_aug_full has wrong shape for $(spec.object_id)"))
    size(obj.observations["target_phys"]) == size(obj.state) ||
        throw(ArgumentError("target_phys has wrong shape for $(spec.object_id)"))
    length(obj.time_grid) == spec.M + 1 ||
        throw(ArgumentError("time_grid length mismatch for $(spec.object_id)"))
    length(obj.split_roles) == spec.R ||
        throw(ArgumentError("split_roles length mismatch for $(spec.object_id)"))
    length(obj.amplitude_groups) == spec.R ||
        throw(ArgumentError("amplitude group length mismatch for $(spec.object_id)"))
    all(isfinite, obj.state) || throw(ArgumentError("state contains non-finite values"))
    return true
end
