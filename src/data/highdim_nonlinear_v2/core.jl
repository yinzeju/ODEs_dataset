using Dates
using FFTW
using HDF5
using JSON
using LinearAlgebra
using OrdinaryDiffEq
import Plots
using Printf
using Random
using SciMLBase
using SHA
using Statistics

const HIGHDIM_NONLINEAR_V2 = "highdim_nonlinear_v2"
const HDND_SPLIT_NAMES = ("train", "val", "test")
const HDND_DERIVED_SAMPLING_VIEWS = [0.05, 0.10, 0.25]

Base.@kwdef struct HDNDProfile
    name::Symbol
    split_counts::NamedTuple{(:train, :val, :test),Tuple{Int,Int,Int}}
    l96_steps::Int
    pde_steps::Int
    l96_burn::Float64
    ks_warm::Float64
    l96_lyapunov_time::Float64
    ks_lyapunov_time::Float64
    check_count::Int
    sample_states_per_split::Int
    master_seed::Int
    output_root::String
    report_root::String
end

function hdnd_profile(project_root::AbstractString, name::Symbol)
    if name === :formal
        return HDNDProfile(
            name = :formal,
            split_counts = (train = 320, val = 80, test = 80),
            l96_steps = 2_048,
            pde_steps = 5_120,
            l96_burn = 100.0,
            ks_warm = 200.0,
            l96_lyapunov_time = 100.0,
            ks_lyapunov_time = 100.0,
            check_count = 256,
            sample_states_per_split = 2_048,
            master_seed = 20260710,
            output_root = joinpath(project_root, "data", "releases", HIGHDIM_NONLINEAR_V2),
            report_root = joinpath(project_root, "reports", "v2_core", HIGHDIM_NONLINEAR_V2),
        )
    elseif name === :smoke
        return HDNDProfile(
            name = :smoke,
            split_counts = (train = 4, val = 4, test = 4),
            l96_steps = 32,
            pde_steps = 40,
            l96_burn = 1.0,
            ks_warm = 2.0,
            l96_lyapunov_time = 1.0,
            ks_lyapunov_time = 1.0,
            check_count = 12,
            sample_states_per_split = 128,
            master_seed = 20260710,
            output_root = joinpath(project_root, "runs", "smoke_tests", HIGHDIM_NONLINEAR_V2),
            report_root = joinpath(project_root, "runs", "smoke_tests", string(HIGHDIM_NONLINEAR_V2, "_report")),
        )
    end
    throw(ArgumentError("unsupported HDND profile: $name"))
end

total_trajectory_count(profile::HDNDProfile) = sum(profile.split_counts)

function split_count(profile::HDNDProfile, split_name::AbstractString)
    return getproperty(profile.split_counts, Symbol(split_name))
end

function trajectory_seed(profile::HDNDProfile, system_offset::Integer, trajectory_id::Integer)
    return profile.master_seed + 1_000_000 * system_offset + trajectory_id
end

function time_vector(steps::Integer, tau::Real)
    return collect(Float64, (0:steps) .* tau)
end

function environment_hash(project_root::AbstractString)
    ctx = SHA.SHA256_CTX()
    for filename in ("Project.toml", "Manifest.toml")
        path = joinpath(project_root, filename)
        isfile(path) && SHA.update!(ctx, read(path))
    end
    return bytes2hex(SHA.digest!(ctx))
end

function git_commit(project_root::AbstractString)
    try
        return readchomp(`git -C $project_root rev-parse HEAD`)
    catch
        return "unavailable"
    end
end

function write_hdf5_string(parent, name::AbstractString, value::AbstractString)
    parent[name] = String(value)
    return nothing
end

function write_hdf5_json(parent, name::AbstractString, value)
    write_hdf5_string(parent, name, JSON.json(value))
end

function initialize_system_file!(
    h5,
    project_root::AbstractString,
    profile::HDNDProfile,
    metadata::AbstractDict,
    state_dim::Integer,
    steps::Integer,
    tau::Real,
)
    meta = create_group(h5, "meta")
    for (key, value) in metadata
        if value isa AbstractString
            write_hdf5_string(meta, key, value)
        elseif value isa Number
            meta[key] = value
        else
            write_hdf5_json(meta, key, value)
        end
    end
    meta["state_dimension"] = Int64(state_dim)
    meta["base_sampling_interval"] = Float64(tau)
    meta["derived_sampling_views"] = Float64.(HDND_DERIVED_SAMPLING_VIEWS)
    meta["record_time"] = Float64(steps * tau)
    meta["trajectory_count"] = Int64(total_trajectory_count(profile))
    write_hdf5_string(meta, "float_type", "Float64")
    meta["random_seed_master"] = Int64(profile.master_seed)
    write_hdf5_string(meta, "code_commit", git_commit(project_root))
    write_hdf5_string(meta, "environment_hash", environment_hash(project_root))
    write_hdf5_string(meta, "source_policy", "fresh_numerical_integration")
    write_hdf5_string(meta, "normalization_policy", "none_raw_physical_coordinates")
    write_hdf5_string(meta, "task_code", HIGHDIM_NONLINEAR_V2)

    nt = steps + 1
    time = time_vector(steps, tau)
    writers = Dict{String,Dict{String,Any}}()
    for split_name in HDND_SPLIT_NAMES
        count = split_count(profile, split_name)
        group = create_group(h5, split_name)
        state = create_dataset(
            group,
            "state",
            Float64,
            (count, nt, state_dim);
            chunk = (1, min(nt, 256), state_dim),
            compress = 3,
        )
        group["time"] = time
        group["trajectory_id"] = zeros(Int64, count)
        group["seed"] = zeros(Int64, count)
        group["initial_state"] = zeros(Float64, count, state_dim)
        group["warmup_time"] = zeros(Float64, count)
        writers[split_name] = Dict("group" => group, "state" => state)
    end
    return writers
