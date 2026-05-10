## Load frozen generation configs

using Dates
using Printf
using Random
using Statistics

function kbasic_load_generation_configs(project_root::AbstractString)
    return Dict(
        "systems" => kbasic_load_toml(joinpath(project_root, "configs", "systems", "kdsm_basic_diagnostic_v1_systems.toml")),
        "observations" => kbasic_load_toml(joinpath(project_root, "configs", "observations", "kdsm_basic_diagnostic_v1_observations.toml")),
        "splits" => kbasic_load_toml(joinpath(project_root, "configs", "splits", "kdsm_basic_diagnostic_v1_split_trajectory_I.toml")),
        "windows" => kbasic_load_toml(joinpath(project_root, "configs", "windows", "kdsm_basic_diagnostic_v1_windows.toml")),
        "tasks" => kbasic_load_toml(joinpath(project_root, "configs", "tasks", "kdsm_basic_diagnostic_v1_tasks.toml")),
        "benchmark" => kbasic_load_toml(joinpath(project_root, "configs", "benchmarks", "kdsm_basic_diagnostic_v1_benchmark.toml")),
        "release" => kbasic_load_toml(joinpath(project_root, "configs", "releases", "kdsm_basic_diagnostic_v1_release.toml")),
    )
end

function kbasic_config_hashes(project_root::AbstractString)
    paths = Dict(
        "systems" => joinpath(project_root, "configs", "systems", "kdsm_basic_diagnostic_v1_systems.toml"),
        "observations" => joinpath(project_root, "configs", "observations", "kdsm_basic_diagnostic_v1_observations.toml"),
        "splits" => joinpath(project_root, "configs", "splits", "kdsm_basic_diagnostic_v1_split_trajectory_I.toml"),
        "windows" => joinpath(project_root, "configs", "windows", "kdsm_basic_diagnostic_v1_windows.toml"),
        "tasks" => joinpath(project_root, "configs", "tasks", "kdsm_basic_diagnostic_v1_tasks.toml"),
        "benchmark" => joinpath(project_root, "configs", "benchmarks", "kdsm_basic_diagnostic_v1_benchmark.toml"),
        "release" => joinpath(project_root, "configs", "releases", "kdsm_basic_diagnostic_v1_release.toml"),
    )
    return Dict(key => kbasic_file_sha256(path) for (key, path) in paths)
end

function kbasic_build_generation_plan(system_config::AbstractDict; difficulty::AbstractString = "default")
    specs = [
        kbasic_object_spec(system_config, object_config; difficulty = difficulty)
        for object_config in system_config["objects"]
    ]
    ids = [spec.object_id for spec in specs]
    ids == kbasic_expected_object_ids() ||
        throw(ArgumentError("generation plan must follow the fixed kdsm_basic ladder"))
    return specs
end

function kbasic_stable_string_seed(label::AbstractString)
    acc = UInt32(2166136261)
    for byte in codeunits(label)
        acc = (acc ⊻ UInt32(byte)) * UInt32(16777619)
    end
    return Int(acc % UInt32(1_000_000_000))
end

function kbasic_object_rng(spec::KDSMBasicObjectSpec)
    return MersenneTwister(spec.generation_seed + kbasic_stable_string_seed(spec.object_id))
end

## Initialize reproducible trajectory seeds

function kbasic_sample_initial_condition(
    rng::AbstractRNG,
    spec::KDSMBasicObjectSpec,
    trajectory_index::Integer,
)
    bands = (
        ("small", 0.1, 0.4),
        ("mid", 0.4, 0.8),
        ("large", 0.8, 1.2),
    )
    band = bands[mod1(Int(trajectory_index), length(bands))]
    label, lo, hi = band
    radius = lo + (hi - lo) * rand(rng)
    angle = 2.0 * pi * rand(rng)
    q0 = radius * cos(angle)
    p0 = radius * sin(angle)
    return [q0, p0], String(label)
end

## Generate raw state trajectories

