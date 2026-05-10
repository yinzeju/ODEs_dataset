## Purpose and generation pipeline

using Dates
using Printf
using Random
using Statistics

## Load system and release configs

function kdsm_load_generation_configs(project_root::AbstractString)
    return Dict(
        "systems" => kdsm_load_toml(joinpath(project_root, "configs", "systems", "kdsm_duffing_diagnostic_v1_systems.toml")),
        "observations" => kdsm_load_toml(joinpath(project_root, "configs", "observations", "kdsm_duffing_diagnostic_v1_observations.toml")),
        "splits" => kdsm_load_toml(joinpath(project_root, "configs", "splits", "kdsm_duffing_diagnostic_v1_split_trajectory_I.toml")),
        "windows" => kdsm_load_toml(joinpath(project_root, "configs", "windows", "kdsm_duffing_diagnostic_v1_windows.toml")),
        "tasks" => kdsm_load_toml(joinpath(project_root, "configs", "tasks", "kdsm_duffing_diagnostic_v1_tasks.toml")),
        "benchmark" => kdsm_load_toml(joinpath(project_root, "configs", "benchmarks", "kdsm_duffing_diagnostic_v1_benchmark.toml")),
        "release" => kdsm_load_toml(joinpath(project_root, "configs", "releases", "kdsm_duffing_diagnostic_v1_release.toml")),
    )
end

function kdsm_config_hashes(project_root::AbstractString)
    paths = Dict(
        "systems" => joinpath(project_root, "configs", "systems", "kdsm_duffing_diagnostic_v1_systems.toml"),
        "observations" => joinpath(project_root, "configs", "observations", "kdsm_duffing_diagnostic_v1_observations.toml"),
        "splits" => joinpath(project_root, "configs", "splits", "kdsm_duffing_diagnostic_v1_split_trajectory_I.toml"),
        "windows" => joinpath(project_root, "configs", "windows", "kdsm_duffing_diagnostic_v1_windows.toml"),
        "tasks" => joinpath(project_root, "configs", "tasks", "kdsm_duffing_diagnostic_v1_tasks.toml"),
        "benchmark" => joinpath(project_root, "configs", "benchmarks", "kdsm_duffing_diagnostic_v1_benchmark.toml"),
        "release" => joinpath(project_root, "configs", "releases", "kdsm_duffing_diagnostic_v1_release.toml"),
    )
    return Dict(key => kdsm_file_sha256(path) for (key, path) in paths)
end

## Build object-level generation plan

function kdsm_build_generation_plan(
    system_config::AbstractDict;
    difficulty::AbstractString = "default",
)
    specs = [
        kdsm_duffing_object_spec(system_config, object_config; difficulty = difficulty)
        for object_config in system_config["objects"]
    ]
    ids = [spec.object_id for spec in specs]
    length(ids) == length(unique(ids)) || throw(ArgumentError("duplicate generated object ids"))
    return specs
end

function kdsm_stable_string_seed(label::AbstractString)
    acc = UInt32(2166136261)
    for byte in codeunits(label)
        acc = (acc ⊻ UInt32(byte)) * UInt32(16777619)
    end
    return Int(acc % UInt32(1_000_000_000))
end

function kdsm_object_rng(spec::KDSMDuffingObjectSpec)
    seed_label = startswith(spec.object_id, "kdsm_duffing__D9_noise_scan") ?
        "kdsm_duffing__D9_noise_scan_base" :
        spec.object_id
    return MersenneTwister(spec.generation_seed + kdsm_stable_string_seed(seed_label))
end

## Sample trajectory parameters and initial conditions

function kdsm_uniform(rng::AbstractRNG, lo::Real, hi::Real)
    return Float64(lo) + (Float64(hi) - Float64(lo)) * rand(rng)
end

function kdsm_sample_box_ic(rng::AbstractRNG, config::AbstractDict)
    q = kdsm_uniform(rng, Float64(config["q_min"]), Float64(config["q_max"]))
    p = kdsm_uniform(rng, Float64(config["p_min"]), Float64(config["p_max"]))
    return q, p
end

