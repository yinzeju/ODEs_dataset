using Dates
using JLD2
using JSON
using LinearAlgebra
using Printf
using Random
using Statistics

struct L96CompleteStateConfig
    dataset_id::String
    dataset_version::String
    Nx::Int
    F0::Float64
    dt_internal::Float64
    q_save::Int
    tau::Float64
    burn_in_time::Float64
    burn_in_steps::Int
    M_traj::Int
    snapshots::Int
    num_trajectories::Int
    train_count::Int
    val_count::Int
    test_count::Int
    h_max::Int
    rollout_horizons::Vector{Int}
    delta_init::Float64
    seed_master::Int
    epsilon_std::Float64
    S_chk::Int
    rk_acceptance_threshold::Float64
end

function L96CompleteStateConfig()
    dt_internal = 0.005
    q_save = 10
    M_traj = 2048
    burn_in_time = 100.0
    return L96CompleteStateConfig(
        "l96_nx40_complete_state_v1",
        "1.0.0",
        40,
        8.0,
        dt_internal,
        q_save,
        q_save * dt_internal,
        burn_in_time,
        Int(round(burn_in_time / dt_internal)),
        M_traj,
        M_traj + 1,
        40,
        24,
        8,
        8,
        64,
        [1, 2, 4, 8, 16, 32, 64],
        0.01,
        20260624,
        1.0e-8,
        128,
        1.0e-6,
    )
end

mutable struct L96RK4Workspace
    k1::Vector{Float64}
    k2::Vector{Float64}
    k3::Vector{Float64}
    k4::Vector{Float64}
    tmp::Vector{Float64}
end

L96RK4Workspace(n::Integer) = L96RK4Workspace(
    Vector{Float64}(undef, n),
    Vector{Float64}(undef, n),
    Vector{Float64}(undef, n),
    Vector{Float64}(undef, n),
    Vector{Float64}(undef, n),
)

l96_im2(i::Integer, n::Integer) = i <= 2 ? i + n - 2 : i - 2
l96_im1(i::Integer, n::Integer) = i == 1 ? n : i - 1
l96_ip1(i::Integer, n::Integer) = i == n ? 1 : i + 1

function l96_rhs!(dx::AbstractVector{Float64}, x::AbstractVector{Float64}, F0::Float64)
    n = length(x)
    length(dx) == n || throw(ArgumentError("dx and x must have the same length"))
    @inbounds for i in 1:n
        dx[i] = (x[l96_ip1(i, n)] - x[l96_im2(i, n)]) * x[l96_im1(i, n)] - x[i] + F0
    end
    return dx
end

function l96_rk4_step!(x::Vector{Float64}, workspace::L96RK4Workspace, F0::Float64, dt::Float64)
    k1 = workspace.k1
    k2 = workspace.k2
    k3 = workspace.k3
    k4 = workspace.k4
    tmp = workspace.tmp

    l96_rhs!(k1, x, F0)
    @inbounds for i in eachindex(x)
        tmp[i] = x[i] + 0.5 * dt * k1[i]
    end

    l96_rhs!(k2, tmp, F0)
    @inbounds for i in eachindex(x)
        tmp[i] = x[i] + 0.5 * dt * k2[i]
    end

    l96_rhs!(k3, tmp, F0)
    @inbounds for i in eachindex(x)
        tmp[i] = x[i] + dt * k3[i]
    end

    l96_rhs!(k4, tmp, F0)
    @inbounds for i in eachindex(x)
        x[i] += dt * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i]) / 6.0
    end
    return x
end

function l96_advance!(x::Vector{Float64}, workspace::L96RK4Workspace, F0::Float64, dt::Float64, steps::Integer)
    steps >= 0 || throw(ArgumentError("steps must be nonnegative"))
    for _ in 1:steps
        l96_rk4_step!(x, workspace, F0, dt)
    end
    return x
end

