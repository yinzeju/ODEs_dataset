## High-dimensional uncoupled linear baseline generation

using Dates
using JSON
using JLD2
using LinearAlgebra
using Printf
using Random
using Statistics

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const HIGH_DIMENSIONS = (4, 8, 16)

## Shared file and configuration helpers

project_path(parts...) = joinpath(PROJECT_ROOT, parts...)

function project_path_from_string(relative_path::AbstractString)
    return joinpath(PROJECT_ROOT, split(relative_path, '/')...)
end

function load_config(parts...)
    return JSON.parsefile(project_path("configs", parts...))
end

function ensure_parent_dir(path::AbstractString)
    mkpath(dirname(path))
    return path
end

function write_json_file(path::AbstractString, object)
    ensure_parent_dir(path)
    open(path, "w") do io
        JSON.print(io, object, 2)
        write(io, "\n")
    end
    return path
end

function repeat_to_length(values::AbstractVector, n::Integer)
    n % length(values) == 0 ||
        throw(ArgumentError("target dimension must be a multiple of the baseline value count"))
    return Float64.(repeat(collect(values), n ÷ length(values)))
end

function block_diagonal_repeat(block::AbstractMatrix{<:Real}, count::Integer)
    count >= 1 || throw(ArgumentError("block count must be positive"))
    dblock = size(block, 1)
    size(block, 2) == dblock || throw(ArgumentError("block must be square"))
    matrix = zeros(Float64, dblock * count, dblock * count)
    for k in 1:count
        rows = ((k - 1) * dblock + 1):(k * dblock)
        matrix[rows, rows] .= block
    end
    return matrix
end

function matrix_rows(matrix::AbstractMatrix)
    return [Vector{Float64}(matrix[i, :]) for i in axes(matrix, 1)]
end

function complex_metadata(z::Complex)
    return Dict(
        "real" => real(z),
        "imag" => imag(z),
        "abs" => abs(z),
        "angle" => angle(z),
    )
end

function spectrum_metadata(values::AbstractVector{<:Complex})
    return [complex_metadata(z) for z in values]
end

## Split and window summaries

function split_counts(n::Integer, ratios::NTuple{3,Float64})
    raw = collect(Float64(n) .* ratios)
    counts = floor.(Int, raw)
    remainder = n - sum(counts)
    fractions = raw .- counts
    for _ in 1:remainder
        index = argmax(fractions)
        counts[index] += 1
        fractions[index] = -Inf
    end
    return counts
end

function build_trajectory_split(trajectory_ids::AbstractVector{String}, split_config::AbstractDict)
    ratios = (
        Float64(split_config["train_ratio"]),
        Float64(split_config["val_ratio"]),
        Float64(split_config["test_ratio"]),
    )
    abs(sum(ratios) - 1.0) <= 1e-12 || throw(ArgumentError("split ratios must sum to 1"))

    shuffled = copy(trajectory_ids)
    shuffle!(MersenneTwister(Int(split_config["seed"])), shuffled)
    n_train, n_val, n_test = split_counts(length(shuffled), ratios)

    split = Dict(
        "split_id" => String(split_config["split_id"]),
        "split_type" => String(split_config["split_type"]),
        "grouping_unit" => String(get(split_config, "grouping_unit", "trajectory")),
        "seed" => Int(split_config["seed"]),
        "train_ratio" => ratios[1],
        "val_ratio" => ratios[2],
        "test_ratio" => ratios[3],
        "train_trajectory_ids" => shuffled[1:n_train],
        "val_trajectory_ids" => shuffled[(n_train + 1):(n_train + n_val)],
        "test_trajectory_ids" => shuffled[(n_train + n_val + 1):(n_train + n_val + n_test)],
    )

    all_ids = Set(trajectory_ids)
    split_union = union(
        Set(split["train_trajectory_ids"]),
        Set(split["val_trajectory_ids"]),
        Set(split["test_trajectory_ids"]),
    )
    split_union == all_ids || throw(ArgumentError("split does not cover all trajectories"))
    return split
end

function split_count_summary(split::AbstractDict)
    return Dict(
        "train" => length(split["train_trajectory_ids"]),
        "val" => length(split["val_trajectory_ids"]),
        "test" => length(split["test_trajectory_ids"]),
    )
end

function one_step_window_summary(split::AbstractDict, trajectory_length::Integer; window_id::AbstractString, lag::Integer)
    lag == 1 || throw(ArgumentError("high-dimensional generation currently expects lag 1"))
    counts = Dict(
        "train" => length(split["train_trajectory_ids"]) * trajectory_length,
        "val" => length(split["val_trajectory_ids"]) * trajectory_length,
        "test" => length(split["test_trajectory_ids"]) * trajectory_length,
    )
    return Dict(
        "window_id" => String(window_id),
        "window_type" => "one_step",
        "lag" => Int(lag),
        "samples_per_trajectory" => Int(trajectory_length),
        "counts" => counts,
    )
end

