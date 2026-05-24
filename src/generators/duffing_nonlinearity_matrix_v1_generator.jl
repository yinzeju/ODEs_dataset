## Duffing nonlinearity matrix v1 formal release generator

using Base.Threads: @threads, nthreads
using Dates
using JLD2
using Printf
using SHA
using Statistics
using TOML

struct DuffingNLMatrixObject
    spec::DuffingNLMatrixSpec
    trajectory_ids::Vector{String}
    initial_conditions::Matrix{Float64}
    trajectory_metadata::Vector{Dict{String,Any}}
    time_grid::Vector{Float64}
    state::Array{Float64,3}
    split_roles::Vector{String}
    window_metadata::Dict{String,Any}
    system_metadata::Dict{String,Any}
    diagnostics::Dict{String,Any}
end

function dnlmat_load_toml(path::AbstractString)
    return TOML.parsefile(path)
end

function dnlmat_write_toml(path::AbstractString, object::AbstractDict)
    dnlmat_ensure_parent_dir(path)
    open(path, "w") do io
        TOML.print(io, object)
    end
    return path
end

function dnlmat_ensure_parent_dir(path::AbstractString)
    dir = dirname(path)
    isempty(dir) || mkpath(dir)
    return path
end

function dnlmat_release_id()
    return "duffing_nonlinearity_matrix_v1"
end

function dnlmat_config_paths(project_root::AbstractString)
    return Dict(
        "systems" => joinpath(project_root, "configs", "systems", "duffing_nonlinearity_matrix_v1_systems.toml"),
        "observations" => joinpath(project_root, "configs", "observations", "duffing_nonlinearity_matrix_v1_observations.toml"),
        "splits" => joinpath(project_root, "configs", "splits", "duffing_nonlinearity_matrix_v1_split_trajectory_I.toml"),
        "windows" => joinpath(project_root, "configs", "windows", "duffing_nonlinearity_matrix_v1_windows.toml"),
        "tasks" => joinpath(project_root, "configs", "tasks", "duffing_nonlinearity_matrix_v1_tasks.toml"),
        "benchmark" => joinpath(project_root, "configs", "benchmarks", "duffing_nonlinearity_matrix_v1_benchmark.toml"),
        "release" => joinpath(project_root, "configs", "releases", "duffing_nonlinearity_matrix_v1_release.toml"),
    )
end

function dnlmat_load_generation_configs(project_root::AbstractString)
    paths = dnlmat_config_paths(project_root)
    return Dict(key => dnlmat_load_toml(path) for (key, path) in paths)
end

function dnlmat_file_sha256(path::AbstractString)
    isfile(path) || return "missing"
    return bytes2hex(open(sha256, path))
end

function dnlmat_config_hashes(project_root::AbstractString)
    return Dict(key => dnlmat_file_sha256(path) for (key, path) in dnlmat_config_paths(project_root))
end

function dnlmat_profile(system_config::AbstractDict, difficulty::AbstractString)
    profile = system_config["profile"][difficulty]
    return Dict(
        "R_train" => Int(profile["R_train"]),
        "R_val" => Int(profile["R_val"]),
        "R_test" => Int(profile["R_test"]),
        "M" => Int(profile["M"]),
        "tau" => Float64(profile["tau"]),
    )
end