function l96_boundary_index_check(config::L96CompleteStateConfig = L96CompleteStateConfig())
    x = collect(1.0:Float64(config.Nx))
    dx = similar(x)
    l96_rhs!(dx, x, config.F0)
    f1 = (x[2] - x[39]) * x[40] - x[1] + config.F0
    fN = (x[1] - x[38]) * x[39] - x[40] + config.F0
    return abs(dx[1] - f1) <= 1.0e-12 && abs(dx[config.Nx] - fN) <= 1.0e-12
end

function l96_spawn_trajectory_seeds(config::L96CompleteStateConfig)
    rng = MersenneTwister(config.seed_master)
    return [Int(rand(rng, UInt32)) for _ in 1:config.num_trajectories]
end

function l96_split_indices(config::L96CompleteStateConfig)
    total = config.train_count + config.val_count + config.test_count
    total == config.num_trajectories || throw(ArgumentError("split counts do not sum to num_trajectories"))
    train = collect(1:config.train_count)
    val_start = last(train) + 1
    val = collect(val_start:(val_start + config.val_count - 1))
    test_start = last(val) + 1
    test = collect(test_start:(test_start + config.test_count - 1))
    return Dict("train" => train, "val" => val, "test" => test)
end

function l96_window_counts(config::L96CompleteStateConfig, splits::AbstractDict)
    starts_per_trajectory = config.M_traj - config.h_max + 1
    return Dict(
        "one_step" => Dict(
            split => length(indices) * config.M_traj
            for (split, indices) in splits
        ),
        "rollout" => Dict(
            "starts_per_trajectory" => starts_per_trajectory,
            "h_max" => config.h_max,
            "horizons" => config.rollout_horizons,
            "train" => length(splits["train"]) * starts_per_trajectory,
            "val" => length(splits["val"]) * starts_per_trajectory,
            "test" => length(splits["test"]) * starts_per_trajectory,
        ),
    )
end

function l96_generate_trajectory!(
    out::Array{Float64,3},
    trajectory_index::Integer,
    seed::Integer,
    config::L96CompleteStateConfig,
)
    rng = MersenneTwister(seed)
    x = fill(config.F0, config.Nx)
    x .+= config.delta_init .* randn(rng, config.Nx)
    pre_burn_in = copy(x)

    workspace = L96RK4Workspace(config.Nx)
    l96_advance!(x, workspace, config.F0, config.dt_internal, config.burn_in_steps)
    burn_in_state = copy(x)

    @inbounds for j in 1:config.Nx
        out[trajectory_index, 1, j] = x[j]
    end

    @inbounds for m in 2:config.snapshots
        l96_advance!(x, workspace, config.F0, config.dt_internal, config.q_save)
        for j in 1:config.Nx
            out[trajectory_index, m, j] = x[j]
        end
    end

    return pre_burn_in, burn_in_state
end

function l96_generate_all_trajectories(config::L96CompleteStateConfig)
    l96_boundary_index_check(config) || throw(ArgumentError("Lorenz96 periodic boundary check failed"))
    trajectories = Array{Float64,3}(undef, config.num_trajectories, config.snapshots, config.Nx)
    seeds = l96_spawn_trajectory_seeds(config)
    pre_burn_in = Matrix{Float64}(undef, config.num_trajectories, config.Nx)
    burn_in_states = Matrix{Float64}(undef, config.num_trajectories, config.Nx)

    for q in 1:config.num_trajectories
        pre, burned = l96_generate_trajectory!(trajectories, q, seeds[q], config)
        @inbounds for j in 1:config.Nx
            pre_burn_in[q, j] = pre[j]
            burn_in_states[q, j] = burned[j]
        end
        @printf("generated trajectory %02d/%02d with seed %d\n", q, config.num_trajectories, seeds[q])
    end

    return trajectories, seeds, pre_burn_in, burn_in_states
end

function l96_normalization(trajectories::Array{Float64,3}, train_indices::AbstractVector{<:Integer}, config::L96CompleteStateConfig)
    train_view = view(trajectories, train_indices, :, :)
    n = length(train_view)
    mu = sum(train_view) / n
    sigma = sqrt(sum(abs2(x - mu) for x in train_view) / n)
    return Dict(
        "mu_sp" => mu,
        "sigma_sp" => sigma,
        "epsilon_std" => config.epsilon_std,
        "policy" => "train_split_global_space_shared_population_statistics",
        "train_snapshot_count" => length(train_indices) * config.snapshots,
        "train_scalar_count" => n,
    )