function rollout_window_summary(split::AbstractDict, trajectory_length::Integer, horizons::AbstractVector{<:Integer}; window_id::AbstractString)
    by_horizon = Dict{String,Any}()
    for horizon in horizons
        horizon <= trajectory_length ||
            throw(ArgumentError("rollout horizon cannot exceed trajectory length"))
        starts = trajectory_length + 1 - horizon
        by_horizon[string("h", horizon)] = Dict(
            "window_id" => string(window_id, "_h", horizon),
            "horizon" => Int(horizon),
            "starts_per_trajectory" => Int(starts),
            "counts" => Dict(
                "train" => length(split["train_trajectory_ids"]) * starts,
                "val" => length(split["val_trajectory_ids"]) * starts,
                "test" => length(split["test_trajectory_ids"]) * starts,
            ),
        )
    end
    return Dict(
        "window_id" => String(window_id),
        "window_type" => "rollout",
        "horizons" => Int.(horizons),
        "by_horizon" => by_horizon,
    )
end

## Initial-condition sampling

function sample_box_min_abs(rng::AbstractRNG, state_dim::Integer, domain::AbstractDict)
    lower = Float64(domain["lower"])
    upper = Float64(domain["upper"])
    min_abs = Float64(domain["min_abs"])
    for _ in 1:10_000
        x0 = lower .+ (upper - lower) .* rand(rng, state_dim)
        minimum(abs.(x0)) >= min_abs && return Vector{Float64}(x0)
    end
    throw(ArgumentError("failed to sample box initial condition with min_abs"))
end

function sample_repeated_polar_annulus(rng::AbstractRNG, state_dim::Integer, domain::AbstractDict)
    state_dim % 2 == 0 || throw(ArgumentError("rotation-contraction dimension must be even"))
    x0 = Vector{Float64}(undef, state_dim)
    for block in 1:(state_dim ÷ 2)
        radius = Float64(domain["radius_lower"]) +
            (Float64(domain["radius_upper"]) - Float64(domain["radius_lower"])) * rand(rng)
        angle = Float64(domain["angle_lower"]) +
            (Float64(domain["angle_upper"]) - Float64(domain["angle_lower"])) * rand(rng)
        idx = 2block - 1
        x0[idx] = radius * cos(angle)
        x0[idx + 1] = radius * sin(angle)
    end
    return x0
end

function sample_repeated_oscillator_box(rng::AbstractRNG, state_dim::Integer, domain::AbstractDict)
    state_dim % 2 == 0 || throw(ArgumentError("oscillator dimension must be even"))
    lower = Float64.(domain["lower"])
    upper = Float64.(domain["upper"])
    min_norm = Float64(domain["min_norm"])
    length(lower) == 2 && length(upper) == 2 ||
        throw(ArgumentError("baseline oscillator box must have two bounds"))

    x0 = Vector{Float64}(undef, state_dim)
    for block in 1:(state_dim ÷ 2)
        for _ in 1:10_000
            pair = lower .+ (upper .- lower) .* rand(rng, 2)
            if norm(pair) >= min_norm
                idx = 2block - 1
                x0[idx] = pair[1]
                x0[idx + 1] = pair[2]
                break
            end
        end
    end
    return x0
end

## Exact uncoupled linear trajectory generation

function linear_times(dt::Real, trajectory_length::Integer)
    return collect(range(0.0; step = Float64(dt), length = trajectory_length + 1))
end

function generate_discrete_linear_trajectory(F::AbstractMatrix{<:Real}, x0::AbstractVector{<:Real}, trajectory_length::Integer)
    state_dim = length(x0)
    X = Matrix{Float64}(undef, state_dim, trajectory_length + 1)
    X[:, 1] = Float64.(x0)
    @inbounds for m in 1:trajectory_length
        X[:, m + 1] = F * X[:, m]
    end
    return X
end

function generate_diagonal_trajectory(eigenvalues::AbstractVector{<:Real}, dt::Real, x0::AbstractVector{<:Real}, trajectory_length::Integer)
    times = linear_times(dt, trajectory_length)
    X = Matrix{Float64}(undef, length(x0), trajectory_length + 1)
    @inbounds for (m, t) in enumerate(times)
        X[:, m] = Float64.(x0) .* exp.(Float64.(eigenvalues) .* t)
    end
    return X
end

function trajectory_tensor(trajectories::AbstractVector{<:AbstractMatrix})
    first_matrix = first(trajectories)
    tensor = Array{Float64}(undef, size(first_matrix, 1), size(first_matrix, 2), length(trajectories))
    for (q, X) in enumerate(trajectories)
        tensor[:, :, q] = X
    end
    return tensor
end

## System-specific lifted configurations

function diagonal_highdim_config(base_config::AbstractDict, state_dim::Integer)
    config = deepcopy(base_config)
    eigenvalues = repeat_to_length(base_config["default_parameters"]["eigenvalues"], state_dim)
    config["state_dim"] = Int(state_dim)
    config["variant"] = string("uncoupled_d", state_dim)
    config["parameter_names"] = [string("lambda_", i) for i in 1:state_dim]
    config["parameter_domain"] = Dict("eigenvalues" => eigenvalues)
    config["default_parameters"] = Dict("eigenvalues" => eigenvalues)
    config["difficulty_level"] = string("uncoupled_d", state_dim)
    config["dimension_lift_policy"] = Dict(
        "type" => "repeat_baseline_diagonal_spectrum",
        "baseline_state_dim" => length(base_config["default_parameters"]["eigenvalues"]),
        "no_coupling" => true,
    )
    return config