function kdsm_sample_physical_initial_condition(
    rng::AbstractRNG,
    spec::KDSMDuffingObjectSpec,
    trajectory_index::Integer,
)
    config = spec.raw_config
    if spec.ic_policy == "uniform_box" || spec.ic_policy == "uniform_box_with_phase" ||
            spec.ic_policy == "uniform_box_with_two_phases"
        q, p = kdsm_sample_box_ic(rng, config)
        metadata = Dict{String,Any}()
        if haskey(config, "well_metadata")
            metadata["well_region"] = String(config["well_metadata"])
        end
        return q, p, metadata
    elseif spec.ic_policy == "two_shell"
        if isodd(trajectory_index)
            q = kdsm_uniform(rng, -0.4, 0.4)
            p = kdsm_uniform(rng, -0.4, 0.4)
            return q, p, Dict{String,Any}("amplitude_shell" => "low")
        else
            if rand(rng) < 0.5
                q = kdsm_uniform(rng, -2.0, -1.2)
            else
                q = kdsm_uniform(rng, 1.2, 2.0)
            end
            p = kdsm_uniform(rng, -0.5, 0.5)
            return q, p, Dict{String,Any}("amplitude_shell" => "high")
        end
    elseif spec.ic_policy == "mixed_wells"
        if trajectory_index <= div(spec.R, 2)
            q = kdsm_uniform(rng, -1.2, -0.8)
            p = kdsm_uniform(rng, -0.2, 0.2)
            return q, p, Dict{String,Any}("well_region" => "left")
        else
            q = kdsm_uniform(rng, 0.8, 1.2)
            p = kdsm_uniform(rng, -0.2, 0.2)
            return q, p, Dict{String,Any}("well_region" => "right")
        end
    end
    throw(ArgumentError("unsupported initial condition policy: $(spec.ic_policy)"))
end

function kdsm_make_initial_state(
    rng::AbstractRNG,
    spec::KDSMDuffingObjectSpec,
    trajectory_index::Integer,
)
    q, p, physical_metadata = kdsm_sample_physical_initial_condition(rng, spec, trajectory_index)
    u0, forcing_metadata = kdsm_forcing_initial_state(rng, spec.forcing)
    x0 = vcat([q, p], u0)
    metadata = merge(
        Dict{String,Any}(
            "trajectory_index" => Int(trajectory_index),
            "q0" => q,
            "p0" => p,
        ),
        physical_metadata,
        forcing_metadata,
    )
    return x0, metadata
end

## Integrate augmented Duffing trajectories

function kdsm_generate_state_tensors(spec::KDSMDuffingObjectSpec)
    d_x = kdsm_state_dim(spec)
    X = Array{Float64}(undef, d_x, spec.M + 1, spec.R)
    x0s = Matrix{Float64}(undef, d_x, spec.R)
    metadata = Vector{Dict{String,Any}}(undef, spec.R)
    trajectory_ids = [string(spec.object_id, "__traj_", lpad(string(r), 4, '0')) for r in 1:spec.R]
    rng = kdsm_object_rng(spec)
    for r in 1:spec.R
        x0, traj_metadata = kdsm_make_initial_state(rng, spec, r)
        x0s[:, r] = x0
        metadata[r] = traj_metadata
        X[:, :, r] = kdsm_integrate_augmented_trajectory(spec, x0)
    end
    return trajectory_ids, x0s, metadata, X
end

## Assemble raw trajectory tensors

function kdsm_generate_dataset_object(
    spec::KDSMDuffingObjectSpec,
    split_config::AbstractDict;
    difficulty::AbstractString = "default",
)
    trajectory_ids, x0s, trajectory_metadata, state_aug = kdsm_generate_state_tensors(spec)
    state_phys = kdsm_state_phys(state_aug)
    forcing_state = kdsm_forcing_state_tensor(state_aug, spec)
    forcing_signal = kdsm_forcing_signal_tensor(state_aug, spec)
    split_roles, split_counts = kdsm_build_trajectory_split_roles(spec.R, split_config; difficulty = difficulty)

    clean_tensors = kdsm_build_clean_observations_and_targets(state_aug, state_phys, spec)
    noisy_tensors, noise_scales, noise_summary =
        kdsm_apply_noise_protocol(clean_tensors, split_roles, spec)
    kdsm_validate_noise_protocol(clean_tensors, noisy_tensors, spec)

    obj = KDSMDuffingDatasetObject(
        spec,
        trajectory_ids,
        x0s,
        trajectory_metadata,
        kdsm_time_grid(spec),
        state_aug,
        state_phys,
        forcing_state,
        forcing_signal,
        split_roles,
        Dict{String,Any}(clean_tensors),
        Dict{String,Any}(noisy_tensors),
        Dict{String,Any}(
            "policy" => "per_channel_train_split_std",
            "scales" => noise_scales,
            "noise_summary" => noise_summary,
        ),
        Dict{String,Any}(
            "split_counts" => split_counts,
            "generation_passed" => false,
        ),
    )
    kdsm_validate_dataset_object(obj)
    kdsm_finalize_object_diagnostics!(obj)
    return obj