end

function l96_state_at_linear_index(trajectories::Array{Float64,3}, linear_index::Integer)
    total_per_trajectory = size(trajectories, 2)
    q = div(linear_index - 1, total_per_trajectory) + 1
    m = mod(linear_index - 1, total_per_trajectory) + 1
    return vec(copy(view(trajectories, q, m, :)))
end

function l96_tau_advance_copy(x0::AbstractVector{Float64}, F0::Float64, dt::Float64, steps::Integer)
    x = copy(x0)
    workspace = L96RK4Workspace(length(x))
    l96_advance!(x, workspace, F0, dt, steps)
    return x
end

function l96_integration_check(trajectories::Array{Float64,3}, config::L96CompleteStateConfig)
    total_snapshots = size(trajectories, 1) * size(trajectories, 2)
    indices = round.(Int, range(1, total_snapshots; length = config.S_chk))
    rel_errors = Vector{Float64}(undef, length(indices))

    for (s, index) in enumerate(indices)
        x0 = l96_state_at_linear_index(trajectories, index)
        x_coarse = l96_tau_advance_copy(x0, config.F0, config.dt_internal, config.q_save)
        x_fine = l96_tau_advance_copy(x0, config.F0, config.dt_internal / 2, 2 * config.q_save)
        rel_errors[s] = norm(x_coarse - x_fine) / (norm(x_fine) + 1.0e-12)
    end

    epsilon_rk = mean(rel_errors)
    return Dict(
        "S_chk" => length(indices),
        "dt_coarse" => config.dt_internal,
        "steps_coarse" => config.q_save,
        "dt_fine" => config.dt_internal / 2,
        "steps_fine" => 2 * config.q_save,
        "epsilon_RK" => epsilon_rk,
        "relative_error_max" => maximum(rel_errors),
        "relative_error_min" => minimum(rel_errors),
        "relative_error_std" => std(rel_errors),
        "accepted" => epsilon_rk <= config.rk_acceptance_threshold,
        "acceptance_threshold" => config.rk_acceptance_threshold,
    )
end

function l96_trajectory_energy_statistics(trajectories::Array{Float64,3}, config::L96CompleteStateConfig)
    rows = Vector{Dict{String,Any}}(undef, size(trajectories, 1))
    energies_by_split = Dict{String,Vector{Float64}}()
    splits = l96_split_indices(config)
    for split in keys(splits)
        energies_by_split[split] = Float64[]
    end

    for q in axes(trajectories, 1)
        energies = Vector{Float64}(undef, size(trajectories, 2))
        @inbounds for m in axes(trajectories, 2)
            e = 0.0
            for j in axes(trajectories, 3)
                e += trajectories[q, m, j]^2
            end
            energies[m] = e / (2 * config.Nx)
        end
        early = view(energies, 1:1024)
        late = view(energies, 1025:2049)
        rows[q] = Dict(
            "trajectory_id" => l96_trajectory_id(q),
            "trajectory_index" => q,
            "energy_mean" => mean(energies),
            "energy_std" => std(energies),
            "energy_min" => minimum(energies),
            "energy_max" => maximum(energies),
            "energy_early_mean" => mean(early),
            "energy_late_mean" => mean(late),
            "energy_late_minus_early" => mean(late) - mean(early),
        )
        for (split, indices) in splits
            if q in indices
                append!(energies_by_split[split], energies)
                break
            end
        end
    end

    split_summary = Dict(
        split => Dict(
            "energy_mean" => mean(values),
            "energy_std" => std(values),
            "energy_min" => minimum(values),
            "energy_max" => maximum(values),
        )
        for (split, values) in energies_by_split
    )

    return Dict("trajectories" => rows, "split_summary" => split_summary)
end