end

function rotation_highdim_config(base_config::AbstractDict, state_dim::Integer)
    state_dim % 2 == 0 || throw(ArgumentError("rotation-contraction dimension must be even"))
    config = deepcopy(base_config)
    config["system_id"] = "linear_rotation_contraction_uncoupled"
    config["state_dim"] = Int(state_dim)
    config["variant"] = string("uncoupled_d", state_dim)
    config["difficulty_level"] = string("uncoupled_d", state_dim)
    config["block_count"] = state_dim ÷ 2
    config["dimension_lift_policy"] = Dict(
        "type" => "repeat_independent_rotation_contraction_2d_blocks",
        "baseline_system_id" => base_config["system_id"],
        "baseline_state_dim" => base_config["state_dim"],
        "no_coupling" => true,
    )
    return config
end

function oscillator_highdim_config(base_config::AbstractDict, state_dim::Integer)
    state_dim % 2 == 0 || throw(ArgumentError("oscillator dimension must be even"))
    config = deepcopy(base_config)
    config["state_dim"] = Int(state_dim)
    config["variant"] = string("uncoupled_d", state_dim)
    config["block_count"] = state_dim ÷ 2
    config["dimension_lift_policy"] = Dict(
        "type" => "repeat_independent_linear_oscillator_2d_blocks",
        "baseline_variant" => base_config["variant"],
        "baseline_state_dim" => base_config["state_dim"],
        "no_coupling" => true,
    )
    return config
end

function observation_config(base_config::AbstractDict, state_dim::Integer; observation_id::AbstractString)
    config = deepcopy(base_config)
    config["observation_id"] = String(observation_id)
    config["output_dim"] = Int(state_dim)
    config["dimension_lift_policy"] = Dict(
        "type" => "full_state_identity_same_dimension",
        "no_projection" => true,
        "no_noise" => true,
    )
    return config
end

## Matrix builders and metadata

function diagonal_matrices(system_config::AbstractDict)
    eigenvalues = Float64.(system_config["default_parameters"]["eigenvalues"])
    F = Diagonal(exp.(eigenvalues .* Float64(system_config["dt"])))
    A = Diagonal(eigenvalues)
    return Matrix(A), Matrix(F), ComplexF64.(eigenvalues), ComplexF64.(diag(F))
end

function rotation_matrices(system_config::AbstractDict)
    params = system_config["default_parameters"]
    gamma = Float64(params["gamma"])
    omega = Float64(params["omega"])
    dt = Float64(system_config["dt"])
    block_count = Int(system_config["block_count"])
    Ablock = [-gamma -omega; omega -gamma]
    rho = exp(-gamma * dt)
    theta = omega * dt
    Fblock = rho .* [cos(theta) -sin(theta); sin(theta) cos(theta)]
    continuous = repeat(ComplexF64[-gamma + im * omega, -gamma - im * omega], block_count)
    discrete = exp.(continuous .* dt)
    return block_diagonal_repeat(Ablock, block_count), block_diagonal_repeat(Fblock, block_count), continuous, discrete
end

function oscillator_matrices(system_config::AbstractDict)
    params = system_config["default_parameters"]
    gamma = Float64(params["gamma"])
    omega0 = Float64(params["omega0"])
    dt = Float64(system_config["dt"])
    block_count = Int(system_config["block_count"])
    omega_d = sqrt(omega0^2 - gamma^2)
    theta = omega_d * dt
    c = cos(theta)
    s = sin(theta)
    damping = exp(-gamma * dt)
    Ablock = [0.0 1.0; -(omega0^2) -2.0 * gamma]
    Fblock = damping .* [
        c + (gamma / omega_d) * s s / omega_d
        -(omega0^2 / omega_d) * s c - (gamma / omega_d) * s
    ]
    continuous = repeat(ComplexF64[-gamma + im * omega_d, -gamma - im * omega_d], block_count)
    discrete = exp.(continuous .* dt)
    return block_diagonal_repeat(Ablock, block_count), block_diagonal_repeat(Fblock, block_count), continuous, discrete
end

## Diagnostics

function max_one_step_residual(F::AbstractMatrix{<:Real}, trajectories::AbstractVector{<:AbstractMatrix})
    residual = 0.0
    for X in trajectories
        @inbounds for m in 1:(size(X, 2) - 1)
            residual = max(residual, norm(X[:, m + 1] - F * X[:, m]))
        end
    end
    return residual
end

function sampled_rollout_residual(
    F::AbstractMatrix{<:Real},
    trajectories::AbstractVector{<:AbstractMatrix},
    horizons::AbstractVector{<:Integer};
    max_starts_per_trajectory::Integer = 8,
)
    trajectory_length = size(first(trajectories), 2) - 1
    by_horizon = Dict{String,Any}()
    global_max = 0.0

    for horizon in horizons
        max_start = trajectory_length + 1 - horizon
        starts = unique(round.(Int, range(1, max_start; length = min(max_starts_per_trajectory, max_start))))
        Fh = Matrix{Float64}(I, size(F, 1), size(F, 2))
        residuals = Float64[]
        for ell in 1:horizon
            Fh = F * Fh
            for X in trajectories
                for s in starts
                    push!(residuals, norm(X[:, s + ell] - Fh * X[:, s]))
                end
            end
        end
        residual_max = maximum(residuals)
        global_max = max(global_max, residual_max)
        by_horizon[string("h", horizon)] = Dict(
            "rollout_horizon" => Int(horizon),
            "rollout_residual_mean" => mean(residuals),
            "rollout_residual_max" => residual_max,
            "sampled_starts_per_trajectory" => length(starts),
        )
    end

    return Dict("rollout_residual_max" => global_max, "by_horizon" => by_horizon)
