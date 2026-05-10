## Resolve dataset output paths

using JLD2
using TOML

function kbasic_ensure_parent_dir(path::AbstractString)
    dir = dirname(path)
    isempty(dir) || mkpath(dir)
    return path
end

function kbasic_load_toml(path::AbstractString)
    return TOML.parsefile(path)
end

function kbasic_write_toml(path::AbstractString, object::AbstractDict)
    kbasic_ensure_parent_dir(path)
    open(path, "w") do io
        TOML.print(io, object)
    end
    return path
end

function kbasic_raw_path(project_root::AbstractString, spec::KDSMBasicObjectSpec)
    return joinpath(project_root, "data", "raw", spec.release_id, spec.object_id, "raw_trajectories.jld2")
end

function kbasic_processed_path(project_root::AbstractString, spec::KDSMBasicObjectSpec)
    return joinpath(project_root, "data", "processed", spec.release_id, spec.object_id, "processed_tensors.jld2")
end

function kbasic_manifest_path(project_root::AbstractString, spec::KDSMBasicObjectSpec)
    filename = string(spec.object_id, "_manifest.toml")
    return joinpath(project_root, "data", "manifests", spec.release_id, filename)
end

function kbasic_release_root(project_root::AbstractString, release_id::AbstractString)
    return joinpath(project_root, "data", "releases", release_id)
end

## Save raw trajectory files

function kbasic_save_raw_object(path::AbstractString, obj::KDSMBasicDatasetObject)
    kbasic_ensure_parent_dir(path)
    JLD2.jldsave(
        path;
        release_id = obj.spec.release_id,
        object_id = obj.spec.object_id,
        trajectory_ids = obj.trajectory_ids,
        initial_conditions = obj.initial_conditions,
        amplitude_groups = obj.amplitude_groups,
        trajectory_metadata = obj.trajectory_metadata,
        time_grid = obj.time_grid,
        state = obj.state,
        metadata = kbasic_object_metadata(obj),
        array_layout = "trajectory_by_time_by_channel",
    )
    return path
end

## Save processed tensor files

function kbasic_save_processed_object(path::AbstractString, obj::KDSMBasicDatasetObject)
    kbasic_ensure_parent_dir(path)
    JLD2.jldsave(
        path;
        release_id = obj.spec.release_id,
        object_id = obj.spec.object_id,
        trajectory_ids = obj.trajectory_ids,
        trajectory_metadata = obj.trajectory_metadata,
        time_grid = obj.time_grid,
        state = obj.state,
        obs_phys = obj.observations["obs_phys"],
        obs_aug_full = obj.observations["obs_aug_full"],
        target_phys = obj.observations["target_phys"],
        split_roles = obj.split_roles,
        amplitude_groups = obj.amplitude_groups,
        window_metadata = obj.window_metadata,
        metadata = kbasic_object_metadata(obj),
        diagnostics = obj.diagnostics,
        array_layout = "trajectory_by_time_by_channel",
    )
    return path
end

## Save manifest and release files

function kbasic_write_csv(path::AbstractString, columns::AbstractVector{<:AbstractString}, rows::AbstractVector)
    kbasic_ensure_parent_dir(path)
    open(path, "w") do io
        println(io, join(columns, ","))
        for row in rows
            println(io, join(kbasic_csv_value.(row), ","))
        end
    end
    return path
end

function kbasic_csv_value(value)
    if value isa AbstractString
        return string('"', replace(value, "\"" => "\"\""), '"')
    elseif value isa Bool
        return value ? "true" : "false"
    else
        return string(value)
    end
end

## Reload and verify saved objects

function kbasic_load_jld2(path::AbstractString)
    return JLD2.load(path)
end

function kbasic_reload_verify(raw_path::AbstractString, processed_path::AbstractString)
    raw = kbasic_load_jld2(raw_path)
    processed = kbasic_load_jld2(processed_path)
    raw["object_id"] == processed["object_id"] ||
        throw(ArgumentError("raw/processed object_id mismatch"))
    size(raw["state"]) == size(processed["state"]) ||
        throw(ArgumentError("raw/processed state shape mismatch"))
    maximum(abs.(raw["state"] .- processed["state"])) <= 0.0 ||
        throw(ArgumentError("raw/processed state tensors differ"))
    maximum(abs.(processed["obs_phys"] .- processed["state"])) <= 0.0 ||
        throw(ArgumentError("processed obs_phys does not equal state"))
    maximum(abs.(processed["obs_aug_full"] .- processed["obs_phys"])) <= 0.0 ||
        throw(ArgumentError("obs_aug_full does not equal obs_phys"))
    maximum(abs.(processed["target_phys"] .- processed["state"])) <= 0.0 ||
        throw(ArgumentError("target_phys does not equal state"))
    return true
end