function l96_dataset_diagnostics(
    trajectories::Array{Float64,3},
    normalization::AbstractDict,
    integration_check::AbstractDict,
    energy_statistics::AbstractDict,
    config::L96CompleteStateConfig,
)
    splits = l96_split_indices(config)
    window_counts = l96_window_counts(config, splits)
    shape_passed = size(trajectories) == (config.num_trajectories, config.snapshots, config.Nx)
    finite_passed = all(isfinite, trajectories)
    split_shapes = Dict(
        split => [length(indices), config.snapshots, config.Nx]
        for (split, indices) in splits
    )
    split_counts = Dict(split => length(indices) for (split, indices) in splits)
    state_min = minimum(trajectories)
    state_max = maximum(trajectories)
    energy_means = [row["energy_mean"] for row in energy_statistics["trajectories"]]
    early_late_abs = maximum(abs(row["energy_late_minus_early"]) for row in energy_statistics["trajectories"])

    return Dict(
        "dataset_id" => config.dataset_id,
        "state_shape_all" => collect(size(trajectories)),
        "split_shapes" => split_shapes,
        "shape_passed" => shape_passed,
        "finite_passed" => finite_passed,
        "boundary_index_check_passed" => l96_boundary_index_check(config),
        "integration_check_passed" => integration_check["accepted"],
        "all_passed" => shape_passed && finite_passed && l96_boundary_index_check(config) && integration_check["accepted"],
        "split_counts" => split_counts,
        "one_step_pair_counts" => window_counts["one_step"],
        "rollout_window_counts" => window_counts["rollout"],
        "state_min" => state_min,
        "state_max" => state_max,
        "state_span" => state_max - state_min,
        "mu_sp" => normalization["mu_sp"],
        "sigma_sp" => normalization["sigma_sp"],
        "epsilon_RK" => integration_check["epsilon_RK"],
        "epsilon_RK_max" => integration_check["relative_error_max"],
        "energy_mean_min_by_trajectory" => minimum(energy_means),
        "energy_mean_mean_by_trajectory" => mean(energy_means),
        "energy_mean_max_by_trajectory" => maximum(energy_means),
        "max_abs_late_minus_early_energy" => early_late_abs,
    )
end

l96_trajectory_id(index::Integer) = @sprintf("l96_nx40_complete_state_v1_traj_%03d", index)

function l96_times(config::L96CompleteStateConfig)
    return collect(0.0:config.tau:(config.M_traj * config.tau))
end

function l96_write_json(path::AbstractString, object)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON.print(io, object, 2)
        write(io, "\n")
    end
    return path
end

function l96_write_split_jld2(
    path::AbstractString,
    trajectories::Array{Float64,3},
    indices::AbstractVector{<:Integer},
    config::L96CompleteStateConfig,
)
    mkpath(dirname(path))
    split_tensor = Array{Float64,3}(trajectories[indices, :, :])
    JLD2.jldsave(
        path;
        trajectories = split_tensor,
        trajectory_ids = [l96_trajectory_id(i) for i in indices],
        source_trajectory_indices = collect(indices),
        times = l96_times(config),
        array_layout = "trajectory_by_time_by_state",
        state_dim = config.Nx,
        snapshot_count = config.snapshots,
        one_step_pair_count_per_trajectory = config.M_traj,
        dtype = "Float64",
    )
    return path
end

function l96_splits_payload(config::L96CompleteStateConfig, seeds::AbstractVector{<:Integer})
    splits = l96_split_indices(config)
    split_labels = Dict{String,String}()
    trajectory_records = Vector{Dict{String,Any}}()
    for (split, indices) in splits
        for index in indices
            split_labels[l96_trajectory_id(index)] = split
        end
    end
    for index in 1:config.num_trajectories
        push!(
            trajectory_records,
            Dict(
                "trajectory_id" => l96_trajectory_id(index),
                "trajectory_index" => index,
                "split" => split_labels[l96_trajectory_id(index)],
                "seed" => seeds[index],
            ),
        )
    end
    return Dict(
        "split_id" => "l96_nx40_complete_state_v1_split_i",
        "split_type" => "initial_condition",
        "grouping_unit" => "trajectory",
        "assignment_policy" => "deterministic ordered trajectory blocks: 1-24 train, 25-32 val, 33-40 test",
        "counts" => Dict(split => length(indices) for (split, indices) in splits),
        "train_trajectory_ids" => [l96_trajectory_id(i) for i in splits["train"]],
        "val_trajectory_ids" => [l96_trajectory_id(i) for i in splits["val"]],
        "test_trajectory_ids" => [l96_trajectory_id(i) for i in splits["test"]],
        "trajectories" => trajectory_records,
    )