function dnlmat_make_spec(
    system_config::AbstractDict,
    object_id::AbstractString,
    object_kind::AbstractString,
    beta::Real,
    Q::Real,
    profile::AbstractDict,
)
    R = profile["R_train"] + profile["R_val"] + profile["R_test"]
    solver_config = system_config["solver"]
    rotation_config = system_config["discrete_rotation"]
    solver_name = object_kind == "L0" ? String(solver_config["discrete_solver_name"]) : String(solver_config["continuous_solver_name"])
    chi = object_kind == "duffing" ? Float64(beta) * Float64(Q)^2 : 0.0
    return DuffingNLMatrixSpec(
        String(system_config["dataset_id"]),
        String(object_id),
        String(object_kind),
        String(system_config["system_family"]),
        Float64(system_config["alpha"]),
        Float64(system_config["delta"]),
        Float64(beta),
        Float64(system_config["gamma"]),
        Float64(Q),
        chi,
        Float64(rotation_config["damping_radius"]),
        Float64(rotation_config["omega"]),
        Float64(profile["tau"]),
        Int(profile["M"]),
        Int(R),
        Int(profile["R_train"]),
        Int(profile["R_val"]),
        Int(profile["R_test"]),
        Int(system_config["initial_condition_seed"]),
        solver_name,
        Float64(solver_config["reltol"]),
        Float64(solver_config["abstol"]),
        Float64(solver_config["max_internal_step"]),
        Float64(solver_config["energy_tolerance"]),
    )
end

function dnlmat_build_generation_plan(system_config::AbstractDict; difficulty::AbstractString = "formal")
    profile = dnlmat_profile(system_config, difficulty)
    specs = DuffingNLMatrixSpec[]
    base_Q = Float64(system_config["linear_base_Q"])
    push!(
        specs,
        dnlmat_make_spec(
            system_config,
            "dynsys_nlmat__L0_discrete_damped_rotation",
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
            "dynsys_nlmat__L1_continuous_linear_oscillator",
            "L1",
            0.0,
            base_Q,
            profile,
        ),
    )
    for beta in Float64.(system_config["beta_values"]), Q in Float64.(system_config["amplitude_levels_Q"])
        push!(specs, dnlmat_make_spec(system_config, dnlmat_duffing_object_id(beta, Q), "duffing", beta, Q, profile))
    end
    return specs
end

function dnlmat_build_split_roles(split_config::AbstractDict, spec::DuffingNLMatrixSpec)
    counts = split_config["formal_counts"]
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

function dnlmat_split_indices(roles::AbstractVector{<:AbstractString})
    return Dict(role => findall(==(role), roles) for role in ("train", "val", "test"))
end

function dnlmat_window_metadata(spec::DuffingNLMatrixSpec, split_roles::AbstractVector{<:AbstractString}, window_config::AbstractDict)
    split_counts = Dict(role => count(==(role), split_roles) for role in ("train", "val", "test"))
    horizons = Int.(window_config["rollout"]["horizons"])
    rollout_counts = Dict{String,Any}()
    for h in horizons
        1 <= h <= spec.M || throw(ArgumentError("invalid horizon $(h)"))
        rollout_counts[string(h)] = Dict(role => count * (spec.M - h + 1) for (role, count) in split_counts)
    end
    return Dict{String,Any}(
        "one_step" => Dict(
            "lag" => Int(window_config["one_step"]["lag"]),
            "counts" => Dict(role => count * spec.M for (role, count) in split_counts),
        ),
        "rollout" => Dict(
            "horizons" => horizons,
            "counts" => rollout_counts,
            "valid_start_rule" => String(window_config["rollout"]["valid_start_rule"]),
        ),
        "split_convention" => String(window_config["split_convention"]),
    )
end

function dnlmat_trajectory_metadata(spec::DuffingNLMatrixSpec, x0s::AbstractMatrix{<:Real})
    return [
        Dict{String,Any}(
            "trajectory_index" => r,
            "q0" => Float64(x0s[r, 1]),
            "p0" => Float64(x0s[r, 2]),
            "amplitude0" => hypot(Float64(x0s[r, 1]), Float64(x0s[r, 2])),
            "amplitude_level_Q" => spec.amplitude_Q,
        )
        for r in axes(x0s, 1)
    ]
end

function dnlmat_generate_state_tensor(spec::DuffingNLMatrixSpec, x0s::AbstractMatrix{<:Real})
    size(x0s) == (spec.R, 2) || throw(ArgumentError("initial condition matrix must be R by 2"))
    state = Array{Float64}(undef, spec.R, spec.M + 1, 2)
    @threads for r in 1:spec.R
        trajectory = dnlmat_generate_trajectory(spec, view(x0s, r, :))
        @views state[r, :, :] .= trajectory
    end
    return state
