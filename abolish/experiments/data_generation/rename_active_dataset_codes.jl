using HDF5
using JLD2

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const LOWDIM_OLD_CODE = "standard_odes_v1"
const LOWDIM_NEW_CODE = "lowdim_nonlinear_v1"
const HIGHDIM_OLD_CODE = "high_dimensional_nonlinear_dynamics_v2"
const HIGHDIM_NEW_CODE = "highdim_nonlinear_v2"

function replace_code!(path::AbstractString, old_code::AbstractString, new_code::AbstractString)
    content = read(path, String)
    updated = replace(content, old_code => new_code)
    updated == content || write(path, updated)
    return nothing
end

function update_lowdim_jld2!(path::AbstractString)
    jldopen(path, "a+") do file
        dataset_id = file["dataset_id"]
        dataset_id in (LOWDIM_OLD_CODE, LOWDIM_NEW_CODE) ||
            error("unexpected dataset_id in $path: $dataset_id")
        delete!(file, "dataset_id")
        file["dataset_id"] = LOWDIM_NEW_CODE
    end
    return nothing
end

function update_highdim_hdf5!(path::AbstractString)
    h5open(path, "r+") do file
        metadata = file["meta"]
        if haskey(metadata, "task_code")
            task_code = read(metadata["task_code"])
            task_code in (HIGHDIM_OLD_CODE, HIGHDIM_NEW_CODE) ||
                error("unexpected task_code in $path: $task_code")
            delete_object(metadata, "task_code")
        end
        metadata["task_code"] = HIGHDIM_NEW_CODE
    end
    return nothing
end

function update_text_files!(root::AbstractString, old_code::AbstractString, new_code::AbstractString)
    isdir(root) || return nothing
    for (directory, _, files) in walkdir(root)
        for filename in files
            any(extension -> endswith(filename, extension), (".csv", ".json", ".log", ".md")) || continue
            replace_code!(joinpath(directory, filename), old_code, new_code)
        end
    end
    return nothing
end

function main()
    lowdim_processed = joinpath(PROJECT_ROOT, "data", "processed", LOWDIM_NEW_CODE)
    for (directory, _, files) in walkdir(lowdim_processed)
        for filename in files
            filename == "processed_tensors.jld2" || continue
            update_lowdim_jld2!(joinpath(directory, filename))
        end
    end

    highdim_release = joinpath(PROJECT_ROOT, "data", "releases", HIGHDIM_NEW_CODE)
    for filename in readdir(highdim_release)
        endswith(filename, ".h5") || continue
        update_highdim_hdf5!(joinpath(highdim_release, filename))
    end

    for root in (
        joinpath(PROJECT_ROOT, "data", "manifests", LOWDIM_NEW_CODE),
        joinpath(PROJECT_ROOT, "data", "releases", LOWDIM_NEW_CODE),
        highdim_release,
        joinpath(PROJECT_ROOT, "reports", "v1_core", LOWDIM_NEW_CODE),
        joinpath(PROJECT_ROOT, "reports", "v2_core", HIGHDIM_NEW_CODE),
        joinpath(PROJECT_ROOT, "runs", "smoke_tests", LOWDIM_NEW_CODE),
        joinpath(PROJECT_ROOT, "runs", "smoke_tests", HIGHDIM_NEW_CODE),
    )
        update_text_files!(root, LOWDIM_OLD_CODE, LOWDIM_NEW_CODE)
        update_text_files!(root, HIGHDIM_OLD_CODE, HIGHDIM_NEW_CODE)
    end

    println("renamed active dataset metadata to $LOWDIM_NEW_CODE and $HIGHDIM_NEW_CODE")
    return nothing
end

main()