function kbasic_generate_state_tensor(spec::KDSMBasicObjectSpec)
    X = Array{Float64}(undef, spec.R, spec.M + 1, 2)
    x0s = Matrix{Float64}(undef, spec.R, 2)
    amplitude_groups = Vector{String}(undef, spec.R)
    metadata = Vector{Dict{String,Any}}(undef, spec.R)
    trajectory_ids = [string(spec.object_id, "__traj_", lpad(string(r), 4, '0')) for r in 1:spec.R]
    rng = kbasic_object_rng(spec)
    for r in 1:spec.R
        x0, group = kbasic_sample_initial_condition(rng, spec, r)
        x0s[r, :] .= x0
        amplitude_groups[r] = group
        metadata[r] = Dict{String,Any}(
            "trajectory_index" => r,
            "q0" => x0[1],
            "p0" => x0[2],
            "amplitude0" => hypot(x0[1], x0[2]),
            "amplitude_group" => group,
        )
        trajectory = kbasic_generate_trajectory(spec, x0)
        @views X[r, :, :] .= trajectory
    end
    return trajectory_ids, x0s, amplitude_groups, metadata, X
end

## Attach initial-condition and amplitude metadata

function kbasic_generate_dataset_object(
    spec::KDSMBasicObjectSpec,
    split_config::AbstractDict,
    window_config::AbstractDict;
    difficulty::AbstractString = "default",
)
    trajectory_ids, x0s, amplitude_groups, trajectory_metadata, X = kbasic_generate_state_tensor(spec)
    split_roles, split_counts = kbasic_build_trajectory_split_roles(spec.R, split_config; difficulty = difficulty)

    ## Build processed observation and target tensors
    observations = kbasic_build_observations_and_targets(X)
    window_metadata = kbasic_window_metadata(spec.M, split_roles, window_config)
    system_metadata = kbasic_true_system_metadata(spec)

    ## Run dataset-side diagnostics
    obj = KDSMBasicDatasetObject(
        spec,
        trajectory_ids,
        x0s,
        amplitude_groups,
        trajectory_metadata,
        kbasic_time_grid(spec),
        X,
        observations,
        split_roles,
        window_metadata,
        system_metadata,
        Dict{String,Any}("split_counts" => split_counts, "generation_passed" => false),
    )
    kbasic_validate_dataset_object(obj)
    kbasic_finalize_object_diagnostics!(obj)
    return obj
end

## Save raw, processed, and manifest outputs

function kbasic_generation_summary_row(obj::KDSMBasicDatasetObject)
    diag = obj.diagnostics["manifest_summary"]
    split = obj.diagnostics["split_counts"]
    amplitude = obj.diagnostics["amplitude_counts"]
    return [
        obj.spec.object_id,
        obj.spec.regime_id,
        obj.spec.system_kind,
        obj.spec.alpha,
        obj.spec.beta,
        obj.spec.delta,
        obj.spec.gamma,
        obj.spec.R,
        obj.spec.M,
        obj.spec.tau,
        split["train"],
        split["val"],
        split["test"],
        amplitude["small"],
        amplitude["mid"],
        amplitude["large"],
        diag["state_abs_max"],
        diag["linear_recurrence_error_max"],
        obj.diagnostics["passed"],
    ]
end

function kbasic_window_count_rows(obj::KDSMBasicDatasetObject)
    rows = Vector{Vector{Any}}()
    one = obj.window_metadata["one_step"]["counts"]
    for role in ("train", "val", "test")
        push!(rows, [obj.spec.object_id, "one_step", 1, role, one[role]])
    end
    rollout = obj.window_metadata["rollout"]["counts"]
    for h in obj.window_metadata["rollout"]["horizons"], role in ("train", "val", "test")
        push!(rows, [obj.spec.object_id, "rollout", h, role, rollout[string(h)][role]])
    end
    return rows
end

function kbasic_state_statistics_row(obj::KDSMBasicDatasetObject)
    diag = obj.diagnostics["manifest_summary"]
    return [
        obj.spec.object_id,
        diag["q_min"],
        diag["q_max"],
        diag["p_min"],
        diag["p_max"],
        diag["q_mean"],
        diag["p_mean"],
        diag["q_std"],
        diag["p_std"],
        diag["state_abs_max"],
        diag["nonfinite_count"],
        diag["final_le_initial_fraction"],
        diag["mean_energy_drop"],
    ]