end

function dnlmat_energy_diagnostics(spec::DuffingNLMatrixSpec, state::Array{Float64,3})
    if spec.object_kind == "L0"
        amplitudes_initial = [hypot(state[r, 1, 1], state[r, 1, 2]) for r in axes(state, 1)]
        amplitudes_final = [hypot(state[r, end, 1], state[r, end, 2]) for r in axes(state, 1)]
        return Dict(
            "energy_check_type" => "discrete_radius_contraction",
            "final_energy_violation_count" => count(amplitudes_final .> amplitudes_initial .+ spec.energy_tolerance),
            "max_final_energy_excess" => maximum(amplitudes_final .- amplitudes_initial),
            "mean_energy_drop" => mean(amplitudes_initial .- amplitudes_final),
        )
    end
    initial_E = Vector{Float64}(undef, spec.R)
    final_E = Vector{Float64}(undef, spec.R)
    @inbounds for r in 1:spec.R
        initial_E[r] = dnlmat_energy(state[r, 1, 1], state[r, 1, 2], spec.alpha, spec.beta)
        final_E[r] = dnlmat_energy(state[r, end, 1], state[r, end, 2], spec.alpha, spec.beta)
    end
    excess = final_E .- initial_E
    return Dict(
        "energy_check_type" => "duffing_final_le_initial",
        "final_energy_violation_count" => count(excess .> spec.energy_tolerance),
        "max_final_energy_excess" => maximum(excess),
        "mean_energy_drop" => mean(initial_E .- final_E),
        "initial_energy_min" => minimum(initial_E),
        "initial_energy_max" => maximum(initial_E),
        "final_energy_min" => minimum(final_E),
        "final_energy_max" => maximum(final_E),
    )
end

function dnlmat_state_statistics(state::Array{Float64,3})
    q = vec(state[:, :, 1])
    p = vec(state[:, :, 2])
    return Dict(
        "q_min" => minimum(q),
        "q_max" => maximum(q),
        "p_min" => minimum(p),
        "p_max" => maximum(p),
        "q_mean" => mean(q),
        "p_mean" => mean(p),
        "q_std" => std(q),
        "p_std" => std(p),
        "state_abs_max" => maximum(abs, state),
        "nonfinite_count" => count(!isfinite, state),
        "all_finite" => all(isfinite, state),
    )
end

function dnlmat_recurrence_error(spec::DuffingNLMatrixSpec, state::Array{Float64,3})
    if spec.object_kind == "L0"
        F = dnlmat_discrete_rotation_matrix(spec)
    elseif spec.object_kind == "L1" || spec.beta == 0.0
        F = dnlmat_linear_flow_matrix(spec)
    else
        return NaN
    end
    err = 0.0
    @inbounds for r in axes(state, 1), m in 1:spec.M
        q = state[r, m, 1]
        p = state[r, m, 2]
        q_pred = F[1, 1] * q + F[1, 2] * p
        p_pred = F[2, 1] * q + F[2, 2] * p
        err = max(err, abs(q_pred - state[r, m + 1, 1]), abs(p_pred - state[r, m + 1, 2]))
    end
    return err
end