end

function spectrum_abs_error_max(F::AbstractMatrix{<:Real}, truth::AbstractVector{<:Complex})
    observed = eigvals(F)
    return maximum(minimum(abs.(z .- truth)) for z in observed)
end

function diagonal_analytic_error(
    eigenvalues::AbstractVector{<:Real},
    dt::Real,
    trajectories::AbstractVector{<:AbstractMatrix},
    initial_conditions::AbstractMatrix,
)
    trajectory_length = size(first(trajectories), 2) - 1
    times = linear_times(dt, trajectory_length)
    error = 0.0
    for (q, X) in enumerate(trajectories)
        for (m, t) in enumerate(times)
            xtrue = initial_conditions[:, q] .* exp.(Float64.(eigenvalues) .* t)
            error = max(error, maximum(abs.(X[:, m] .- xtrue)))
        end
    end
    return error
end

function rotation_block_diagnostics(system_config::AbstractDict, trajectories::AbstractVector{<:AbstractMatrix})
    gamma = Float64(system_config["default_parameters"]["gamma"])
    omega = Float64(system_config["default_parameters"]["omega"])
    dt = Float64(system_config["dt"])
    rho_true = exp(-gamma * dt)
    theta_true = omega * dt
    rho_errors = Float64[]
    theta_errors = Float64[]

    for X in trajectories
        for block in 1:(size(X, 1) ÷ 2)
            idx = 2block - 1
            for m in 1:(size(X, 2) - 1)
                z0 = complex(X[idx, m], X[idx + 1, m])
                z1 = complex(X[idx, m + 1], X[idx + 1, m + 1])
                ratio = z1 / z0
                push!(rho_errors, abs(abs(ratio) - rho_true))
                push!(theta_errors, abs(angle(ratio) - theta_true))
            end
        end
    end

    return Dict(
        "rho_true" => rho_true,
        "rho_empirical_max_abs_error" => maximum(rho_errors),
        "theta_step_true" => theta_true,
        "theta_step_max_abs_error" => maximum(theta_errors),
    )
end

function oscillator_energy_series(system_config::AbstractDict, X::AbstractMatrix)
    omega0 = Float64(system_config["default_parameters"]["omega0"])
    energies = Vector{Float64}(undef, size(X, 2))
    for m in axes(X, 2)
        total = 0.0
        for block in 1:(size(X, 1) ÷ 2)
            idx = 2block - 1
            q = X[idx, m]
            v = X[idx + 1, m]
            total += 0.5 * v^2 + 0.5 * omega0^2 * q^2
        end
        energies[m] = total
    end
    return energies
end

function oscillator_energy_diagnostics(system_config::AbstractDict, trajectories::AbstractVector{<:AbstractMatrix})
    step_increase = Float64[]
    final_ratios = Float64[]
    for X in trajectories
        energies = oscillator_energy_series(system_config, X)
        push!(step_increase, maximum(diff(energies)))
        push!(final_ratios, last(energies) / max(first(energies), eps(Float64)))
    end
    return Dict(
        "energy_step_increase_max" => maximum(step_increase),
        "energy_final_ratio_mean" => mean(final_ratios),
        "energy_final_ratio_max" => maximum(final_ratios),
    )
end