end

function write_trajectory!(
    writer::AbstractDict,
    local_index::Integer,
    trajectory::AbstractMatrix{<:Real},
    trajectory_id::Integer,
    seed::Integer,
    warmup_time::Real,
)
    writer["state"][local_index, :, :] = trajectory
    writer["group"]["trajectory_id"][local_index] = Int64(trajectory_id)
    writer["group"]["seed"][local_index] = Int64(seed)
    writer["group"]["initial_state"][local_index, :] = @view trajectory[1, :]
    writer["group"]["warmup_time"][local_index] = Float64(warmup_time)
    return nothing
end

function write_regime_labels!(writer::AbstractDict, labels::AbstractVector{<:AbstractString})
    writer["group"]["regime_label"] = String.(labels)
    return nothing
end

function write_diagnostics!(h5, diagnostics::AbstractDict)
    haskey(h5, "diagnostics") && delete_object(h5, "diagnostics")
    group = create_group(h5, "diagnostics")
    for key in (
        "time_convergence",
        "space_convergence",
        "physical_statistics",
        "autocorrelation",
        "energy_spectrum",
        "lyapunov_spectrum",
        "split_distribution",
        "stationarity",
    )
        write_hdf5_json(group, key, get(diagnostics, key, Dict{String,Any}()))
    end
    return nothing
end

function evenly_spaced_indices(n::Integer, count::Integer)
    n <= 0 && return Int[]
    count = min(n, max(count, 1))
    return unique(round.(Int, range(1, n; length = count)))
end

function append_sample_states!(
    samples::Vector{Vector{Float64}},
    trajectory::AbstractMatrix{<:Real},
    target_count::Integer,
)
    remaining = target_count - length(samples)
    remaining <= 0 && return samples
    take = min(remaining, 8)
    for index in evenly_spaced_indices(size(trajectory, 1), take)
        push!(samples, collect(Float64, @view trajectory[index, :]))
    end
    return samples
end

function duplicate_check(initial_states::AbstractMatrix, seeds::AbstractVector{<:Integer})
    seed_unique = length(unique(seeds)) == length(seeds)
    hashes = [bytes2hex(SHA.sha256(reinterpret(UInt8, collect(@view initial_states[i, :])))) for i in axes(initial_states, 1)]
    state_unique = length(unique(hashes)) == length(hashes)
    return Dict(
        "passed" => seed_unique && state_unique,
        "seed_unique" => seed_unique,
        "initial_state_hash_unique" => state_unique,
    )
end

function finite_time_shape_checks(path::AbstractString, profile::HDNDProfile, expected_nt::Integer, expected_dim::Integer)
    checks = Dict{String,Any}()
    h5open(path, "r") do h5
        for split_name in HDND_SPLIT_NAMES
            state = h5[string(split_name, "/state")]
            time = read(h5[string(split_name, "/time")])
            expected_shape = (split_count(profile, split_name), expected_nt, expected_dim)
            time_tolerance = 8eps(maximum(abs, time))
            finite_passed = true
            for trajectory_index in axes(state, 1)
                if !all(isfinite, state[trajectory_index, :, :])
                    finite_passed = false
                    break
                end
            end
            checks[split_name] = Dict(
                "shape" => collect(size(state)),
                "shape_passed" => size(state) == expected_shape,
                "finite_passed" => finite_passed,
                "time_grid_passed" => all(isapprox.(diff(time), time[2] - time[1]; atol = time_tolerance, rtol = 0.0)),
                "time_grid_tolerance" => time_tolerance,
            )
        end
    end
    return checks
end

function scalar_summary(values::AbstractArray{<:Real})
    data = vec(Float64.(values))
    return Dict(
        "mean" => mean(data),
        "std" => std(data; corrected = false),
        "min" => minimum(data),
        "max" => maximum(data),
        "rms" => sqrt(mean(abs2, data)),
    )
end