function dnlmat_finalize_diagnostics(
    spec::DuffingNLMatrixSpec,
    state::Array{Float64,3},
    split_roles::AbstractVector{<:AbstractString},
)
    split_counts = Dict(role => count(==(role), split_roles) for role in ("train", "val", "test"))
    state_stats = dnlmat_state_statistics(state)
    energy = dnlmat_energy_diagnostics(spec, state)
    dimensions = Dict(
        "state" => collect(size(state)),
        "obs_phys" => collect(size(state)),
        "obs_full" => collect(size(state)),
        "target_phys" => collect(size(state)),
        "time_grid" => [spec.M + 1],
        "split_roles" => [length(split_roles)],
    )
    shape_passed = size(state) == (spec.R, spec.M + 1, 2)
    split_passed =
        split_counts["train"] == spec.R_train &&
        split_counts["val"] == spec.R_val &&
        split_counts["test"] == spec.R_test
    energy_passed = Int(energy["final_energy_violation_count"]) == 0
    passed = shape_passed && split_passed && state_stats["all_finite"] && state_stats["nonfinite_count"] == 0 && energy_passed
    return Dict{String,Any}(
        "dimensions" => dimensions,
        "split_counts" => split_counts,
        "state_statistics" => state_stats,
        "energy" => energy,
        "linear_recurrence_error_max" => dnlmat_recurrence_error(spec, state),
        "shape_passed" => shape_passed,
        "split_passed" => split_passed,
        "finite_passed" => state_stats["all_finite"] && state_stats["nonfinite_count"] == 0,
        "energy_passed" => energy_passed,
        "passed" => passed,
    )
end

function dnlmat_generate_object(
    spec::DuffingNLMatrixSpec,
    x0s::AbstractMatrix{<:Real},
    split_roles::AbstractVector{<:AbstractString},
    window_config::AbstractDict,
)
    state = dnlmat_generate_state_tensor(spec, x0s)
    trajectory_ids = [string(spec.object_id, "__traj_", lpad(string(r), 4, '0')) for r in 1:spec.R]
    diagnostics = dnlmat_finalize_diagnostics(spec, state, split_roles)
    diagnostics["generation_status"] = diagnostics["passed"] ? "success" : "failed_diagnostics"
    return DuffingNLMatrixObject(
        spec,
        trajectory_ids,
        Matrix{Float64}(x0s),
        dnlmat_trajectory_metadata(spec, x0s),
        dnlmat_time_grid(spec),
        state,
        String.(split_roles),
        dnlmat_window_metadata(spec, split_roles, window_config),
        dnlmat_true_system_metadata(spec),
        diagnostics,
    )
end

function dnlmat_observations(obj::DuffingNLMatrixObject)
    return Dict(
        "obs_phys" => obj.state,
        "obs_full" => obj.state,
        "target_phys" => obj.state,
    )
end

function dnlmat_object_metadata(obj::DuffingNLMatrixObject)
    spec = obj.spec
    split_indices = dnlmat_split_indices(obj.split_roles)
    return Dict{String,Any}(
        "dataset_id" => spec.dataset_id,
        "object_id" => spec.object_id,
        "system_family" => spec.system_family,
        "object_kind" => spec.object_kind,
        "parameter_alpha" => spec.alpha,
        "parameter_delta" => spec.delta,
        "parameter_beta" => spec.beta,
        "parameter_gamma" => spec.gamma,
        "amplitude_level_Q" => spec.amplitude_Q,
        "nonlinearity_index_chi" => spec.chi_nl,
        "forcing_type" => "force_none",
        "state_dimension" => 2,
        "observation_keys" => ["obs_phys", "obs_full"],
        "target_keys" => ["target_phys"],
        "default_observation_key" => "obs_phys",
        "default_target_key" => "target_phys",
        "tau" => spec.tau,
        "trajectory_length" => spec.M,
        "num_snapshots" => spec.M + 1,
        "num_trajectories" => spec.R,
        "split_train" => split_indices["train"],
        "split_val" => split_indices["val"],
        "split_test" => split_indices["test"],
        "split_role_per_trajectory" => obj.split_roles,
        "initial_condition_seed" => spec.initial_condition_seed,
        "solver_name" => spec.solver_name,
        "solver_tolerances" => Dict("reltol" => spec.reltol, "abstol" => spec.abstol),
        "max_internal_step" => spec.max_internal_step,
        "noise_level" => 0.0,
        "true_discrete_matrix" => obj.system_metadata["true_discrete_matrix"],
        "true_continuous_matrix" => obj.system_metadata["true_continuous_matrix"],
        "true_continuous_spectrum" => obj.system_metadata["true_continuous_spectrum"],
        "true_discrete_spectrum" => obj.system_metadata["true_discrete_spectrum"],
        "generation_status" => obj.diagnostics["generation_status"],
        "window_metadata" => obj.window_metadata,
        "array_layout" => "trajectory_by_time_by_channel",
    )