end

function kbasic_write_report_tables(
    project_root::AbstractString,
    release_id::AbstractString,
    objects::AbstractVector{KDSMBasicDatasetObject},
)
    table_root = joinpath(project_root, "reports", "unit_internal", release_id, "tables")
    object_summary_path = joinpath(table_root, "$(release_id)_object_summary.csv")
    window_counts_path = joinpath(table_root, "$(release_id)_window_counts.csv")
    state_statistics_path = joinpath(table_root, "$(release_id)_state_statistics.csv")

    kbasic_write_csv(
        object_summary_path,
        [
            "object_id",
            "regime_id",
            "system_kind",
            "alpha",
            "beta",
            "delta",
            "gamma",
            "R",
            "M",
            "tau",
            "train_count",
            "val_count",
            "test_count",
            "amplitude_small",
            "amplitude_mid",
            "amplitude_large",
            "state_abs_max",
            "linear_recurrence_error_max",
            "passed",
        ],
        [kbasic_generation_summary_row(obj) for obj in objects],
    )
    kbasic_write_csv(
        window_counts_path,
        ["object_id", "window_type", "horizon", "split", "count"],
        reduce(vcat, [kbasic_window_count_rows(obj) for obj in objects]),
    )
    kbasic_write_csv(
        state_statistics_path,
        [
            "object_id",
            "q_min",
            "q_max",
            "p_min",
            "p_max",
            "q_mean",
            "p_mean",
            "q_std",
            "p_std",
            "state_abs_max",
            "nonfinite_count",
            "final_le_initial_fraction",
            "mean_energy_drop",
        ],
        [kbasic_state_statistics_row(obj) for obj in objects],
    )
    return Dict(
        "object_summary" => object_summary_path,
        "window_counts" => window_counts_path,
        "state_statistics" => state_statistics_path,
    )
end

function kbasic_write_generation_log(
    project_root::AbstractString,
    release_id::AbstractString,
    objects::AbstractVector{KDSMBasicDatasetObject},
    output_paths::AbstractDict,
)
    log_path = joinpath(project_root, "reports", "unit_internal", release_id, "logs", "$(release_id)_generation.log")
    kbasic_ensure_parent_dir(log_path)
    open(log_path, "w") do io
        println(io, "release_id: ", release_id)
        println(io, "created_at: ", now())
        println(io, "object_count: ", length(objects))
        println(io, "all_passed: ", all(obj -> obj.diagnostics["passed"], objects))
        println(io, "release_manifest: ", output_paths["release_manifest"])
        println(io, "release_index: ", output_paths["release_index"])
        println(io, "checksums: ", output_paths["checksums"])
        for obj in objects
            diag = obj.diagnostics["manifest_summary"]
            split = obj.diagnostics["split_counts"]
            println(
                io,
                obj.spec.object_id,
                " | kind=", obj.spec.system_kind,
                " | beta=", obj.spec.beta,
                " | shape=", size(obj.state),
                " | split=", split,
                " | state_abs_max=", diag["state_abs_max"],
                " | recurrence_error=", diag["linear_recurrence_error_max"],
                " | passed=", obj.diagnostics["passed"],
            )
        end
    end
    return log_path
end