function diagnostics_for_dataset(
    system_kind::AbstractString,
    system_config::AbstractDict,
    F::AbstractMatrix{<:Real},
    discrete_spectrum::AbstractVector{<:Complex},
    trajectories::AbstractVector{<:AbstractMatrix},
    initial_conditions::AbstractMatrix,
    rollout_horizons::AbstractVector{<:Integer},
)
    diagnostics = Dict{String,Any}(
        "system_kind" => String(system_kind),
        "system_id" => system_config["system_id"],
        "variant" => system_config["variant"],
        "family" => system_config["family"],
        "state_dim" => Int(system_config["state_dim"]),
        "num_trajectories" => length(trajectories),
        "trajectory_length" => Int(system_config["trajectory_length"]),
        "state_matrix_size" => collect(size(first(trajectories))),
        "array_layout" => "state_dim_by_time_by_trajectory",
        "full_state_observation_error_max" => 0.0,
        "max_abs_state" => maximum(maximum(abs.(X)) for X in trajectories),
        "max_one_step_residual" => max_one_step_residual(F, trajectories),
        "spectrum_abs_error_max" => spectrum_abs_error_max(F, discrete_spectrum),
    )
    merge!(diagnostics, sampled_rollout_residual(F, trajectories, rollout_horizons))

    if system_kind == "linear_diagonal"
        eigenvalues = Float64.(system_config["default_parameters"]["eigenvalues"])
        diagnostics["max_analytic_error"] = diagonal_analytic_error(
            eigenvalues,
            Float64(system_config["dt"]),
            trajectories,
            initial_conditions,
        )
        diagnostics["passed"] = diagnostics["max_one_step_residual"] <= 1e-10 &&
            diagnostics["max_analytic_error"] <= 1e-10 &&
            diagnostics["spectrum_abs_error_max"] <= 1e-10
    elseif system_kind == "linear_rotation_contraction"
        merge!(diagnostics, rotation_block_diagnostics(system_config, trajectories))
        diagnostics["passed"] = diagnostics["max_one_step_residual"] <= 1e-10 &&
            diagnostics["rollout_residual_max"] <= 1e-10 &&
            diagnostics["rho_empirical_max_abs_error"] <= 1e-10 &&
            diagnostics["theta_step_max_abs_error"] <= 1e-10 &&
            diagnostics["spectrum_abs_error_max"] <= 1e-10
    elseif system_kind == "linear_oscillator"
        merge!(diagnostics, oscillator_energy_diagnostics(system_config, trajectories))
        diagnostics["passed"] = diagnostics["max_one_step_residual"] <= 1e-10 &&
            diagnostics["rollout_residual_max"] <= 1e-10 &&
            diagnostics["energy_step_increase_max"] <= 1e-10 &&
            diagnostics["energy_final_ratio_max"] < 1.0 &&
            diagnostics["spectrum_abs_error_max"] <= 1e-10
    else
        throw(ArgumentError("unknown system kind: $(system_kind)"))
    end

    return diagnostics
end

## Dataset saving

function save_dataset_tensors(;
    raw_path::AbstractString,
    processed_path::AbstractString,
    trajectory_ids::AbstractVector{String},
    system_config::AbstractDict,
    observation_config::AbstractDict,
    parameter_instances::AbstractVector,
    initial_conditions::AbstractMatrix,
    times::AbstractVector,
    trajectories::AbstractVector{<:AbstractMatrix},
)
    state_tensor = trajectory_tensor(trajectories)
    ensure_parent_dir(raw_path)
    JLD2.jldsave(
        raw_path;
        trajectory_ids = trajectory_ids,
        system_id = system_config["system_id"],
        family = system_config["family"],
        variant = system_config["variant"],
        parameter_instances = parameter_instances,
        initial_conditions = initial_conditions,
        times = times,
        state_tensor = state_tensor,
        array_layout = "state_dim_by_time_by_trajectory",
    )

    ensure_parent_dir(processed_path)
    JLD2.jldsave(
        processed_path;
        trajectory_ids = trajectory_ids,
        system_id = system_config["system_id"],
        family = system_config["family"],
        variant = system_config["variant"],
        observation_id = observation_config["observation_id"],
        parameter_instances = parameter_instances,
        initial_conditions = initial_conditions,
        times = times,
        state_tensor = state_tensor,
        observation_tensor = copy(state_tensor),
        array_layout = "state_dim_by_time_by_trajectory",
    )
    return raw_path, processed_path
end

function diagnostics_csv_row(system_kind::AbstractString, diagnostics::AbstractDict)
    columns = [
        "system_kind",
        "system_id",
        "variant",
        "state_dim",
        "num_trajectories",
        "trajectory_length",
        "max_one_step_residual",
        "rollout_residual_max",
        "spectrum_abs_error_max",
        "full_state_observation_error_max",
        "max_abs_state",
        "passed",
    ]
    values = [diagnostics[column] for column in columns]
    return columns, values
end

function csv_value(value)
    value isa AbstractString ? string('"', replace(value, "\"" => "\"\""), '"') : string(value)
end

function write_single_row_csv(path::AbstractString, columns::AbstractVector, values::AbstractVector)
    ensure_parent_dir(path)
    open(path, "w") do io
        println(io, join(columns, ","))
        println(io, join(csv_value.(values), ","))
    end
    return path
end

function write_generation_log(path::AbstractString, manifest::AbstractDict)
    ensure_parent_dir(path)
    open(path, "w") do io
        println(io, "benchmark_id: ", manifest["benchmark_id"])
        println(io, "system_id: ", manifest["system_id"])
        println(io, "variant: ", manifest["variant"])
        println(io, "state_dim: ", manifest["state_dim"])
        println(io, "num_trajectories: ", manifest["num_trajectories"])
        println(io, "trajectory_length: ", manifest["trajectory_length"])
        println(io, "split_counts: ", manifest["split_counts"])
        println(io, "one_step_window_counts: ", manifest["window_summary"]["one_step"]["counts"])
        println(io, "rollout_window_counts: ", manifest["window_summary"]["rollout"]["by_horizon"])
        println(io, "diagnostics: ", manifest["diagnostics"])
        println(io, "raw_path: ", manifest["generated_files"]["raw_trajectories"])
        println(io, "processed_path: ", manifest["generated_files"]["processed_trajectories"])
        println(io, "manifest_path: ", manifest["generated_files"]["manifest"])
    end
    return path
end

## Dataset orchestration

