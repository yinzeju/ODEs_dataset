## Purpose and storage boundary

using JLD2
using TOML

function kdsm_project_path(project_root::AbstractString, relative_path::AbstractString)
    return joinpath(project_root, split(relative_path, '/')...)
end

function kdsm_ensure_parent_dir(path::AbstractString)
    dir = dirname(path)
    isempty(dir) || mkpath(dir)
    return path
end

function kdsm_ensure_dir(path::AbstractString)
    mkpath(path)
    return path
end

function kdsm_load_toml(path::AbstractString)
    return TOML.parsefile(path)
end

function kdsm_write_toml(path::AbstractString, object::AbstractDict)
    kdsm_ensure_parent_dir(path)
    open(path, "w") do io
        TOML.print(io, object)
    end
    return path
end

## Raw data path rules

function kdsm_raw_path(project_root::AbstractString, spec::KDSMDuffingObjectSpec)
    return joinpath(project_root, "data", "raw", spec.release_id, spec.object_id, "raw_trajectories.jld2")
end

## Processed data path rules

function kdsm_processed_path(project_root::AbstractString, spec::KDSMDuffingObjectSpec)
    return joinpath(project_root, "data", "processed", spec.release_id, spec.object_id, "processed_tensors.jld2")
end

## Manifest path rules

function kdsm_manifest_path(project_root::AbstractString, spec::KDSMDuffingObjectSpec)
    return joinpath(project_root, "data", "manifests", spec.release_id, spec.object_id, "manifest.toml")
end

## Release index path rules

function kdsm_release_root(project_root::AbstractString, release_id::AbstractString)
    return joinpath(project_root, "data", "releases", release_id)
end

## Tensor save policy

function kdsm_save_raw_object(path::AbstractString, obj::KDSMDuffingDatasetObject)
    kdsm_ensure_parent_dir(path)
    JLD2.jldsave(
        path;
        release_id = obj.spec.release_id,
        object_id = obj.spec.object_id,
        trajectory_ids = obj.trajectory_ids,
        initial_conditions = obj.initial_conditions,
        trajectory_metadata = obj.trajectory_metadata,
        time_grid = obj.time_grid,
        state_aug = obj.state_aug,
        state_phys = obj.state_phys,
        forcing_state = obj.forcing_state,
        forcing_signal = obj.forcing_signal,
        array_layout = "channel_by_time_by_trajectory",
    )
    return path
end

function kdsm_save_processed_object(path::AbstractString, obj::KDSMDuffingDatasetObject)
    kdsm_ensure_parent_dir(path)
    JLD2.jldsave(
        path;
        release_id = obj.spec.release_id,
        object_id = obj.spec.object_id,
        trajectory_ids = obj.trajectory_ids,
        trajectory_metadata = obj.trajectory_metadata,
        state_aug = obj.state_aug,
        state_phys = obj.state_phys,
        forcing_state = obj.forcing_state,
        forcing_signal = obj.forcing_signal,
        time_grid = obj.time_grid,
        observation_aug = obj.clean_tensors["observation_aug"],
        observation_phys = obj.clean_tensors["observation_phys"],
        observation_aug_noisy = obj.noisy_tensors["observation_aug_noisy"],
        observation_phys_noisy = obj.noisy_tensors["observation_phys_noisy"],
        target_phys = obj.clean_tensors["target_phys"],
        target_aug = obj.clean_tensors["target_aug"],
        target_poly9 = obj.clean_tensors["target_poly9"],
        target_energy5 = obj.clean_tensors["target_energy5"],
        target_phys_noisy = obj.noisy_tensors["target_phys_noisy"],
        target_aug_noisy = obj.noisy_tensors["target_aug_noisy"],
        target_poly9_noisy = obj.noisy_tensors["target_poly9_noisy"],
        target_energy5_noisy = obj.noisy_tensors["target_energy5_noisy"],
        split_roles = obj.split_roles,
        metadata = kdsm_object_metadata(obj),
        noise_scale_metadata = obj.noise_scale_metadata,
        diagnostics = obj.diagnostics,
        array_layout = "channel_by_time_by_trajectory",
    )
    return path
end

## Tensor load policy

kdsm_load_jld2(path::AbstractString) = JLD2.load(path)

## Overwrite and append-only checks

function kdsm_write_csv(path::AbstractString, columns::AbstractVector{<:AbstractString}, rows::AbstractVector)
    kdsm_ensure_parent_dir(path)
    open(path, "w") do io
        println(io, join(columns, ","))
        for row in rows
            println(io, join(kdsm_csv_value.(row), ","))
        end
    end
    return path
end

function kdsm_csv_value(value)
    if value isa AbstractString
        return string('"', replace(value, "\"" => "\"\""), '"')
    elseif value isa Bool
        return value ? "true" : "false"
    else
        return string(value)
    end
end