end

function dnlmat_raw_path(project_root::AbstractString, spec::DuffingNLMatrixSpec)
    return joinpath(project_root, "data", "raw", spec.dataset_id, spec.object_id, "raw_trajectories.jld2")
end

function dnlmat_processed_path(project_root::AbstractString, spec::DuffingNLMatrixSpec)
    return joinpath(project_root, "data", "processed", spec.dataset_id, spec.object_id, "processed_tensors.jld2")
end

function dnlmat_manifest_path(project_root::AbstractString, spec::DuffingNLMatrixSpec)
    return joinpath(project_root, "data", "manifests", spec.dataset_id, string(spec.object_id, "_manifest.toml"))
end

function dnlmat_release_root(project_root::AbstractString, release_id::AbstractString)
    return joinpath(project_root, "data", "releases", release_id)
end

function dnlmat_save_raw_object(path::AbstractString, obj::DuffingNLMatrixObject)
    dnlmat_ensure_parent_dir(path)
    JLD2.jldsave(
        path;
        dataset_id = obj.spec.dataset_id,
        object_id = obj.spec.object_id,
        trajectory_ids = obj.trajectory_ids,
        initial_conditions = obj.initial_conditions,
        trajectory_metadata = obj.trajectory_metadata,
        time_grid = obj.time_grid,
        state = obj.state,
        metadata = dnlmat_object_metadata(obj),
        array_layout = "trajectory_by_time_by_channel",
    )
    return path
end

function dnlmat_save_processed_object(path::AbstractString, obj::DuffingNLMatrixObject)
    dnlmat_ensure_parent_dir(path)
    observations = dnlmat_observations(obj)
    JLD2.jldsave(
        path;
        dataset_id = obj.spec.dataset_id,
        object_id = obj.spec.object_id,
        trajectory_ids = obj.trajectory_ids,
        trajectory_metadata = obj.trajectory_metadata,
        time_grid = obj.time_grid,
        state = obj.state,
        obs_phys = observations["obs_phys"],
        obs_full = observations["obs_full"],
        target_phys = observations["target_phys"],
        split_roles = obj.split_roles,
        window_metadata = obj.window_metadata,
        metadata = dnlmat_object_metadata(obj),
        diagnostics = obj.diagnostics,
        array_layout = "trajectory_by_time_by_channel",
    )
    return path
end

function dnlmat_reload_verify(raw_path::AbstractString, processed_path::AbstractString)
    raw = JLD2.load(raw_path)
    processed = JLD2.load(processed_path)
    raw["object_id"] == processed["object_id"] || throw(ArgumentError("raw/processed object_id mismatch"))
    size(raw["state"]) == size(processed["state"]) || throw(ArgumentError("raw/processed state shape mismatch"))
    maximum(abs.(raw["state"] .- processed["state"])) <= 0.0 ||
        throw(ArgumentError("raw/processed state tensors differ"))
    maximum(abs.(processed["obs_phys"] .- processed["state"])) <= 0.0 ||
        throw(ArgumentError("obs_phys does not equal state"))
    maximum(abs.(processed["obs_full"] .- processed["obs_phys"])) <= 0.0 ||
        throw(ArgumentError("obs_full does not equal obs_phys"))
    maximum(abs.(processed["target_phys"] .- processed["state"])) <= 0.0 ||
        throw(ArgumentError("target_phys does not equal state"))
    return true
end