end

function l96_metadata_payload(
    config::L96CompleteStateConfig,
    seeds::AbstractVector{<:Integer},
    pre_burn_in::AbstractMatrix{Float64},
    burn_in_states::AbstractMatrix{Float64},
    diagnostics::AbstractDict,
    output_files::AbstractDict,
)
    return Dict(
        "dataset_id" => config.dataset_id,
        "dataset_version" => config.dataset_version,
        "generated_at" => string(now()),
        "data_format_version" => "l96_complete_state_jld2_json_v1",
        "rk4_implementation_version" => "preallocated_l96_rk4_v1",
        "system_id" => "lorenz96",
        "state_dim" => config.Nx,
        "N_x" => config.Nx,
        "F0" => config.F0,
        "dt_internal" => config.dt_internal,
        "q_save" => config.q_save,
        "tau" => config.tau,
        "burn_in_time" => config.burn_in_time,
        "burn_in_steps" => config.burn_in_steps,
        "M_traj" => config.M_traj,
        "snapshots_per_trajectory" => config.snapshots,
        "recorded_time" => config.M_traj * config.tau,
        "h_max" => config.h_max,
        "rollout_horizons" => config.rollout_horizons,
        "seed_master" => config.seed_master,
        "trajectory_seeds" => seeds,
        "seed_spawn_rule" => "MersenneTwister(seed_master) draws one UInt32 seed per trajectory; each trajectory uses its own MersenneTwister(seed).",
        "delta_init" => config.delta_init,
        "pre_burn_in_initial_conditions_shape" => collect(size(pre_burn_in)),
        "burn_in_states_shape" => collect(size(burn_in_states)),
        "array_layout" => "trajectory_by_time_by_state",
        "observation_mode" => "complete_state_identity_clean",
        "z_equals_y_equals_x" => true,
        "float_type" => "Float64",
        "diagnostics_summary" => diagnostics,
        "generated_files" => output_files,
    )
end

function l96_write_csv(path::AbstractString, header::AbstractVector{<:AbstractString}, rows::AbstractVector)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(header, ","))
        for row in rows
            println(io, join([string(row[col]) for col in header], ","))
        end
    end
    return path
end

function l96_write_energy_csv(path::AbstractString, energy_statistics::AbstractDict)
    header = [
        "trajectory_id",
        "trajectory_index",
        "energy_mean",
        "energy_std",
        "energy_min",
        "energy_max",
        "energy_early_mean",
        "energy_late_mean",
        "energy_late_minus_early",
    ]
    return l96_write_csv(path, header, energy_statistics["trajectories"])
end

function l96_write_summary_csv(path::AbstractString, diagnostics::AbstractDict)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "metric,value")
        for key in sort(collect(keys(diagnostics)))
            value = diagnostics[key]
            if !(value isa AbstractDict || value isa AbstractVector)
                println(io, key, ",", value)
            end
        end
    end
    return path
end

