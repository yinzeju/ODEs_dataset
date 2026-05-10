## Purpose and manifest boundary

using Dates
using SHA

function kdsm_file_sha256(path::AbstractString)
    isfile(path) || return "missing"
    return bytes2hex(open(sha256, path))
end

## Object manifest schema

function kdsm_object_manifest(
    obj::KDSMDuffingDatasetObject,
    raw_path::AbstractString,
    processed_path::AbstractString,
)
    spec = obj.spec
    diagnostics = obj.diagnostics
    return Dict{String,Any}(
        "release_id" => spec.release_id,
        "object_id" => spec.object_id,
        "created_at" => string(now()),
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
        "solver_metadata" => Dict(
            "solver_name" => "fixed_step_rk4_augmented",
            "saveat" => spec.tau,
            "step" => spec.tau,
        ),
        "random_seed" => spec.generation_seed,
        "split_seed" => spec.split_seed,
        "dimensions" => diagnostics["dimension_summary"],
        "split_counts" => diagnostics["split_counts"],
        "diagnostics" => diagnostics["manifest_summary"],
        "data_paths" => Dict(
            "raw_trajectories" => raw_path,
            "processed_tensors" => processed_path,
        ),
        "data_hashes" => Dict(
            "raw_sha256" => kdsm_file_sha256(raw_path),
            "processed_sha256" => kdsm_file_sha256(processed_path),
        ),
    )
end

## Release manifest schema

function kdsm_release_manifest(
    release_id::AbstractString,
    object_manifests::AbstractVector{<:AbstractDict},
    output_paths::AbstractDict,
    config_hashes::AbstractDict,
)
    return Dict{String,Any}(
        "release_id" => String(release_id),
        "release_version" => "1.0.0",
        "created_at" => string(now()),
        "family" => "v1_core",
        "object_count" => length(object_manifests),
        "object_ids" => [manifest["object_id"] for manifest in object_manifests],
        "forcing_ids" => unique([manifest["forcing_id"] for manifest in object_manifests]),
        "noise_levels" => unique([manifest["noise_level"] for manifest in object_manifests]),
        "split_protocol" => "split_trajectory_I",
        "storage_format" => "JLD2 tensors plus TOML manifests",
        "paths" => output_paths,
        "config_hashes" => config_hashes,
        "objects" => object_manifests,
    )
end

## Object path validation

function kdsm_validate_manifest_paths(manifest::AbstractDict)
    for (_, path) in manifest["data_paths"]
        isfile(path) || throw(ArgumentError("manifest path is missing: $(path)"))
    end
    return true
end