function dnlmat_object_manifest(obj::DuffingNLMatrixObject, raw_path::AbstractString, processed_path::AbstractString)
    metadata = dnlmat_object_metadata(obj)
    return merge(
        metadata,
        Dict{String,Any}(
            "created_at" => string(now()),
            "dimensions" => obj.diagnostics["dimensions"],
            "split_counts" => obj.diagnostics["split_counts"],
            "diagnostics" => obj.diagnostics,
            "data_paths" => Dict("raw_trajectories" => raw_path, "processed_tensors" => processed_path),
            "data_hashes" => Dict(
                "raw_sha256" => dnlmat_file_sha256(raw_path),
                "processed_sha256" => dnlmat_file_sha256(processed_path),
            ),
        ),
    )
end

function dnlmat_write_csv(path::AbstractString, columns::AbstractVector{<:AbstractString}, rows::AbstractVector)
    dnlmat_ensure_parent_dir(path)
    open(path, "w") do io
        println(io, join(columns, ","))
        for row in rows
            println(io, join(dnlmat_csv_value.(row), ","))
        end
    end
    return path
end

function dnlmat_csv_value(value)
    if value isa AbstractString
        return string('"', replace(value, "\"" => "\"\""), '"')
    elseif value isa Bool
        return value ? "true" : "false"
    elseif value isa Real
        return string(value)
    else
        return string('"', replace(string(value), "\"" => "\"\""), '"')
    end
end

function dnlmat_object_summary_row(obj::DuffingNLMatrixObject)
    spec = obj.spec
    stats = obj.diagnostics["state_statistics"]
    energy = obj.diagnostics["energy"]
    split = obj.diagnostics["split_counts"]
    return [
        spec.object_id,
        spec.object_kind,
        spec.beta,
        spec.amplitude_Q,
        spec.chi_nl,
        spec.R,
        spec.M,
        spec.tau,
        split["train"],
        split["val"],
        split["test"],
        stats["q_min"],
        stats["q_max"],
        stats["p_min"],
        stats["p_max"],
        stats["state_abs_max"],
        energy["final_energy_violation_count"],
        energy["max_final_energy_excess"],
        energy["mean_energy_drop"],
        obj.diagnostics["linear_recurrence_error_max"],
        obj.diagnostics["passed"],
    ]
end

function dnlmat_window_count_rows(obj::DuffingNLMatrixObject)
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

function dnlmat_write_report_tables(
    project_root::AbstractString,
    release_id::AbstractString,
    objects::AbstractVector{DuffingNLMatrixObject},
)
    table_root = joinpath(project_root, "reports", "v1_core", release_id, "tables")
    object_summary_path = joinpath(table_root, "$(release_id)_object_summary.csv")
    window_counts_path = joinpath(table_root, "$(release_id)_window_counts.csv")
    matrix_summary_path = joinpath(table_root, "$(release_id)_duffing_matrix_summary.csv")
    dnlmat_write_csv(
        object_summary_path,
        [
            "object_id",
            "object_kind",
            "beta",
            "Q",
            "chi_nl",
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
            "final_energy_violation_count",
            "max_final_energy_excess",
            "mean_energy_drop",
            "linear_recurrence_error_max",
            "passed",
        ],
        [dnlmat_object_summary_row(obj) for obj in objects],
    )
    dnlmat_write_csv(
        window_counts_path,
        ["object_id", "window_type", "horizon", "split", "count"],
        reduce(vcat, [dnlmat_window_count_rows(obj) for obj in objects]),
    )
    duffing_objects = [obj for obj in objects if obj.spec.object_kind == "duffing"]
    dnlmat_write_csv(
        matrix_summary_path,
        [
            "object_id",
            "beta",
            "Q",
            "chi_nl",
            "q_min",
            "q_max",
            "p_min",
            "p_max",
            "state_abs_max",
            "mean_energy_drop",
            "passed",
        ],
        [
            [
                obj.spec.object_id,
                obj.spec.beta,
                obj.spec.amplitude_Q,
                obj.spec.chi_nl,
                obj.diagnostics["state_statistics"]["q_min"],
                obj.diagnostics["state_statistics"]["q_max"],
                obj.diagnostics["state_statistics"]["p_min"],
                obj.diagnostics["state_statistics"]["p_max"],
                obj.diagnostics["state_statistics"]["state_abs_max"],
                obj.diagnostics["energy"]["mean_energy_drop"],
                obj.diagnostics["passed"],
            ]
            for obj in duffing_objects
        ],
    )
    return Dict(
        "object_summary" => object_summary_path,
        "window_counts" => window_counts_path,
        "matrix_summary" => matrix_summary_path,
    )