function normalized_autocorrelation(series::AbstractVector{<:Real}, max_lag::Integer)
    x = Float64.(series)
    x .-= mean(x)
    variance = mean(abs2, x)
    variance <= eps(Float64) && return vcat(1.0, zeros(Float64, min(max_lag, length(x) - 1)))
    limit = min(max_lag, length(x) - 1)
    result = Vector{Float64}(undef, limit + 1)
    result[1] = 1.0
    for lag in 1:limit
        result[lag + 1] = dot(@view(x[1:(end - lag)]), @view(x[(lag + 1):end])) / ((length(x) - lag) * variance)
    end
    return result
end

function integrated_autocorrelation_time(acf::AbstractVector{<:Real}, tau::Real)
    cutoff = length(acf)
    for i in 2:length(acf)
        if acf[i] <= 0
            cutoff = i - 1
            break
        end
    end
    return tau * (1 + 2 * sum(@view acf[2:cutoff]))
end

function stationarity_summary(values_by_trajectory::AbstractVector{<:AbstractVector})
    deltas = Float64[]
    for values in values_by_trajectory
        half = length(values) ÷ 2
        half == 0 && continue
        early = @view values[1:half]
        late = @view values[(length(values) - half + 1):end]
        push!(deltas, abs(mean(late) - mean(early)) / (std(values; corrected = false) + eps(Float64)))
    end
    isempty(deltas) && return Dict("median" => NaN, "q90" => NaN)
    return Dict("median" => median(deltas), "q90" => quantile(deltas, 0.9))
end

function pca_distribution_metrics(samples::AbstractDict; q::Integer = 8, max_points::Integer = 1_024)
    train = reduce(hcat, samples["train"])'
    val = reduce(hcat, samples["val"])'
    test = reduce(hcat, samples["test"])'
    qeff = min(q, size(train, 2), size(train, 1) - 1)
    center = vec(mean(train; dims = 1))
    _, _, V = svd(train .- center'; full = false)
    projection = V[:, 1:qeff]
    projected = Dict(
        "train" => (train .- center') * projection,
        "val" => (val .- center') * projection,
        "test" => (test .- center') * projection,
    )
    regularization = 1.0e-8
    function gaussian_kl(x, y)
        mux = vec(mean(x; dims = 1)); muy = vec(mean(y; dims = 1))
        cx = cov(x; corrected = false) + regularization * I
        cy = cov(y; corrected = false) + regularization * I
        delta = muy - mux
        return 0.5 * (tr(cy \ cx) + dot(delta, cy \ delta) - qeff + logdet(cy) - logdet(cx))
    end
    train_kernel = projected["train"][1:min(end, max_points), :]
    distances = Float64[]
    for i in 1:min(size(train_kernel, 1), 256), j in 1:(i - 1)
        push!(distances, sum(abs2, @view(train_kernel[i, :]) .- @view(train_kernel[j, :])))
    end
    bandwidth2 = max(median(distances), eps(Float64))
    function mmd2(x, y)
        x = x[1:min(end, max_points), :]
        y = y[1:min(end, max_points), :]
        kernel(a, b) = exp(-sum(abs2, a .- b) / (2bandwidth2))
        xx = mean(kernel(@view(x[i, :]), @view(x[j, :])) for i in axes(x, 1), j in axes(x, 1) if i != j)
        yy = mean(kernel(@view(y[i, :]), @view(y[j, :])) for i in axes(y, 1), j in axes(y, 1) if i != j)
        xy = mean(kernel(@view(x[i, :]), @view(y[j, :])) for i in axes(x, 1), j in axes(y, 1))
        return max(xx + yy - 2xy, 0.0)
    end
    return Dict(
        "pca_dimension" => qeff,
        "pca_center_source" => "train_only",
        "kld_estimator" => "regularized_multivariate_gaussian_in_train_pca_coordinates",
        "mmd_kernel" => "rbf_train_median_squared_distance",
        "mmd_bandwidth_squared" => bandwidth2,
        "train_val_kld" => gaussian_kl(projected["train"], projected["val"]),
        "train_test_kld" => gaussian_kl(projected["train"], projected["test"]),
        "train_val_mmd2" => mmd2(projected["train"], projected["val"]),
        "train_test_mmd2" => mmd2(projected["train"], projected["test"]),
    )
end

function lyapunov_summary(exponents::AbstractVector{<:Real})
    lambda = sort(Float64.(exponents); rev = true)
    positive_count = count(>(0.0), lambda)
    cumulative = cumsum(lambda)
    r = findlast(>=(0.0), cumulative)
    dky = if isnothing(r)
        0.0
    elseif r == length(lambda)
        Float64(length(lambda))
    else
        r + cumulative[r] / abs(lambda[r + 1])
    end
    return Dict(
        "exponents" => lambda,
        "largest_lyapunov_exponent" => lambda[1],
        "lyapunov_time" => lambda[1] > 0 ? inv(lambda[1]) : nothing,
        "positive_lyapunov_count" => positive_count,
        "kaplan_yorke_dimension" => dky,
        "lyapunov_entropy_rate" => sum(max(value, 0.0) for value in lambda),
    )
end

function save_json(path::AbstractString, value)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON.print(io, value, 4)
    end
    return path
end