function l96_write_report(
    path::AbstractString,
    config::L96CompleteStateConfig,
    diagnostics::AbstractDict,
    integration_check::AbstractDict,
    energy_statistics::AbstractDict,
    output_files::AbstractDict,
)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# Lorenz96 Nx40 Complete-State v1 Dataset Report")
        println(io)
        println(io, "## Objective and Scope")
        println(io)
        println(io, "This report records the formal generation of `l96_nx40_complete_state_v1`, a complete-state Lorenz96 dataset for high-dimensional autonomous chaotic dynamics. The dataset contains only raw physical-coordinate trajectories, trajectory-level splits, train-only normalization statistics, and acceptance diagnostics. It does not include model training, learned dictionaries, kernels, controls, partial observations, or noise injection.")
        println(io)
        println(io, "The learning object is `z_m = y_m = x_m in R^40`, sampled from the numerical flow `F_num^tau` with `tau = 0.05`.")
        println(io)
        println(io, "## Method and Configuration")
        println(io)
        println(io, "| Quantity | Value |")
        println(io, "| --- | --- |")
        println(io, "| State dimension | $(config.Nx) |")
        println(io, "| Forcing `F0` | $(config.F0) |")
        println(io, "| RK4 internal step `dt_internal` | $(config.dt_internal) |")
        println(io, "| Save stride `q_save` | $(config.q_save) |")
        println(io, "| Learning interval `tau` | $(config.tau) |")
        println(io, "| Burn-in time / steps | $(config.burn_in_time) / $(config.burn_in_steps) |")
        println(io, "| One-step pairs per trajectory | $(config.M_traj) |")
        println(io, "| Snapshots per trajectory | $(config.snapshots) |")
        println(io, "| Trajectories train / val / test | $(config.train_count) / $(config.val_count) / $(config.test_count) |")
        println(io, "| Master seed | $(config.seed_master) |")
        println(io, "| Maximum rollout horizon | $(config.h_max) |")
        println(io)
        println(io, "The vector field uses periodic indexing:")
        println(io)
        println(io, raw"$$")
        println(io, raw"\frac{dx_j}{dt} = (x_{j+1} - x_{j-2})x_{j-1} - x_j + F_0,\qquad j=1,\ldots,40.")
        println(io, raw"$$")
        println(io)
        println(io, "Initial states are sampled as `F0 * ones(40) + 0.01 * xi`, where each trajectory uses a spawned trajectory seed recorded in `metadata.json` and `splits.json`.")
        println(io)
        println(io, "## Dataset and Splits")
        println(io)
        println(io, "| Split | Trajectories | Tensor shape | One-step pairs | Valid h_max windows |")
        println(io, "| --- | ---: | --- | ---: | ---: |")
        for split in ("train", "val", "test")
            println(
                io,
                "| $(split) | $(diagnostics["split_counts"][split]) | $(diagnostics["split_shapes"][split]) | $(diagnostics["one_step_pair_counts"][split]) | $(diagnostics["rollout_window_counts"][split]) |",
            )
        end
        println(io)
        println(io, "The split is trajectory-level. No trajectory is shared across train, validation, and test.")
        println(io)
        println(io, "## Normalization")
        println(io)
        println(io, "The physical-coordinate tensors remain unnormalized. The saved normalization statistics are train-only, globally shared across all spatial coordinates:")
        println(io)
        println(io, raw"$$")
        println(io, raw"\widetilde{x} = \frac{x-\mu_{\mathrm{sp}}}{\sigma_{\mathrm{sp}} + 10^{-8}}.")
        println(io, raw"$$")
        println(io)
        println(io, "| Statistic | Value |")
        println(io, "| --- | ---: |")
        println(io, "| `mu_sp` | $(diagnostics["mu_sp"]) |")
        println(io, "| `sigma_sp` | $(diagnostics["sigma_sp"]) |")
        println(io)
        println(io, "## Validation Protocol and Results")
        println(io)
        println(io, "| Check | Result |")
        println(io, "| --- | --- |")
        println(io, "| Shape check | $(diagnostics["shape_passed"]) |")
        println(io, "| Finite-value check | $(diagnostics["finite_passed"]) |")
        println(io, "| Periodic boundary check | $(diagnostics["boundary_index_check_passed"]) |")
        println(io, "| RK4 step-size consistency accepted | $(integration_check["accepted"]) |")
        println(io, "| Mean relative RK difference `epsilon_RK` | $(integration_check["epsilon_RK"]) |")
        println(io, "| Maximum relative RK difference | $(integration_check["relative_error_max"]) |")
        println(io, "| Overall acceptance | $(diagnostics["all_passed"]) |")
        println(io)
        println(io, "## Energy Diagnostics")
        println(io)
        println(io, "| Metric | Value |")
        println(io, "| --- | ---: |")
        println(io, "| State range min | $(diagnostics["state_min"]) |")
        println(io, "| State range max | $(diagnostics["state_max"]) |")
        println(io, "| State span | $(diagnostics["state_span"]) |")
        println(io, "| Mean trajectory energy mean | $(diagnostics["energy_mean_mean_by_trajectory"]) |")
        println(io, "| Min trajectory energy mean | $(diagnostics["energy_mean_min_by_trajectory"]) |")
        println(io, "| Max trajectory energy mean | $(diagnostics["energy_mean_max_by_trajectory"]) |")
        println(io, "| Max absolute late-minus-early trajectory energy | $(diagnostics["max_abs_late_minus_early_energy"]) |")
        println(io)
        println(io, "| Split | Energy mean | Energy std | Energy min | Energy max |")
        println(io, "| --- | ---: | ---: | ---: | ---: |")
        for split in ("train", "val", "test")
            summary = energy_statistics["split_summary"][split]
            println(io, "| $(split) | $(summary["energy_mean"]) | $(summary["energy_std"]) | $(summary["energy_min"]) | $(summary["energy_max"]) |")
        end
        println(io)
        println(io, "The early/late energy diagnostic is recorded for quality inspection only. It was not used to remove trajectories.")
        println(io)
        println(io, "## Reproducibility Notes")
        println(io)
        println(io, "The generated dataset root is `data/releases/l96_nx40_complete_state_v1/`. Split tensors are JLD2 files with layout `trajectory_by_time_by_state`, and metadata, normalization, split, and diagnostic files are JSON. The generation log and report-local CSV tables are stored under `reports/v1_core/l96_nx40_complete_state_v1/`.")
        println(io)
        println(io, "Main generated files:")
        println(io)
        for key in sort(collect(keys(output_files)))
            println(io, "- `$(key)`: `$(output_files[key])`")
        end
        println(io)
        println(io, "## Limitations and Next Steps")
        println(io)
        println(io, "This release contains only the clean complete-state, fixed-forcing Lorenz96 configuration. Downstream tasks should derive one-step and rollout windows by index inside each split and should reuse the train normalization statistics for validation and test data.")
    end
    return path