end

function dnlmat_write_generation_log(
    project_root::AbstractString,
    release_id::AbstractString,
    objects::AbstractVector{DuffingNLMatrixObject},
    output_paths::AbstractDict,
)
    log_path = joinpath(project_root, "reports", "v1_core", release_id, "logs", "$(release_id)_generation.log")
    dnlmat_ensure_parent_dir(log_path)
    open(log_path, "w") do io
        println(io, "release_id: ", release_id)
        println(io, "created_at: ", now())
        println(io, "thread_count: ", nthreads())
        println(io, "object_count: ", length(objects))
        println(io, "duffing_cell_count: ", count(obj -> obj.spec.object_kind == "duffing", objects))
        println(io, "all_passed: ", all(obj -> obj.diagnostics["passed"], objects))
        println(io, "release_manifest: ", output_paths["release_manifest"])
        println(io, "release_index: ", output_paths["release_index"])
        println(io, "checksums: ", output_paths["checksums"])
        for obj in objects
            stats = obj.diagnostics["state_statistics"]
            energy = obj.diagnostics["energy"]
            split = obj.diagnostics["split_counts"]
            println(
                io,
                obj.spec.object_id,
                " | kind=", obj.spec.object_kind,
                " | beta=", obj.spec.beta,
                " | Q=", obj.spec.amplitude_Q,
                " | chi=", obj.spec.chi_nl,
                " | shape=", size(obj.state),
                " | split=", split,
                " | state_abs_max=", stats["state_abs_max"],
                " | energy_violations=", energy["final_energy_violation_count"],
                " | passed=", obj.diagnostics["passed"],
            )
        end
    end
    return log_path
end

function dnlmat_release_manifest(
    release_id::AbstractString,
    object_manifests::AbstractVector{<:AbstractDict},
    output_paths::AbstractDict,
    config_hashes::AbstractDict,
    initial_condition_checks::AbstractDict,
)
    return Dict{String,Any}(
        "release_id" => String(release_id),
        "dataset_id" => String(release_id),
        "release_version" => "1.0.0",
        "created_at" => string(now()),
        "scope" => "v1_core",
        "object_count" => length(object_manifests),
        "duffing_cell_count" => count(manifest -> manifest["object_kind"] == "duffing", object_manifests),
        "object_ids" => [manifest["object_id"] for manifest in object_manifests],
        "beta_values" => sort(unique([manifest["parameter_beta"] for manifest in object_manifests if manifest["object_kind"] == "duffing"])),
        "amplitude_levels_Q" => sort(unique([manifest["amplitude_level_Q"] for manifest in object_manifests if manifest["object_kind"] == "duffing"])),
        "forcing_type" => "force_none",
        "split_protocol" => "duffing_nonlinearity_matrix_v1_split_trajectory_I",
        "storage_format" => "JLD2 tensors plus TOML manifests",
        "initial_condition_checks" => initial_condition_checks,
        "paths" => output_paths,
        "config_hashes" => config_hashes,
        "objects" => object_manifests,
    )
end

function dnlmat_write_checksums(path::AbstractString, path_groups::AbstractDict)
    checksums = Dict{String,Any}()
    for (group, paths) in path_groups
        if paths isa AbstractDict
            checksums[String(group)] = Dict(String(k) => dnlmat_file_sha256(v) for (k, v) in paths)
        else
            checksums[String(group)] = dnlmat_file_sha256(paths)
        end
    end
    dnlmat_write_toml(path, checksums)
    return checksums
end

