## Duffing nonlinearity basic v1 release generator

using Base.Threads: nthreads
using Dates
using Printf
using Random

function dnlbasic_release_id()
    return "duffing_nonlinearity_basic_v1"
end

function dnlbasic_config_paths(project_root::AbstractString)
    release_id = dnlbasic_release_id()
    return Dict(
        "systems" => joinpath(project_root, "configs", "systems", "$(release_id)_systems.toml"),
        "observations" => joinpath(project_root, "configs", "observations", "$(release_id)_observations.toml"),
        "splits" => joinpath(project_root, "configs", "splits", "$(release_id)_split_trajectory_I.toml"),
        "windows" => joinpath(project_root, "configs", "windows", "$(release_id)_windows.toml"),
        "tasks" => joinpath(project_root, "configs", "tasks", "$(release_id)_tasks.toml"),
        "benchmark" => joinpath(project_root, "configs", "benchmarks", "$(release_id)_benchmark.toml"),
        "release" => joinpath(project_root, "configs", "releases", "$(release_id)_release.toml"),
    )
end

function dnlbasic_load_generation_configs(project_root::AbstractString)
    paths = dnlbasic_config_paths(project_root)
    return Dict(key => dnlmat_load_toml(path) for (key, path) in paths)
end

function dnlbasic_config_hashes(project_root::AbstractString)
    return Dict(key => dnlmat_file_sha256(path) for (key, path) in dnlbasic_config_paths(project_root))
end

function dnlbasic_build_generation_plan(system_config::AbstractDict; difficulty::AbstractString = "formal")
    profile = dnlmat_profile(system_config, difficulty)
    specs = DuffingNLMatrixSpec[]
    base_Q = Float64(system_config["linear_base_Q"])
    push!(
        specs,
        dnlmat_make_spec(
            system_config,
            "L0_discrete_damped_rotation",
            "L0",
            0.0,
            base_Q,
            profile,
        ),
    )
    push!(
        specs,
        dnlmat_make_spec(
            system_config,
            "L1_continuous_linear_oscillator",
            "L1",
            0.0,
            base_Q,
            profile,
        ),
    )

    duffing_rows = sort(
        collect(system_config["duffing_objects"]);
        by = row -> Float64(row["beta"]) * Float64(row["Q"])^2,
    )
    length(duffing_rows) == 5 || throw(ArgumentError("duffing_nonlinearity_basic_v1 requires exactly 5 Duffing objects"))
    previous_chi = -Inf
    for row in duffing_rows
        beta = Float64(row["beta"])
        Q = Float64(row["Q"])
        chi = beta * Q^2
        chi > previous_chi || throw(ArgumentError("Duffing objects must have strictly increasing chi_nl"))
        object_id = String(get(row, "object_id", dnlmat_duffing_object_id(beta, Q)))
        expected_id = dnlmat_duffing_object_id(beta, Q)
        object_id == expected_id || throw(ArgumentError("object_id $(object_id) does not match beta/Q code $(expected_id)"))
        push!(specs, dnlmat_make_spec(system_config, object_id, "duffing", beta, Q, profile))
        previous_chi = chi
    end
    return specs
end

function dnlbasic_build_split_roles(split_config::AbstractDict, spec::DuffingNLMatrixSpec; difficulty::AbstractString)
    count_key = string(difficulty, "_counts")
    haskey(split_config, count_key) || throw(ArgumentError("missing split count table $(count_key)"))
    counts = split_config[count_key]
    train = Int(counts["train"])
    val = Int(counts["val"])
    test = Int(counts["test"])
    train + val + test == spec.R || throw(ArgumentError("split counts must sum to R=$(spec.R)"))
    rng = MersenneTwister(Int(split_config["seed"]))
    order = collect(1:spec.R)
    shuffle!(rng, order)
    roles = fill("unassigned", spec.R)
    roles[order[1:train]] .= "train"
    roles[order[(train + 1):(train + val)]] .= "val"
    roles[order[(train + val + 1):end]] .= "test"
    all(role -> role in ("train", "val", "test"), roles) || throw(ArgumentError("invalid split role"))
    return roles, Dict("train" => train, "val" => val, "test" => test)
end

function dnlbasic_release_manifest(
    release_id::AbstractString,
    release_version::AbstractString,
    object_manifests::AbstractVector{<:AbstractDict},
    output_paths::AbstractDict,
    config_hashes::AbstractDict,
    initial_condition_checks::AbstractDict,
)
    manifest = dnlmat_release_manifest(
        release_id,
        release_version,
        object_manifests,
        output_paths,
        config_hashes,
        initial_condition_checks,
    )
    manifest["split_protocol"] = "duffing_nonlinearity_basic_v1_split_trajectory_I"
    manifest["selection_rule"] = "Two linear health checks plus five Duffing cells sorted by chi_nl = beta * Q^2."
    return manifest
end