end

## Write generation logs and status summary

function kdsm_generation_summary_row(obj::KDSMDuffingDatasetObject)
    diag = obj.diagnostics["manifest_summary"]
    split = obj.diagnostics["split_counts"]
    return [
        obj.spec.object_id,
        obj.spec.regime_id,
        obj.spec.forcing.forcing_id,
        obj.spec.noise_level_id,
        obj.spec.default_observation,
        obj.spec.default_target,
        obj.spec.R,
        obj.spec.M,
        obj.spec.tau,
        split["train"],
        split["val"],
        split["test"],
        diag["q_min"],
        diag["q_max"],
        diag["p_min"],
        diag["p_max"],
        diag["state_abs_max"],
        obj.diagnostics["passed"],
    ]
end

function kdsm_dimension_summary_rows(obj::KDSMDuffingDatasetObject)
    rows = Vector{Vector{Any}}()
    for (name, dims) in sort(collect(obj.diagnostics["dimension_summary"]); by = first)
        push!(rows, [obj.spec.object_id, name, join(dims, "x")])
    end
    return rows
end

function kdsm_noise_summary_rows(obj::KDSMDuffingDatasetObject)
    rows = Vector{Vector{Any}}()
    for (name, diag) in sort(collect(obj.diagnostics["noise_diagnostics"]); by = first)
        push!(rows, [
            obj.spec.object_id,
            obj.spec.noise_level_id,
            obj.spec.noise_sigma,
            name,
            diag["source_tensor"],
            diag["rms"],
            diag["abs_max"],
        ])
    end
    return rows
end

function kdsm_write_report_tables(
    project_root::AbstractString,
    release_id::AbstractString,
    objects::AbstractVector{KDSMDuffingDatasetObject},
)
    table_root = joinpath(project_root, "reports", "v1_core", release_id, "tables")
    generation_path = joinpath(table_root, "$(release_id)_generation_summary.csv")
    dimension_path = joinpath(table_root, "$(release_id)_dimension_summary.csv")
    noise_path = joinpath(table_root, "$(release_id)_noise_summary.csv")

    generation_rows = [kdsm_generation_summary_row(obj) for obj in objects]
    dimension_rows = reduce(vcat, [kdsm_dimension_summary_rows(obj) for obj in objects])
    noise_rows = reduce(vcat, [kdsm_noise_summary_rows(obj) for obj in objects])

    kdsm_write_csv(
        generation_path,
        [
            "object_id",
            "regime_id",
            "forcing_id",
            "noise_level",
            "default_observation",
            "default_target",
            "R",
            "M",
            "tau",
            "train_count",
            "val_count",
            "test_count",
            "q_min",
            "q_max",
            "p_min",
            "p_max",
            "state_abs_max",
            "passed",
        ],
        generation_rows,
    )
    kdsm_write_csv(dimension_path, ["object_id", "tensor_name", "shape"], dimension_rows)
    kdsm_write_csv(
        noise_path,
        ["object_id", "noise_level", "sigma", "tensor_name", "source_tensor", "noise_rms", "noise_abs_max"],
        noise_rows,
    )
    return Dict(
        "generation_summary" => generation_path,
        "dimension_summary" => dimension_path,
        "noise_summary" => noise_path,
    )
end

function kdsm_write_generation_log(
    project_root::AbstractString,
    release_id::AbstractString,
    objects::AbstractVector{KDSMDuffingDatasetObject},
    output_paths::AbstractDict,
)
    log_path = joinpath(project_root, "reports", "v1_core", release_id, "logs", "$(release_id)_generation.log")
    kdsm_ensure_parent_dir(log_path)
    open(log_path, "w") do io
        println(io, "release_id: ", release_id)
        println(io, "created_at: ", now())
        println(io, "object_count: ", length(objects))
        println(io, "all_passed: ", all(obj -> obj.diagnostics["passed"], objects))
        println(io, "release_manifest: ", output_paths["release_manifest"])
        println(io, "release_index: ", output_paths["release_index"])
        for obj in objects
            diag = obj.diagnostics["manifest_summary"]
            split = obj.diagnostics["split_counts"]
            println(
                io,
                obj.spec.object_id,
                " | forcing=", obj.spec.forcing.forcing_id,
                " | shape=", size(obj.state_aug),
                " | split=", split,
                " | q=[", diag["q_min"], ", ", diag["q_max"], "]",
                " | p=[", diag["p_min"], ", ", diag["p_max"], "]",
                " | passed=", obj.diagnostics["passed"],
            )
        end
    end
    return log_path