function output_paths_for(system_config::AbstractDict, observation_config::AbstractDict)
    family = String(system_config["family"])
    system_id = String(system_config["system_id"])
    variant = String(system_config["variant"])
    observation_id = String(observation_config["observation_id"])
    report_scope = family == "v1_core" ? "v1_core" : family
    report_task = string(system_id, "_", variant)

    return Dict(
        "raw_path" => project_path("data", "raw", family, system_id, variant, "raw_trajectories.jld2"),
        "processed_path" => project_path("data", "processed", family, system_id, observation_id, variant, "observed_trajectories.jld2"),
        "split_path" => project_path("data", "processed", family, system_id, observation_id, variant, "splits.json"),
        "windows_summary_path" => project_path("data", "processed", family, system_id, observation_id, variant, "windows_summary.json"),
        "manifest_path" => project_path("data", "manifests", family, system_id, variant, "manifest.json"),
        "release_index_path" => project_path("data", "releases", family, system_id, variant, "release_index.json"),
        "table_path" => project_path("reports", report_scope, report_task, "tables", "diagnostics.csv"),
        "log_path" => project_path("reports", report_scope, report_task, "logs", "generation.log"),
    )
end

function build_window_summary(split::AbstractDict, trajectory_length::Integer, one_step_config::AbstractDict, rollout_horizons::AbstractVector{<:Integer}; rollout_window_id::AbstractString)
    return Dict(
        "one_step" => one_step_window_summary(
            split,
            trajectory_length;
            window_id = one_step_config["window_id"],
            lag = Int(one_step_config["lag"]),
        ),
        "rollout" => rollout_window_summary(
            split,
            trajectory_length,
            rollout_horizons;
            window_id = rollout_window_id,
        ),
    )
end

function make_manifest(;
    benchmark_id::AbstractString,
    release_version::AbstractString,
    system_kind::AbstractString,
    system_config::AbstractDict,
    observation_config::AbstractDict,
    split::AbstractDict,
    window_summary::AbstractDict,
    A::AbstractMatrix,
    F::AbstractMatrix,
    continuous_spectrum::AbstractVector{<:Complex},
    discrete_spectrum::AbstractVector{<:Complex},
    diagnostics::AbstractDict,
    generated_files::AbstractDict,
)
    return Dict(
        "dataset_version" => String(release_version),
        "created_at" => string(now()),
        "benchmark_id" => String(benchmark_id),
        "system_kind" => String(system_kind),
        "system_id" => system_config["system_id"],
        "family" => system_config["family"],
        "variant" => system_config["variant"],
        "state_dim" => system_config["state_dim"],
        "observation_id" => observation_config["observation_id"],
        "observation_dim" => observation_config["output_dim"],
        "dt" => system_config["dt"],
        "trajectory_length" => system_config["trajectory_length"],
        "num_trajectories" => system_config["num_trajectories"],
        "solver_name" => system_config["solver_name"],
        "solver_abstol" => system_config["solver_abstol"],
        "solver_reltol" => system_config["solver_reltol"],
        "seed" => system_config["seed_policy"]["generation_seed"],
        "initial_condition_policy" => system_config["initial_condition_domain"],
        "dimension_lift_policy" => system_config["dimension_lift_policy"],
        "array_layout" => "state_dim_by_time_by_trajectory",
        "continuous_matrix_A" => matrix_rows(A),
        "discrete_matrix_F" => matrix_rows(F),
        "continuous_eigenvalues" => spectrum_metadata(continuous_spectrum),
        "discrete_eigenvalues" => spectrum_metadata(discrete_spectrum),
        "split_id" => split["split_id"],
        "split_counts" => split_count_summary(split),
        "window_summary" => window_summary,
        "diagnostics" => diagnostics,
        "generated_files" => generated_files,
    )
end

