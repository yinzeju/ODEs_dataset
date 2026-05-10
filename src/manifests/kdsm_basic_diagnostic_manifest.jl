## Object-level manifest fields

using Dates
using SHA

function kbasic_file_sha256(path::AbstractString)
    isfile(path) || return "missing"
    return bytes2hex(open(sha256, path))
end

function kbasic_object_manifest(
    obj::KDSMBasicDatasetObject,
    raw_path::AbstractString,
    processed_path::AbstractString,
)
    spec = obj.spec
    return Dict{String,Any}(
        "release_id" => spec.release_id,
        "object_id" => spec.object_id,
        "created_at" => string(now()),
        "regime_id" => spec.regime_id,
        "system_family" => spec.system_kind,
        "forcing_type" => "force_none",
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
        "split_roles" => obj.split_roles,
        "amplitude_groups" => obj.amplitude_groups,
        "initial_condition_seed" => spec.generation_seed,
        "solver_name" => spec.solver_name,
        "solver_tolerances" => Dict("method" => spec.solver_name, "fixed_step" => spec.tau),
        "noise_level" => 0.0,
        "true_system_metadata" => obj.system_metadata,
        "window_metadata" => obj.window_metadata,
        "dimensions" => obj.diagnostics["dimension_summary"],
        "split_counts" => obj.diagnostics["split_counts"],
        "amplitude_counts" => obj.diagnostics["amplitude_counts"],
        "diagnostics" => obj.diagnostics["manifest_summary"],
        "data_paths" => Dict(
            "raw_trajectories" => raw_path,
            "processed_tensors" => processed_path,
        ),
        "data_hashes" => Dict(
            "raw_sha256" => kbasic_file_sha256(raw_path),
            "processed_sha256" => kbasic_file_sha256(processed_path),
        ),
    )
end

## Release-level manifest fields

function kbasic_release_manifest(
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
        "duffing_beta_ladder" => [
            manifest["parameters"]["beta"]
            for manifest in object_manifests
            if manifest["system_family"] == "weak_duffing"
        ],
        "forcing_type" => "force_none",
        "split_protocol" => "kdsm_basic_split_trajectory_I",
        "storage_format" => "JLD2 tensors plus TOML manifests",
        "paths" => output_paths,
        "config_hashes" => config_hashes,
        "objects" => object_manifests,
    )
end

## Config hash and data checksum fields

function kbasic_write_checksums(path::AbstractString, path_groups::AbstractDict)
    checksums = Dict{String,Any}()
    for (group, paths) in path_groups
        if paths isa AbstractDict
            checksums[String(group)] = Dict(String(k) => kbasic_file_sha256(v) for (k, v) in paths)
        else
            checksums[String(group)] = kbasic_file_sha256(paths)
        end
    end
    kbasic_write_toml(path, checksums)
    return checksums
end

## Manifest validation checks

function kbasic_validate_manifest_paths(manifest::AbstractDict)
    for (_, path) in manifest["data_paths"]
        isfile(path) || throw(ArgumentError("manifest path is missing: $(path)"))
    end
    return true
end