function kbasic_run_release_generation(
    project_root::AbstractString;
    difficulty::AbstractString = "default",
)
    configs = kbasic_load_generation_configs(project_root)
    kbasic_validate_registry_configs(configs["systems"], configs["observations"])
    specs = kbasic_build_generation_plan(configs["systems"]; difficulty = difficulty)

    objects = KDSMBasicDatasetObject[]
    object_manifests = Dict{String,Any}[]
    manifest_paths = Dict{String,String}()
    raw_paths = Dict{String,String}()
    processed_paths = Dict{String,String}()

    for spec in specs
        @printf("generating %s\n", spec.object_id)
        obj = kbasic_generate_dataset_object(spec, configs["splits"], configs["windows"]; difficulty = difficulty)
        raw_path = kbasic_save_raw_object(kbasic_raw_path(project_root, spec), obj)
        processed_path = kbasic_save_processed_object(kbasic_processed_path(project_root, spec), obj)
        kbasic_reload_verify(raw_path, processed_path)
        manifest = kbasic_object_manifest(obj, raw_path, processed_path)
        kbasic_validate_manifest_paths(manifest)
        manifest_path = kbasic_manifest_path(project_root, spec)
        kbasic_write_toml(manifest_path, manifest)
        push!(objects, obj)
        push!(object_manifests, manifest)
        manifest_paths[spec.object_id] = manifest_path
        raw_paths[spec.object_id] = raw_path
        processed_paths[spec.object_id] = processed_path
        @printf("  saved %s | state=%s | passed=%s\n", spec.object_id, string(size(obj.state)), string(obj.diagnostics["passed"]))
    end

    release_id = kbasic_registered_release_id()
    report_tables = kbasic_write_report_tables(project_root, release_id, objects)
    release_root = kbasic_release_root(project_root, release_id)
    release_manifest_path = joinpath(release_root, "kdsm_basic_diagnostic_v1_manifest.toml")
    release_index_path = joinpath(release_root, "release_index.toml")
    checksums_path = joinpath(release_root, "checksums.toml")
    output_paths = Dict{String,Any}(
        "raw_paths" => raw_paths,
        "processed_paths" => processed_paths,
        "manifest_paths" => manifest_paths,
        "report_tables" => report_tables,
        "release_manifest" => release_manifest_path,
        "release_index" => release_index_path,
        "checksums" => checksums_path,
    )
    release_manifest = kbasic_release_manifest(
        release_id,
        object_manifests,
        output_paths,
        kbasic_config_hashes(project_root),
    )
    kbasic_write_toml(release_manifest_path, release_manifest)
    release_index = Dict{String,Any}(
        "release_id" => release_id,
        "difficulty" => difficulty,
        "object_count" => length(objects),
        "object_ids" => [obj.spec.object_id for obj in objects],
        "release_manifest_path" => release_manifest_path,
        "checksums_path" => checksums_path,
        "created_at" => string(now()),
        "all_passed" => all(obj -> obj.diagnostics["passed"], objects),
    )
    kbasic_write_toml(release_index_path, release_index)
    checksums = kbasic_write_checksums(
        checksums_path,
        Dict(
            "raw" => raw_paths,
            "processed" => processed_paths,
            "manifests" => manifest_paths,
            "release_manifest" => release_manifest_path,
            "release_index" => release_index_path,
        ),
    )
    log_path = kbasic_write_generation_log(project_root, release_id, objects, output_paths)
    output_paths["log"] = log_path

    return Dict(
        "configs" => configs,
        "objects" => objects,
        "object_manifests" => object_manifests,
        "output_paths" => output_paths,
        "release_index" => release_index,
        "checksums" => checksums,
    )
end

function kbasic_print_release_summary(result::AbstractDict)
    objects = result["objects"]
    output_paths = result["output_paths"]
    @printf("release_id: %s\n", kbasic_registered_release_id())
    @printf("object_count: %d\n", length(objects))
    @printf("all_passed: %s\n", string(all(obj -> obj.diagnostics["passed"], objects)))
    for obj in objects
        split = obj.diagnostics["split_counts"]
        diag = obj.diagnostics["manifest_summary"]
        @printf(
            "%s | kind=%s | beta=%.5g | state=%s | split=%d/%d/%d | recurrence=%.3e | passed=%s\n",
            obj.spec.object_id,
            obj.spec.system_kind,
            obj.spec.beta,
            string(size(obj.state)),
            split["train"],
            split["val"],
            split["test"],
            diag["linear_recurrence_error_max"],
            string(obj.diagnostics["passed"]),
        )
    end
    @printf("release_manifest: %s\n", output_paths["release_manifest"])
    @printf("release_index: %s\n", output_paths["release_index"])
    @printf("checksums: %s\n", output_paths["checksums"])
    @printf("object_summary: %s\n", output_paths["report_tables"]["object_summary"])
    @printf("log: %s\n", output_paths["log"])
end