end

function l96_output_paths(project_root::AbstractString, config::L96CompleteStateConfig)
    root = joinpath(project_root, "data", "releases", config.dataset_id)
    report_root = joinpath(project_root, "reports", "v1_core", config.dataset_id)
    return Dict(
        "dataset_root" => root,
        "train_trajectories" => joinpath(root, "train", "trajectories.jld2"),
        "val_trajectories" => joinpath(root, "val", "trajectories.jld2"),
        "test_trajectories" => joinpath(root, "test", "trajectories.jld2"),
        "metadata" => joinpath(root, "metadata.json"),
        "normalization" => joinpath(root, "normalization.json"),
        "splits" => joinpath(root, "splits.json"),
        "integration_check" => joinpath(root, "diagnostics", "integration_check.json"),
        "trajectory_statistics" => joinpath(root, "diagnostics", "trajectory_statistics.json"),
        "diagnostics_summary" => joinpath(root, "diagnostics", "diagnostics_summary.json"),
        "report" => joinpath(report_root, "notebooks", "l96_nx40_complete_state_v1_report.md"),
        "energy_table" => joinpath(report_root, "tables", "trajectory_energy_statistics.csv"),
        "summary_table" => joinpath(report_root, "tables", "diagnostics_summary.csv"),
        "log" => joinpath(report_root, "logs", "generate_l96_nx40_complete_state_v1.log"),
    )
end