end

## Save release manifests

function kdsm_run_release_generation(
    project_root::AbstractString;
    difficulty::AbstractString = "default",
)
    configs = kdsm_load_generation_configs(project_root)
    kdsm_validate_registry_configs(configs["systems"], configs["observations"])
    specs = kdsm_build_generation_plan(configs["systems"]; difficulty = difficulty)

    objects = KDSMDuffingDatasetObject[]
    object_manifests = Dict{String,Any}[]
    manifest_paths = Dict{String,String}()
    raw_paths = Dict{String,String}()
    processed_paths = Dict{String,String}()

    for spec in specs
        @printf("generating %s\n", spec.object_id)
        obj = kdsm_generate_dataset_object(spec, configs["splits"]; difficulty = difficulty)
        raw_path = kdsm_save_raw_object(kdsm_raw_path(project_root, spec), obj)
        processed_path = kdsm_save_processed_object(kdsm_processed_path(project_root, spec), obj)
        manifest = kdsm_object_manifest(obj, raw_path, processed_path)
        kdsm_validate_manifest_paths(manifest)
        manifest_path = kdsm_manifest_path(project_root, spec)
        kdsm_write_toml(manifest_path, manifest)
        push!(objects, obj)
        push!(object_manifests, manifest)
        manifest_paths[spec.object_id] = manifest_path
        raw_paths[spec.object_id] = raw_path
        processed_paths[spec.object_id] = processed_path
        @printf("  saved %s | state_aug=%s | passed=%s\n", spec.object_id, string(size(obj.state_aug)), string(obj.diagnostics["passed"]))
    end

    release_id = kdsm_registered_release_id()
    report_tables = kdsm_write_report_tables(project_root, release_id, objects)
    release_root = kdsm_release_root(project_root, release_id)
    release_manifest_path = joinpath(release_root, "release_manifest.toml")
    release_index_path = joinpath(release_root, "release_index.toml")
    output_paths = Dict{String,Any}(
        "raw_paths" => raw_paths,
        "processed_paths" => processed_paths,
        "manifest_paths" => manifest_paths,
        "report_tables" => report_tables,
        "release_manifest" => release_manifest_path,
        "release_index" => release_index_path,
    )
    release_manifest = kdsm_release_manifest(
        release_id,
        object_manifests,
        output_paths,
        kdsm_config_hashes(project_root),
    )
    kdsm_write_toml(release_manifest_path, release_manifest)
    release_index = Dict{String,Any}(
        "release_id" => release_id,
        "difficulty" => difficulty,
        "object_count" => length(objects),
        "object_ids" => [obj.spec.object_id for obj in objects],
        "release_manifest_path" => release_manifest_path,
        "created_at" => string(now()),
        "all_passed" => all(obj -> obj.diagnostics["passed"], objects),
    )
    kdsm_write_toml(release_index_path, release_index)
    log_path = kdsm_write_generation_log(project_root, release_id, objects, output_paths)
    output_paths["log"] = log_path

    return Dict(
        "configs" => configs,
        "objects" => objects,
        "object_manifests" => object_manifests,
        "output_paths" => output_paths,
        "release_index" => release_index,
    )
end

function kdsm_print_release_summary(result::AbstractDict)
    objects = result["objects"]
    output_paths = result["output_paths"]
    @printf("release_id: %s\n", kdsm_registered_release_id())
    @printf("object_count: %d\n", length(objects))
    @printf("all_passed: %s\n", string(all(obj -> obj.diagnostics["passed"], objects)))
    for obj in objects
        split = obj.diagnostics["split_counts"]
        @printf(
            "%s | forcing=%s | state_aug=%s | split=%d/%d/%d | noise=%s | passed=%s\n",
            obj.spec.object_id,
            obj.spec.forcing.forcing_id,
            string(size(obj.state_aug)),
            split["train"],
            split["val"],
            split["test"],
            obj.spec.noise_level_id,
            string(obj.diagnostics["passed"]),
        )
    end
    @printf("release_manifest: %s\n", output_paths["release_manifest"])
    @printf("release_index: %s\n", output_paths["release_index"])
    @printf("generation_summary: %s\n", output_paths["report_tables"]["generation_summary"])
    @printf("log: %s\n", output_paths["log"])
end