function generate_one_highdim_dataset(;
    system_kind::AbstractString,
    system_config::AbstractDict,
    observation_config::AbstractDict,
    split_config::AbstractDict,
    one_step_config::AbstractDict,
    rollout_horizons::AbstractVector{<:Integer},
    rollout_window_id::AbstractString,
    benchmark_id::AbstractString,
    release_version::AbstractString = "0.1.0-dev",
)
    state_dim = Int(system_config["state_dim"])
    trajectory_length = Int(system_config["trajectory_length"])
    num_trajectories = Int(system_config["num_trajectories"])
    times = linear_times(Float64(system_config["dt"]), trajectory_length)
    rng = MersenneTwister(Int(system_config["seed_policy"]["generation_seed"]))

    if system_kind == "linear_diagonal"
        A, F, continuous_spectrum, discrete_spectrum = diagonal_matrices(system_config)
        sampler = () -> sample_box_min_abs(rng, state_dim, system_config["initial_condition_domain"])
        trajectory_builder = x0 -> generate_diagonal_trajectory(
            Float64.(system_config["default_parameters"]["eigenvalues"]),
            Float64(system_config["dt"]),
            x0,
            trajectory_length,
        )
    elseif system_kind == "linear_rotation_contraction"
        A, F, continuous_spectrum, discrete_spectrum = rotation_matrices(system_config)
        sampler = () -> sample_repeated_polar_annulus(rng, state_dim, system_config["initial_condition_domain"])
        trajectory_builder = x0 -> generate_discrete_linear_trajectory(F, x0, trajectory_length)
    elseif system_kind == "linear_oscillator"
        A, F, continuous_spectrum, discrete_spectrum = oscillator_matrices(system_config)
        sampler = () -> sample_repeated_oscillator_box(rng, state_dim, system_config["initial_condition_domain"])
        trajectory_builder = x0 -> generate_discrete_linear_trajectory(F, x0, trajectory_length)
    else
        throw(ArgumentError("unknown system kind: $(system_kind)"))
    end

    trajectory_ids = [string(system_config["system_id"], "_", system_config["variant"], "_traj_", lpad(q, 4, '0')) for q in 1:num_trajectories]
    initial_conditions = Matrix{Float64}(undef, state_dim, num_trajectories)
    trajectories = Matrix{Float64}[]
    parameter_instance = deepcopy(system_config["default_parameters"])
    parameter_instances = [deepcopy(parameter_instance) for _ in 1:num_trajectories]

    for q in 1:num_trajectories
        x0 = sampler()
        initial_conditions[:, q] = x0
        X = trajectory_builder(x0)
        size(X) == (state_dim, trajectory_length + 1) ||
            throw(ArgumentError("generated state matrix has wrong size"))
        push!(trajectories, X)
    end

    split = build_trajectory_split(trajectory_ids, split_config)
    window_summary = build_window_summary(
        split,
        trajectory_length,
        one_step_config,
        rollout_horizons;
        rollout_window_id = rollout_window_id,
    )
    diagnostics = diagnostics_for_dataset(
        system_kind,
        system_config,
        F,
        discrete_spectrum,
        trajectories,
        initial_conditions,
        rollout_horizons,
    )
    diagnostics["split_counts"] = split_count_summary(split)
    diagnostics["one_step_window_counts"] = window_summary["one_step"]["counts"]
    diagnostics["rollout_window_counts"] = Dict(
        key => value["counts"] for (key, value) in window_summary["rollout"]["by_horizon"]
    )

    paths = output_paths_for(system_config, observation_config)
    save_dataset_tensors(
        raw_path = paths["raw_path"],
        processed_path = paths["processed_path"],
        trajectory_ids = trajectory_ids,
        system_config = system_config,
        observation_config = observation_config,
        parameter_instances = parameter_instances,
        initial_conditions = initial_conditions,
        times = times,
        trajectories = trajectories,
    )
    write_json_file(paths["split_path"], split)
    write_json_file(paths["windows_summary_path"], window_summary)

    generated_files = Dict(
        "system_config" => system_config["config_path"],
        "observation_config" => observation_config["config_path"],
        "raw_trajectories" => paths["raw_path"],
        "processed_trajectories" => paths["processed_path"],
        "split" => paths["split_path"],
        "windows_summary" => paths["windows_summary_path"],
        "diagnostics_table" => paths["table_path"],
        "log" => paths["log_path"],
        "manifest" => paths["manifest_path"],
        "release_index" => paths["release_index_path"],
    )

    manifest = make_manifest(
        benchmark_id = benchmark_id,
        release_version = release_version,
        system_kind = system_kind,
        system_config = system_config,
        observation_config = observation_config,
        split = split,
        window_summary = window_summary,
        A = A,
        F = F,
        continuous_spectrum = continuous_spectrum,
        discrete_spectrum = discrete_spectrum,
        diagnostics = diagnostics,
        generated_files = generated_files,
    )
    write_json_file(paths["manifest_path"], manifest)

    release_index = Dict(
        "release_id" => string(benchmark_id, "_release_index"),
        "release_version" => release_version,
        "system_kind" => system_kind,
        "system_id" => system_config["system_id"],
        "family" => system_config["family"],
        "variant" => system_config["variant"],
        "state_dim" => state_dim,
        "raw_path" => paths["raw_path"],
        "processed_path" => paths["processed_path"],
        "manifest_path" => paths["manifest_path"],
        "created_at" => string(now()),
    )
    write_json_file(paths["release_index_path"], release_index)

    columns, values = diagnostics_csv_row(system_kind, diagnostics)
    write_single_row_csv(paths["table_path"], columns, values)
    write_generation_log(paths["log_path"], manifest)

    return Dict(
        "system_kind" => String(system_kind),
        "system_id" => system_config["system_id"],
        "variant" => system_config["variant"],
        "state_dim" => state_dim,
        "passed" => diagnostics["passed"],
        "max_one_step_residual" => diagnostics["max_one_step_residual"],
        "rollout_residual_max" => diagnostics["rollout_residual_max"],
        "spectrum_abs_error_max" => diagnostics["spectrum_abs_error_max"],
        "manifest_path" => paths["manifest_path"],
        "raw_path" => paths["raw_path"],
        "processed_path" => paths["processed_path"],
    )
end

## Config derivation and direct entry point