function dnlbasic_run_release_generation(project_root::AbstractString; difficulty::AbstractString = "formal")
    configs = dnlbasic_load_generation_configs(project_root)
    specs = dnlbasic_build_generation_plan(configs["systems"]; difficulty = difficulty)
    reference_spec = first(specs)
    split_roles, split_counts = dnlbasic_build_split_roles(configs["splits"], reference_spec; difficulty = difficulty)
    x0_libraries, x0_stats = dnlmat_initial_condition_libraries(configs["systems"], specs)

    objects = DuffingNLMatrixObject[]
    object_manifests = Dict{String,Any}[]
    raw_paths = Dict{String,String}()
    processed_paths = Dict{String,String}()
    manifest_paths = Dict{String,String}()

    @printf("release_id: %s\n", dnlbasic_release_id())
    @printf("difficulty: %s\n", difficulty)
    @printf(
        "objects: %d (%d Duffing cells), split=%d/%d/%d, threads=%d\n",
        length(specs),
        count(spec -> spec.object_kind == "duffing", specs),
        split_counts["train"],
        split_counts["val"],
        split_counts["test"],
        nthreads(),
    )

    for (i, spec) in enumerate(specs)
        @printf("[%02d/%02d] generating %s\n", i, length(specs), spec.object_id)
        x0s = x0_libraries[spec.amplitude_Q]
        obj = dnlmat_generate_object(spec, x0s, split_roles, configs["windows"])
        raw_path = dnlmat_save_raw_object(dnlmat_raw_path(project_root, spec), obj)
        processed_path = dnlmat_save_processed_object(dnlmat_processed_path(project_root, spec), obj)
        dnlmat_reload_verify(raw_path, processed_path)
        manifest = dnlmat_object_manifest(obj, raw_path, processed_path)
        manifest_path = dnlmat_manifest_path(project_root, spec)
        dnlmat_write_toml(manifest_path, manifest)
        push!(objects, obj)
        push!(object_manifests, manifest)
        raw_paths[spec.object_id] = raw_path
        processed_paths[spec.object_id] = processed_path
        manifest_paths[spec.object_id] = manifest_path
        @printf(
            "  saved state=%s chi=%.6g energy_violations=%d passed=%s\n",
            string(size(obj.state)),
            spec.chi_nl,
            obj.diagnostics["energy"]["final_energy_violation_count"],
            string(obj.diagnostics["passed"]),
        )
    end

    initial_condition_checks = dnlmat_initial_condition_reuse_checks(objects)
    all_ic_passed = all(check["passed"] for (_, check) in initial_condition_checks)
    all(obj -> obj.diagnostics["passed"], objects) || error("one or more generated objects failed diagnostics")
    all_ic_passed || error("initial condition reuse check failed")

    release_id = dnlbasic_release_id()
    release_version = String(get(configs["release"], "release_version", "1.0.0"))
    report_tables = dnlmat_write_report_tables(project_root, release_id, objects)
    release_root = dnlmat_release_root(project_root, release_id)
    release_manifest_path = joinpath(release_root, "$(release_id)_manifest.toml")
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
    release_manifest = dnlbasic_release_manifest(
        release_id,
        release_version,
        object_manifests,
        output_paths,
        dnlbasic_config_hashes(project_root),
        Dict("libraries" => x0_stats, "reuse_checks" => initial_condition_checks),
    )
    dnlmat_write_toml(release_manifest_path, release_manifest)
    release_index = Dict{String,Any}(
        "release_id" => release_id,
        "release_version" => release_version,
        "difficulty" => difficulty,
        "object_count" => length(objects),
        "duffing_cell_count" => count(obj -> obj.spec.object_kind == "duffing", objects),
        "object_ids" => [obj.spec.object_id for obj in objects],
        "release_manifest_path" => release_manifest_path,
        "checksums_path" => checksums_path,
        "created_at" => string(now()),
        "all_passed" => all(obj -> obj.diagnostics["passed"], objects),
        "initial_condition_reuse_passed" => all_ic_passed,
    )
    dnlmat_write_toml(release_index_path, release_index)
    checksums = dnlmat_write_checksums(
        checksums_path,
        Dict(
            "raw" => raw_paths,
            "processed" => processed_paths,
            "manifests" => manifest_paths,
            "release_manifest" => release_manifest_path,
            "release_index" => release_index_path,
        ),
    )
    log_path = dnlmat_write_generation_log(project_root, release_id, objects, output_paths)
    output_paths["log"] = log_path

    return Dict(
        "configs" => configs,
        "objects" => objects,
        "object_manifests" => object_manifests,
        "output_paths" => output_paths,
        "release_index" => release_index,
        "checksums" => checksums,
        "initial_condition_checks" => initial_condition_checks,
    )
end

function dnlbasic_print_release_summary(result::AbstractDict)
    objects = result["objects"]
    output_paths = result["output_paths"]
    duffing_objects = [obj for obj in objects if obj.spec.object_kind == "duffing"]
    @printf("release_id: %s\n", dnlbasic_release_id())
    @printf("object_count: %d\n", length(objects))
    @printf("duffing_cell_count: %d\n", length(duffing_objects))
    @printf("all_passed: %s\n", string(all(obj -> obj.diagnostics["passed"], objects)))
    @printf("initial_condition_reuse_passed: %s\n", string(all(check["passed"] for (_, check) in result["initial_condition_checks"])))
    @printf("chi_values: %s\n", join([string(obj.spec.chi_nl) for obj in duffing_objects], ", "))
    @printf("release_manifest: %s\n", output_paths["release_manifest"])
    @printf("release_index: %s\n", output_paths["release_index"])
    @printf("checksums: %s\n", output_paths["checksums"])
    @printf("object_summary: %s\n", output_paths["report_tables"]["object_summary"])
    @printf("matrix_summary: %s\n", output_paths["report_tables"]["matrix_summary"])
    @printf("log: %s\n", output_paths["log"])
end