function dnlmat_initial_condition_libraries(system_config::AbstractDict, specs::AbstractVector{DuffingNLMatrixSpec})
    unique_Q = sort(unique([spec.amplitude_Q for spec in specs]))
    libraries = Dict{Float64,Matrix{Float64}}()
    stats = Dict{String,Any}()
    R = first(specs).R
    seed = Int(system_config["initial_condition_seed"])
    for Q in unique_Q
        x0s, Q_stats = dnlmat_sample_initial_conditions(Q, R, seed)
        libraries[Q] = x0s
        stats[string(Q)] = Q_stats
    end
    return libraries, stats
end

function dnlmat_initial_condition_reuse_checks(objects::AbstractVector{DuffingNLMatrixObject})
    checks = Dict{String,Any}()
    duffing_objects = [obj for obj in objects if obj.spec.object_kind == "duffing"]
    for Q in sort(unique(obj.spec.amplitude_Q for obj in duffing_objects))
        Q_objects = [obj for obj in duffing_objects if obj.spec.amplitude_Q == Q]
        reference = first(Q_objects).initial_conditions
        maxdiff = maximum(maximum(abs.(obj.initial_conditions .- reference)) for obj in Q_objects)
        checks[string(Q)] = Dict(
            "object_count" => length(Q_objects),
            "max_initial_condition_difference_across_beta" => maxdiff,
            "passed" => maxdiff <= 0.0,
        )
    end
    return checks
end

function dnlmat_run_release_generation(project_root::AbstractString; difficulty::AbstractString = "formal")
    configs = dnlmat_load_generation_configs(project_root)
    specs = dnlmat_build_generation_plan(configs["systems"]; difficulty = difficulty)
    reference_spec = first(specs)
    split_roles, split_counts = dnlmat_build_split_roles(configs["splits"], reference_spec)
    x0_libraries, x0_stats = dnlmat_initial_condition_libraries(configs["systems"], specs)

    objects = DuffingNLMatrixObject[]
    object_manifests = Dict{String,Any}[]
    raw_paths = Dict{String,String}()
    processed_paths = Dict{String,String}()
    manifest_paths = Dict{String,String}()

    @printf("release_id: %s\n", dnlmat_release_id())
    @printf("objects: %d (%d Duffing cells), split=%d/%d/%d, threads=%d\n",
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

    release_id = dnlmat_release_id()
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
    release_manifest = dnlmat_release_manifest(
        release_id,
        object_manifests,
        output_paths,
        dnlmat_config_hashes(project_root),
        Dict("libraries" => x0_stats, "reuse_checks" => initial_condition_checks),
    )
    dnlmat_write_toml(release_manifest_path, release_manifest)
    release_index = Dict{String,Any}(
        "release_id" => release_id,
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

function dnlmat_print_release_summary(result::AbstractDict)
    objects = result["objects"]
    output_paths = result["output_paths"]
    duffing_objects = [obj for obj in objects if obj.spec.object_kind == "duffing"]
    @printf("release_id: %s\n", dnlmat_release_id())
    @printf("object_count: %d\n", length(objects))
    @printf("duffing_cell_count: %d\n", length(duffing_objects))
    @printf("all_passed: %s\n", string(all(obj -> obj.diagnostics["passed"], objects)))
    @printf("initial_condition_reuse_passed: %s\n", string(all(check["passed"] for (_, check) in result["initial_condition_checks"])))
    @printf("chi_range: [%.6g, %.6g]\n", minimum(obj.spec.chi_nl for obj in duffing_objects), maximum(obj.spec.chi_nl for obj in duffing_objects))
    @printf("release_manifest: %s\n", output_paths["release_manifest"])
    @printf("release_index: %s\n", output_paths["release_index"])
    @printf("checksums: %s\n", output_paths["checksums"])
    @printf("object_summary: %s\n", output_paths["report_tables"]["object_summary"])
    @printf("matrix_summary: %s\n", output_paths["report_tables"]["matrix_summary"])
    @printf("log: %s\n", output_paths["log"])
end