function generate_l96_nx40_complete_state_v1(project_root::AbstractString = normpath(joinpath(@__DIR__, "..", "..")))
    config = L96CompleteStateConfig()
    started_at = now()
    output_paths = l96_output_paths(project_root, config)
    splits = l96_split_indices(config)

    trajectories, seeds, pre_burn_in, burn_in_states = l96_generate_all_trajectories(config)
    normalization = l96_normalization(trajectories, splits["train"], config)
    integration_check = l96_integration_check(trajectories, config)
    energy_statistics = l96_trajectory_energy_statistics(trajectories, config)
    diagnostics = l96_dataset_diagnostics(
        trajectories,
        normalization,
        integration_check,
        energy_statistics,
        config,
    )

    l96_write_split_jld2(output_paths["train_trajectories"], trajectories, splits["train"], config)
    l96_write_split_jld2(output_paths["val_trajectories"], trajectories, splits["val"], config)
    l96_write_split_jld2(output_paths["test_trajectories"], trajectories, splits["test"], config)

    metadata = l96_metadata_payload(config, seeds, pre_burn_in, burn_in_states, diagnostics, output_paths)
    l96_write_json(output_paths["metadata"], metadata)
    l96_write_json(output_paths["normalization"], normalization)
    l96_write_json(output_paths["splits"], l96_splits_payload(config, seeds))
    l96_write_json(output_paths["integration_check"], integration_check)
    l96_write_json(output_paths["trajectory_statistics"], energy_statistics)
    l96_write_json(output_paths["diagnostics_summary"], diagnostics)
    l96_write_energy_csv(output_paths["energy_table"], energy_statistics)
    l96_write_summary_csv(output_paths["summary_table"], diagnostics)
    l96_write_report(output_paths["report"], config, diagnostics, integration_check, energy_statistics, output_paths)

    mkpath(dirname(output_paths["log"]))
    open(output_paths["log"], "w") do io
        println(io, "dataset_id: ", config.dataset_id)
        println(io, "started_at: ", started_at)
        println(io, "finished_at: ", now())
        println(io, "shape_all: ", size(trajectories))
        println(io, "split_shapes: ", diagnostics["split_shapes"])
        println(io, "mu_sp: ", diagnostics["mu_sp"])
        println(io, "sigma_sp: ", diagnostics["sigma_sp"])
        println(io, "epsilon_RK: ", diagnostics["epsilon_RK"])
        println(io, "epsilon_RK_max: ", diagnostics["epsilon_RK_max"])
        println(io, "state_range: [", diagnostics["state_min"], ", ", diagnostics["state_max"], "]")
        println(io, "energy_mean_mean_by_trajectory: ", diagnostics["energy_mean_mean_by_trajectory"])
        println(io, "all_passed: ", diagnostics["all_passed"])
        println(io, "dataset_root: ", output_paths["dataset_root"])
    end

    return (
        config = config,
        output_paths = output_paths,
        diagnostics = diagnostics,
        integration_check = integration_check,
        normalization = normalization,
        energy_statistics = energy_statistics,
    )
end

function print_l96_nx40_summary(result)
    diagnostics = result.diagnostics
    paths = result.output_paths
    @printf("dataset_id: %s\n", result.config.dataset_id)
    @printf("state_shape_all: %s\n", string(diagnostics["state_shape_all"]))
    @printf("train / val / test shapes: %s / %s / %s\n",
        string(diagnostics["split_shapes"]["train"]),
        string(diagnostics["split_shapes"]["val"]),
        string(diagnostics["split_shapes"]["test"]),
    )
    @printf("one-step pairs train / val / test: %d / %d / %d\n",
        diagnostics["one_step_pair_counts"]["train"],
        diagnostics["one_step_pair_counts"]["val"],
        diagnostics["one_step_pair_counts"]["test"],
    )
    @printf("rollout h_max windows train / val / test: %d / %d / %d\n",
        diagnostics["rollout_window_counts"]["train"],
        diagnostics["rollout_window_counts"]["val"],
        diagnostics["rollout_window_counts"]["test"],
    )
    @printf("mu_sp / sigma_sp: %.12g / %.12g\n", diagnostics["mu_sp"], diagnostics["sigma_sp"])
    @printf("state range: [%.12g, %.12g]\n", diagnostics["state_min"], diagnostics["state_max"])
    @printf("epsilon_RK mean / max: %.12e / %.12e\n", diagnostics["epsilon_RK"], diagnostics["epsilon_RK_max"])
    @printf("energy mean across trajectories: %.12g\n", diagnostics["energy_mean_mean_by_trajectory"])
    @printf("all_passed: %s\n", string(diagnostics["all_passed"]))
    @printf("dataset root: %s\n", paths["dataset_root"])
    @printf("report: %s\n", paths["report"])
end