function write_derived_configs()
    diagonal_base = load_config("systems", "unit_internal", "linear_diagonal_small.json")
    rotation_base = load_config("systems", "unit_internal", "linear_rotation_contraction_2d.json")
    oscillator_base = load_config("systems", "linear_oscillator_v1_core_damped.json")
    unit_obs_base = load_config("observations", "unit_internal", "full_state_identity_clean.json")
    core_obs_base = load_config("observations", "full_state_2d_clean.json")

    specs = Dict{String,Any}()
    for d in HIGH_DIMENSIONS
        diagonal = diagonal_highdim_config(diagonal_base, d)
        diagonal_path = project_path("configs", "systems", "unit_internal", string("linear_diagonal_uncoupled_d", d, ".json"))
        diagonal["config_path"] = relpath(diagonal_path, PROJECT_ROOT)
        write_json_file(diagonal_path, diagonal)

        rotation = rotation_highdim_config(rotation_base, d)
        rotation_path = project_path("configs", "systems", "unit_internal", string("linear_rotation_contraction_uncoupled_d", d, ".json"))
        rotation["config_path"] = relpath(rotation_path, PROJECT_ROOT)
        write_json_file(rotation_path, rotation)

        oscillator = oscillator_highdim_config(oscillator_base, d)
        oscillator_path = project_path("configs", "systems", "v1_core", string("linear_oscillator_uncoupled_d", d, ".json"))
        oscillator["config_path"] = relpath(oscillator_path, PROJECT_ROOT)
        write_json_file(oscillator_path, oscillator)

        unit_observation = observation_config(unit_obs_base, d; observation_id = string("full_state_clean_d", d))
        unit_observation_path = project_path("configs", "observations", "unit_internal", string("full_state_identity_clean_d", d, ".json"))
        unit_observation["config_path"] = relpath(unit_observation_path, PROJECT_ROOT)
        write_json_file(unit_observation_path, unit_observation)

        core_observation = observation_config(core_obs_base, d; observation_id = string("full_state_", d, "d_clean"))
        core_observation_path = project_path("configs", "observations", string("full_state_", d, "d_clean.json"))
        core_observation["config_path"] = relpath(core_observation_path, PROJECT_ROOT)
        write_json_file(core_observation_path, core_observation)

        specs[string("diagonal_d", d)] = diagonal
        specs[string("rotation_d", d)] = rotation
        specs[string("oscillator_d", d)] = oscillator
        specs[string("unit_observation_d", d)] = unit_observation
        specs[string("core_observation_d", d)] = core_observation
    end

    return specs
end

function generate_uncoupled_linear_highdim_datasets()
    configs = write_derived_configs()
    diagonal_split = load_config("splits", "unit_internal", "split_I_70_15_15_seed1.json")
    rotation_split = load_config("splits", "unit_internal", "split_i_70_15_15_seed202604.json")
    oscillator_split = load_config("splits", "linear_oscillator_v1_core_split_i.json")
    unit_one_step = load_config("windows", "unit_internal", "one_step_lag1.json")
    diagonal_rollout = [Int(load_config("windows", "unit_internal", "rollout_horizon20.json")["horizon"])]
    rotation_rollout = Int.(load_config("windows", "unit_internal", "rollout_h10_h50_h100.json")["horizons"])
    oscillator_windows = load_config("windows", "linear_oscillator_v1_core_windows.json")
    oscillator_rollout = Int.(oscillator_windows["rollout"]["horizons"])

    results = Dict{String,Any}[]
    for d in HIGH_DIMENSIONS
        push!(results, generate_one_highdim_dataset(
            system_kind = "linear_diagonal",
            system_config = configs[string("diagonal_d", d)],
            observation_config = configs[string("unit_observation_d", d)],
            split_config = diagonal_split,
            one_step_config = unit_one_step,
            rollout_horizons = diagonal_rollout,
            rollout_window_id = "rollout_horizon20",
            benchmark_id = string("linear_diagonal_uncoupled_d", d),
        ))
        push!(results, generate_one_highdim_dataset(
            system_kind = "linear_rotation_contraction",
            system_config = configs[string("rotation_d", d)],
            observation_config = configs[string("unit_observation_d", d)],
            split_config = rotation_split,
            one_step_config = unit_one_step,
            rollout_horizons = rotation_rollout,
            rollout_window_id = "rollout_h10_h50_h100",
            benchmark_id = string("linear_rotation_contraction_uncoupled_d", d),
        ))
        push!(results, generate_one_highdim_dataset(
            system_kind = "linear_oscillator",
            system_config = configs[string("oscillator_d", d)],
            observation_config = configs[string("core_observation_d", d)],
            split_config = oscillator_split,
            one_step_config = oscillator_windows["one_step"],
            rollout_horizons = oscillator_rollout,
            rollout_window_id = oscillator_windows["rollout"]["window_id"],
            benchmark_id = string("linear_oscillator_uncoupled_d", d),
        ))
    end

    summary_path = project_path("reports", "highdim_uncoupled_linear", "generation_summary.json")
    write_json_file(summary_path, Dict("created_at" => string(now()), "results" => results))
    return results
end

function print_highdim_generation_summary(results::AbstractVector)
    @printf("generated datasets: %d\n", length(results))
    for result in results
        @printf(
            "%s %-44s state_dim=%2d passed=%s one_step=%.3e rollout=%.3e spectrum=%.3e\n",
            result["system_kind"],
            string(result["system_id"], "/", result["variant"]),
            result["state_dim"],
            string(result["passed"]),
            result["max_one_step_residual"],
            result["rollout_residual_max"],
            result["spectrum_abs_error_max"],
        )
        @printf("  manifest: %s\n", result["manifest_path"])
    end
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    results = generate_uncoupled_linear_highdim_datasets()
    print_highdim_generation_summary(results)
end
