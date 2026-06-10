using Dates
using JLD2
using JSON
using LinearAlgebra
using Printf
using Random
using Statistics

const STANDARD_ODES_V1 = "standard_odes_v1"
const STANDARD_NOISE_LEVELS_DB = (5.0, 15.0)

struct StandardObjectSpec
    object_id::String
    family::String
    state_dim::Int
    dt::Float64
    trajectory_length::Int
    num_trajectories::Int
    train_count::Int
    val_count::Int
    test_count::Int
    horizons::Vector{Int}
    seed::Int
    params::Dict{String,Any}
end

project_path(parts...) = joinpath(PROJECT_ROOT, parts...)

function ensure_parent_dir(path::AbstractString)
    mkpath(dirname(path))
    return path
end

function write_json(path::AbstractString, data)
    ensure_parent_dir(path)
    open(path, "w") do io
        JSON.print(io, data, 2)
    end
    return path
end

function split_roles(spec::StandardObjectSpec)
    n = spec.num_trajectories
    spec.train_count + spec.val_count + spec.test_count == n ||
        error("split counts do not sum to num_trajectories for $(spec.object_id)")
    roles = Vector{String}(undef, n)
    roles[1:spec.train_count] .= "train"
    roles[(spec.train_count + 1):(spec.train_count + spec.val_count)] .= "val"
    roles[(spec.train_count + spec.val_count + 1):n] .= "test"
    return roles
end

function role_counts(roles::AbstractVector{String})
    return Dict(role => count(==(role), roles) for role in ("train", "val", "test"))
end

function one_step_counts(spec::StandardObjectSpec)
    return Dict(
        "train" => spec.train_count * spec.trajectory_length,
        "val" => spec.val_count * spec.trajectory_length,
        "test" => spec.test_count * spec.trajectory_length,
    )
end

function rollout_counts(spec::StandardObjectSpec)
    by_horizon = Dict{String,Any}()
    for h in spec.horizons
        windows_per_traj = max(spec.trajectory_length - h + 1, 0)
        by_horizon[string(h)] = Dict(
            "train" => spec.train_count * windows_per_traj,
            "val" => spec.val_count * windows_per_traj,
            "test" => spec.test_count * windows_per_traj,
        )
    end
    return by_horizon
end

function profile_specs(profile::Symbol)
    if profile == :formal
        return [
            StandardObjectSpec("linear_diagonal", "linear", 4, 0.01, 1024, 512, 384, 64, 64, [1, 4, 8, 16, 32, 64], 310001,
                Dict("eigenvalues" => [-1.0, -0.3, 0.1, 0.5], "ic_lower" => -1.0, "ic_upper" => 1.0, "ic_min_abs" => 0.1)),
            StandardObjectSpec("linear_rotation_contraction_2d", "linear", 2, 0.01, 2048, 512, 384, 64, 64, [1, 4, 8, 16, 32, 64, 128], 310002,
                Dict("gamma" => 0.15, "omega" => 2pi, "radius_lower" => 0.5, "radius_upper" => 2.0)),
            StandardObjectSpec("damped_linear_oscillator", "linear", 2, 0.02, 3000, 512, 384, 64, 64, [1, 4, 8, 16, 32, 64, 128], 310003,
                Dict("gamma" => 0.05, "omega0" => 1.0, "ic_lower" => [-2.0, -2.0], "ic_upper" => [2.0, 2.0], "ic_min_norm" => 0.35)),
            StandardObjectSpec("duffing_chi40_medium", "duffing", 2, 0.01, 2048, 512, 384, 64, 64, [1, 4, 8, 16, 32, 64, 128], 310004,
                Dict("alpha" => 1.0, "delta" => 0.08, "beta" => 10.0, "Q" => 2.0, "reltol" => 1.0e-11, "abstol" => 1.0e-13, "max_internal_step" => 0.0005)),
            StandardObjectSpec("duffing_chi320_strong", "duffing", 2, 0.01, 2048, 512, 384, 64, 64, [1, 4, 8, 16, 32, 64, 128], 310005,
                Dict("alpha" => 1.0, "delta" => 0.08, "beta" => 20.0, "Q" => 4.0, "reltol" => 1.0e-11, "abstol" => 1.0e-13, "max_internal_step" => 0.0005)),
            StandardObjectSpec("lorenz63_standard", "chaotic", 3, 0.01, 4096, 512, 384, 64, 64, [1, 4, 8, 16, 32, 64], 310006,
                Dict("sigma" => 10.0, "rho" => 28.0, "beta" => 8.0 / 3.0, "burn_in_time" => 10.0, "reltol" => 1.0e-10, "abstol" => 1.0e-12, "max_internal_step" => 0.002)),
            StandardObjectSpec("rossler_standard", "chaotic", 3, 0.02, 4096, 512, 384, 64, 64, [1, 4, 8, 16, 32, 64], 310007,
                Dict("a" => 0.2, "b" => 0.2, "c" => 5.7, "burn_in_time" => 50.0, "reltol" => 1.0e-10, "abstol" => 1.0e-12, "max_internal_step" => 0.004)),
            StandardObjectSpec("nonlinear_pendulum_lusch2018", "hamiltonian", 2, 0.02, 50, 8192, 6144, 1024, 1024, [1, 5, 10, 25, 50], 310008,
                Dict("x1_min" => -3.1, "x1_max" => 3.1, "x2_min" => -2.0, "x2_max" => 2.0, "energy_threshold" => 0.99)),
        ]
    elseif profile == :smoke
        return [
            StandardObjectSpec("linear_diagonal", "linear", 4, 0.01, 32, 12, 8, 2, 2, [1, 4, 8], 410001,
                Dict("eigenvalues" => [-1.0, -0.3, 0.1, 0.5], "ic_lower" => -1.0, "ic_upper" => 1.0, "ic_min_abs" => 0.1)),
            StandardObjectSpec("linear_rotation_contraction_2d", "linear", 2, 0.01, 48, 12, 8, 2, 2, [1, 4, 8], 410002,
                Dict("gamma" => 0.15, "omega" => 2pi, "radius_lower" => 0.5, "radius_upper" => 2.0)),
            StandardObjectSpec("damped_linear_oscillator", "linear", 2, 0.02, 64, 12, 8, 2, 2, [1, 4, 8], 410003,
                Dict("gamma" => 0.05, "omega0" => 1.0, "ic_lower" => [-2.0, -2.0], "ic_upper" => [2.0, 2.0], "ic_min_norm" => 0.35)),
            StandardObjectSpec("duffing_chi40_medium", "duffing", 2, 0.01, 48, 12, 8, 2, 2, [1, 4, 8], 410004,
                Dict("alpha" => 1.0, "delta" => 0.08, "beta" => 10.0, "Q" => 2.0, "reltol" => 1.0e-10, "abstol" => 1.0e-12, "max_internal_step" => 0.001)),
            StandardObjectSpec("duffing_chi320_strong", "duffing", 2, 0.01, 48, 12, 8, 2, 2, [1, 4, 8], 410005,
                Dict("alpha" => 1.0, "delta" => 0.08, "beta" => 20.0, "Q" => 4.0, "reltol" => 1.0e-10, "abstol" => 1.0e-12, "max_internal_step" => 0.001)),
            StandardObjectSpec("lorenz63_standard", "chaotic", 3, 0.01, 64, 12, 8, 2, 2, [1, 4, 8], 410006,
                Dict("sigma" => 10.0, "rho" => 28.0, "beta" => 8.0 / 3.0, "burn_in_time" => 1.0, "reltol" => 1.0e-10, "abstol" => 1.0e-12, "max_internal_step" => 0.002)),
            StandardObjectSpec("rossler_standard", "chaotic", 3, 0.02, 64, 12, 8, 2, 2, [1, 4, 8], 410007,
                Dict("a" => 0.2, "b" => 0.2, "c" => 5.7, "burn_in_time" => 2.0, "reltol" => 1.0e-10, "abstol" => 1.0e-12, "max_internal_step" => 0.004)),
            StandardObjectSpec("nonlinear_pendulum_lusch2018", "hamiltonian", 2, 0.02, 20, 32, 24, 4, 4, [1, 5, 10, 20], 410008,
                Dict("x1_min" => -3.1, "x1_max" => 3.1, "x2_min" => -2.0, "x2_max" => 2.0, "energy_threshold" => 0.99)),
        ]
    else
        error("unknown Standard_ODEs_v1 profile: $profile")
    end
end

function sample_box_min_abs(rng::AbstractRNG, d::Int, lower::Real, upper::Real, min_abs::Real)
    for _ in 1:100_000
        x = lower .+ (upper - lower) .* rand(rng, d)
        minimum(abs.(x)) >= min_abs && return x
    end
    error("failed to sample min-abs box initial condition")
end

function sample_box_min_norm(rng::AbstractRNG, lower::AbstractVector, upper::AbstractVector, min_norm::Real)
    for _ in 1:100_000
        x = Float64.(lower) .+ (Float64.(upper) .- Float64.(lower)) .* rand(rng, length(lower))
        norm(x) >= min_norm && return x
    end
    error("failed to sample min-norm box initial condition")
end

function sample_annulus(rng::AbstractRNG, rlo::Real, rhi::Real)
    radius = rlo + (rhi - rlo) * rand(rng)
    theta = 2pi * rand(rng)
    return [radius * cos(theta), radius * sin(theta)]
end

function sample_duffing_ic(rng::AbstractRNG, Q::Real)
    theta = 2pi * rand(rng)
    u = rand(rng)
    a = sqrt((0.75 * Q)^2 + u * (Q^2 - (0.75 * Q)^2))
    return [a * cos(theta), a * sin(theta)]
end

pendulum_energy(x1::Real, x2::Real) = 0.5 * x2^2 - cos(x1)

function sample_pendulum_ic(rng::AbstractRNG, p::AbstractDict)
    x1_min = Float64(p["x1_min"])
    x1_max = Float64(p["x1_max"])
    x2_min = Float64(p["x2_min"])
    x2_max = Float64(p["x2_max"])
    threshold = Float64(p["energy_threshold"])
    for _ in 1:1_000_000
        x1 = x1_min + (x1_max - x1_min) * rand(rng)
        x2 = x2_min + (x2_max - x2_min) * rand(rng)
        pendulum_energy(x1, x2) < threshold && return [x1, x2]
    end
    error("failed to sample pendulum initial condition")
end

function structured_grid(bounds::Vector{Tuple{Float64,Float64}}, n::Int)
    d = length(bounds)
    k = ceil(Int, n^(1 / d))
    values = [collect(range(lo, hi; length = k)) for (lo, hi) in bounds]
    X0 = Matrix{Float64}(undef, d, n)
    index = 1
    if d == 3
        for x in values[1], y in values[2], z in values[3]
            index > n && return X0
            X0[:, index] = [x, y, z]
            index += 1
        end
    else
        error("structured_grid currently supports 3D")
    end
    return X0
end

function initial_conditions(spec::StandardObjectSpec)
    rng = MersenneTwister(spec.seed)
    X0 = Matrix{Float64}(undef, spec.state_dim, spec.num_trajectories)
    p = spec.params
    if spec.object_id == "linear_diagonal"
        for r in axes(X0, 2)
            X0[:, r] = sample_box_min_abs(rng, spec.state_dim, p["ic_lower"], p["ic_upper"], p["ic_min_abs"])
        end
    elseif spec.object_id == "linear_rotation_contraction_2d"
        for r in axes(X0, 2)
            X0[:, r] = sample_annulus(rng, p["radius_lower"], p["radius_upper"])
        end
    elseif spec.object_id == "damped_linear_oscillator"
        for r in axes(X0, 2)
            X0[:, r] = sample_box_min_norm(rng, p["ic_lower"], p["ic_upper"], p["ic_min_norm"])
        end
    elseif startswith(spec.object_id, "duffing_")
        for r in axes(X0, 2)
            X0[:, r] = sample_duffing_ic(rng, p["Q"])
        end
    elseif spec.object_id == "lorenz63_standard"
        return structured_grid([(-12.0, 12.0), (-12.0, 12.0), (8.0, 32.0)], spec.num_trajectories)
    elseif spec.object_id == "rossler_standard"
        return structured_grid([(-8.0, 8.0), (-8.0, 8.0), (0.5, 8.0)], spec.num_trajectories)
    elseif spec.object_id == "nonlinear_pendulum_lusch2018"
        for r in axes(X0, 2)
            X0[:, r] = sample_pendulum_ic(rng, p)
        end
    else
        error("unknown object_id $(spec.object_id)")
    end
    return X0
end

function rk4_step(rhs!, x::Vector{Float64}, dt::Float64, p)
    k1 = similar(x)
    k2 = similar(x)
    k3 = similar(x)
    k4 = similar(x)
    tmp = similar(x)
    rhs!(k1, x, p)
    @. tmp = x + 0.5 * dt * k1
    rhs!(k2, tmp, p)
    @. tmp = x + 0.5 * dt * k2
    rhs!(k3, tmp, p)
    @. tmp = x + dt * k3
    rhs!(k4, tmp, p)
    @. x = x + (dt / 6.0) * (k1 + 2.0 * k2 + 2.0 * k3 + k4)
    return x
end

function dopri5_step(rhs!, x::Vector{Float64}, h::Float64, p)
    k1 = similar(x)
    k2 = similar(x)
    k3 = similar(x)
    k4 = similar(x)
    k5 = similar(x)
    k6 = similar(x)
    k7 = similar(x)
    tmp = similar(x)
    rhs!(k1, x, p)

    @. tmp = x + h * (1.0 / 5.0) * k1
    rhs!(k2, tmp, p)

    @. tmp = x + h * ((3.0 / 40.0) * k1 + (9.0 / 40.0) * k2)
    rhs!(k3, tmp, p)

    @. tmp = x + h * ((44.0 / 45.0) * k1 - (56.0 / 15.0) * k2 + (32.0 / 9.0) * k3)
    rhs!(k4, tmp, p)

    @. tmp = x + h * ((19372.0 / 6561.0) * k1 - (25360.0 / 2187.0) * k2 + (64448.0 / 6561.0) * k3 - (212.0 / 729.0) * k4)
    rhs!(k5, tmp, p)

    @. tmp = x + h * ((9017.0 / 3168.0) * k1 - (355.0 / 33.0) * k2 + (46732.0 / 5247.0) * k3 + (49.0 / 176.0) * k4 - (5103.0 / 18656.0) * k5)
    rhs!(k6, tmp, p)

    @. tmp = x + h * ((35.0 / 384.0) * k1 + (500.0 / 1113.0) * k3 + (125.0 / 192.0) * k4 - (2187.0 / 6784.0) * k5 + (11.0 / 84.0) * k6)
    rhs!(k7, tmp, p)

    y5 = similar(x)
    y4 = similar(x)
    @. y5 = x + h * ((35.0 / 384.0) * k1 + (500.0 / 1113.0) * k3 + (125.0 / 192.0) * k4 - (2187.0 / 6784.0) * k5 + (11.0 / 84.0) * k6)
    @. y4 = x + h * ((5179.0 / 57600.0) * k1 + (7571.0 / 16695.0) * k3 + (393.0 / 640.0) * k4 - (92097.0 / 339200.0) * k5 + (187.0 / 2100.0) * k6 + (1.0 / 40.0) * k7)
    return y5, y5 .- y4
end

function adaptive_dopri5_advance!(rhs!, x::Vector{Float64}, t0::Float64, t1::Float64, p::AbstractDict)
    reltol = Float64(p["reltol"])
    abstol = Float64(p["abstol"])
    max_h = Float64(p["max_internal_step"])
    t = t0
    h = min(max_h, t1 - t0)
    accepted = 0
    rejected = 0
    while t < t1 - 10eps(Float64) * max(1.0, abs(t1))
        h = min(h, max_h, t1 - t)
        y, err = dopri5_step(rhs!, x, h, p)
        scale = maximum(@. abstol + reltol * max(abs(x), abs(y)))
        err_norm = maximum(abs, err) / max(scale, eps(Float64))
        if err_norm <= 1.0 || h <= eps(Float64) * max(1.0, abs(t))
            x .= y
            t += h
            accepted += 1
            factor = err_norm == 0.0 ? 5.0 : min(5.0, max(0.2, 0.9 * err_norm^(-0.2)))
            h *= factor
        else
            rejected += 1
            factor = max(0.1, 0.9 * err_norm^(-0.25))
            h *= factor
        end
        accepted + rejected <= 10_000_000 || error("adaptive DOPRI5 exceeded step budget")
    end
    return accepted, rejected
end

function duffing_rhs!(dx, x, p)
    dx[1] = x[2]
    dx[2] = -p["delta"] * x[2] - p["alpha"] * x[1] - p["beta"] * x[1]^3
    return dx
end

function lorenz_rhs!(dx, x, p)
    sigma = p["sigma"]
    rho = p["rho"]
    beta = p["beta"]
    dx[1] = sigma * (x[2] - x[1])
    dx[2] = x[1] * (rho - x[3]) - x[2]
    dx[3] = x[1] * x[2] - beta * x[3]
    return dx
end

function rossler_rhs!(dx, x, p)
    a = p["a"]
    b = p["b"]
    c = p["c"]
    dx[1] = -x[2] - x[3]
    dx[2] = x[1] + a * x[2]
    dx[3] = b + x[3] * (x[1] - c)
    return dx
end

function pendulum_rhs!(dx, x, p)
    dx[1] = x[2]
    dx[2] = -sin(x[1])
    return dx
end

function propagate_linear_diagonal(spec::StandardObjectSpec, X0::Matrix{Float64})
    eigenvalues = Float64.(spec.params["eigenvalues"])
    X = Array{Float64}(undef, spec.num_trajectories, spec.trajectory_length + 1, spec.state_dim)
    for r in 1:spec.num_trajectories
        x0 = X0[:, r]
        for m in 0:spec.trajectory_length
            t = m * spec.dt
            @inbounds for j in 1:spec.state_dim
                X[r, m + 1, j] = x0[j] * exp(eigenvalues[j] * t)
            end
        end
    end
    return X
end

function propagate_rotation(spec::StandardObjectSpec, X0::Matrix{Float64})
    gamma = Float64(spec.params["gamma"])
    omega = Float64(spec.params["omega"])
    rho = exp(-gamma * spec.dt)
    c = cos(omega * spec.dt)
    s = sin(omega * spec.dt)
    X = Array{Float64}(undef, spec.num_trajectories, spec.trajectory_length + 1, 2)
    for r in 1:spec.num_trajectories
        x1, x2 = X0[:, r]
        X[r, 1, 1] = x1
        X[r, 1, 2] = x2
        for m in 1:spec.trajectory_length
            y1 = rho * (c * x1 - s * x2)
            y2 = rho * (s * x1 + c * x2)
            x1, x2 = y1, y2
            X[r, m + 1, 1] = x1
            X[r, m + 1, 2] = x2
        end
    end
    return X
end

function oscillator_matrix(gamma::Float64, omega0::Float64, dt::Float64)
    A = [0.0 1.0; -omega0^2 -2.0 * gamma]
    return exp(A * dt)
end

function propagate_oscillator(spec::StandardObjectSpec, X0::Matrix{Float64})
    F = oscillator_matrix(Float64(spec.params["gamma"]), Float64(spec.params["omega0"]), spec.dt)
    X = Array{Float64}(undef, spec.num_trajectories, spec.trajectory_length + 1, 2)
    for r in 1:spec.num_trajectories
        x = copy(X0[:, r])
        X[r, 1, :] = x
        for m in 1:spec.trajectory_length
            x = F * x
            X[r, m + 1, :] = x
        end
    end
    return X
end

function propagate_rk4_substep(spec::StandardObjectSpec, X0::Matrix{Float64}, rhs!, p::Dict{String,Any}; burn_in_time::Float64 = 0.0, internal_dt::Float64 = spec.dt)
    X = Array{Float64}(undef, spec.num_trajectories, spec.trajectory_length + 1, spec.state_dim)
    n_burn = round(Int, burn_in_time / internal_dt)
    n_sub = round(Int, spec.dt / internal_dt)
    abs(n_sub * internal_dt - spec.dt) <= 1.0e-12 || error("internal_dt must divide dt for $(spec.object_id)")
    for r in 1:spec.num_trajectories
        x = copy(X0[:, r])
        for _ in 1:n_burn
            rk4_step(rhs!, x, internal_dt, p)
        end
        X[r, 1, :] = x
        for m in 1:spec.trajectory_length
            for _ in 1:n_sub
                rk4_step(rhs!, x, internal_dt, p)
            end
            X[r, m + 1, :] = x
        end
    end
    return X
end

function propagate_adaptive_dopri5(spec::StandardObjectSpec, X0::Matrix{Float64}, rhs!, p::Dict{String,Any}; burn_in_time::Float64 = 0.0)
    X = Array{Float64}(undef, spec.num_trajectories, spec.trajectory_length + 1, spec.state_dim)
    total_accepted = 0
    total_rejected = 0
    for r in 1:spec.num_trajectories
        x = copy(X0[:, r])
        if burn_in_time > 0.0
            accepted, rejected = adaptive_dopri5_advance!(rhs!, x, 0.0, burn_in_time, p)
            total_accepted += accepted
            total_rejected += rejected
        end
        X[r, 1, :] = x
        t = 0.0
        for m in 1:spec.trajectory_length
            accepted, rejected = adaptive_dopri5_advance!(rhs!, x, t, t + spec.dt, p)
            total_accepted += accepted
            total_rejected += rejected
            t += spec.dt
            X[r, m + 1, :] = x
        end
    end
    spec.params["accepted_steps"] = total_accepted
    spec.params["rejected_steps"] = total_rejected
    spec.params["integrator"] = "adaptive_dopri5_local"
    return X
end

function generate_clean_state(spec::StandardObjectSpec)
    X0 = initial_conditions(spec)
    if spec.object_id == "linear_diagonal"
        X = propagate_linear_diagonal(spec, X0)
    elseif spec.object_id == "linear_rotation_contraction_2d"
        X = propagate_rotation(spec, X0)
    elseif spec.object_id == "damped_linear_oscillator"
        X = propagate_oscillator(spec, X0)
    elseif startswith(spec.object_id, "duffing_")
        X = propagate_adaptive_dopri5(spec, X0, duffing_rhs!, spec.params)
    elseif spec.object_id == "lorenz63_standard"
        X = propagate_adaptive_dopri5(spec, X0, lorenz_rhs!, spec.params; burn_in_time = Float64(spec.params["burn_in_time"]))
    elseif spec.object_id == "rossler_standard"
        X = propagate_adaptive_dopri5(spec, X0, rossler_rhs!, spec.params; burn_in_time = Float64(spec.params["burn_in_time"]))
    elseif spec.object_id == "nonlinear_pendulum_lusch2018"
        X = propagate_rk4_substep(spec, X0, pendulum_rhs!, spec.params)
    else
        error("unknown object_id $(spec.object_id)")
    end
    return X0, X
end

function train_signal_power(X::Array{Float64,3}, spec::StandardObjectSpec)
    view_train = @view X[1:spec.train_count, :, :]
    powers = Vector{Float64}(undef, size(X, 3))
    for j in eachindex(powers)
        powers[j] = mean(abs2, @view view_train[:, :, j])
    end
    return powers
end

function noisy_observation(X32::Array{Float32,3}, powers::Vector{Float64}, snr_db::Float64, seed::Integer)
    rng = MersenneTwister(seed)
    Z = copy(X32)
    for j in axes(Z, 3)
        sigma = sqrt(powers[j] / 10.0^(snr_db / 10.0))
        @inbounds for i in axes(Z, 1), m in axes(Z, 2)
            Z[i, m, j] += Float32(sigma * randn(rng))
        end
    end
    return Z
end

function empirical_snr_db(X::Array{Float32,3}, Z::Array{Float32,3}, spec::StandardObjectSpec)
    result = Dict{String,Float64}()
    for j in axes(X, 3)
        signal_power = mean(abs2, @view X[1:spec.train_count, :, j])
        noise_sum = 0.0
        n = 0
        @inbounds for r in 1:spec.train_count, m in axes(X, 2)
            noise = Float64(Z[r, m, j] - X[r, m, j])
            noise_sum += noise * noise
            n += 1
        end
        noise_power = noise_sum / n
        result[string(j)] = 10.0 * log10(Float64(signal_power) / max(Float64(noise_power), eps(Float64)))
    end
    return result
end

function basic_diagnostics(X::Array{Float64,3}, spec::StandardObjectSpec)
    return Dict(
        "all_finite" => all(isfinite, X),
        "max_abs_state" => maximum(abs, X),
        "mean_abs_state" => mean(abs, X),
        "state_min_by_channel" => [minimum(@view X[:, :, j]) for j in axes(X, 3)],
        "state_max_by_channel" => [maximum(@view X[:, :, j]) for j in axes(X, 3)],
        "shape" => collect(size(X)),
        "one_step_counts" => one_step_counts(spec),
        "rollout_counts" => rollout_counts(spec),
    )
end

function object_paths(profile::Symbol, spec::StandardObjectSpec)
    if profile == :smoke
        root = project_path("runs", "smoke_tests", STANDARD_ODES_V1, spec.object_id)
        return Dict(
            "processed_jld2" => joinpath(root, "processed_tensors.jld2"),
            "manifest" => joinpath(root, "manifest.json"),
        )
    end
    return Dict(
        "processed_jld2" => project_path("data", "processed", STANDARD_ODES_V1, spec.object_id, "processed_tensors.jld2"),
        "manifest" => project_path("data", "manifests", STANDARD_ODES_V1, spec.object_id, "manifest.json"),
    )
end

function save_object(profile::Symbol, spec::StandardObjectSpec, X0::Matrix{Float64}, X::Array{Float64,3}, roles::Vector{String})
    paths = object_paths(profile, spec)
    powers = train_signal_power(X, spec)
    X32 = Float32.(X)
    Z_clean = copy(X32)
    Z_5 = noisy_observation(X32, powers, 5.0, spec.seed + 50_005)
    Z_15 = noisy_observation(X32, powers, 15.0, spec.seed + 50_015)
    Y_clean = copy(X32)
    time_grid = Float32.(collect(0:spec.trajectory_length) .* spec.dt)
    ensure_parent_dir(paths["processed_jld2"])
    JLD2.jldsave(
        paths["processed_jld2"];
        dataset_id = STANDARD_ODES_V1,
        object_id = spec.object_id,
        dtype = "Float32",
        array_layout = "trajectory_by_time_by_channel",
        time_grid,
        initial_conditions = Float32.(X0),
        state_clean = X32,
        observation_clean = Z_clean,
        observation_noise_5db = Z_5,
        observation_noise_15db = Z_15,
        target_clean = Y_clean,
        split_roles = roles,
        params = spec.params,
    )
    diagnostics = basic_diagnostics(X, spec)
    diagnostics["empirical_snr_db"] = Dict(
        "5db" => empirical_snr_db(X32, Z_5, spec),
        "15db" => empirical_snr_db(X32, Z_15, spec),
    )
    manifest = Dict(
        "dataset_id" => STANDARD_ODES_V1,
        "profile" => string(profile),
        "object_id" => spec.object_id,
        "family" => spec.family,
        "dtype" => "Float32",
        "array_layout" => "trajectory_by_time_by_channel",
        "state_dim" => spec.state_dim,
        "dt" => spec.dt,
        "trajectory_length" => spec.trajectory_length,
        "num_snapshots" => spec.trajectory_length + 1,
        "num_trajectories" => spec.num_trajectories,
        "split_counts" => role_counts(roles),
        "horizons" => spec.horizons,
        "noise_levels_db" => collect(STANDARD_NOISE_LEVELS_DB),
        "target_policy" => "clean_state",
        "params" => spec.params,
        "seed" => spec.seed,
        "generated_files" => Dict("processed_jld2" => paths["processed_jld2"]),
        "diagnostics" => diagnostics,
    )
    write_json(paths["manifest"], manifest)
    return manifest
end

function release_paths(profile::Symbol)
    if profile == :smoke
        return Dict(
            "manifest" => project_path("runs", "smoke_tests", STANDARD_ODES_V1, "release_manifest.json"),
            "summary" => project_path("runs", "smoke_tests", STANDARD_ODES_V1, "summary.csv"),
            "log" => project_path("runs", "smoke_tests", STANDARD_ODES_V1, "generation.log"),
        )
    end
    return Dict(
        "manifest" => project_path("data", "releases", STANDARD_ODES_V1, "metadata", "release_manifest.json"),
        "summary" => project_path("reports", "v1_core", STANDARD_ODES_V1, "tables", "generation_summary.csv"),
        "log" => project_path("reports", "v1_core", STANDARD_ODES_V1, "logs", "generation.log"),
    )
end

function write_summary_csv(path::AbstractString, manifests::Vector{Dict{String,Any}})
    ensure_parent_dir(path)
    open(path, "w") do io
        println(io, "object_id,state_dim,dt,trajectory_length,num_snapshots,num_trajectories,train,val,test,train_one_step,max_abs_state,all_finite,processed_jld2")
        for m in manifests
            split = m["split_counts"]
            diag = m["diagnostics"]
            one_step = diag["one_step_counts"]
            @printf(
                io,
                "%s,%d,%.8g,%d,%d,%d,%d,%d,%d,%d,%.9g,%s,%s\n",
                m["object_id"],
                m["state_dim"],
                m["dt"],
                m["trajectory_length"],
                m["num_snapshots"],
                m["num_trajectories"],
                split["train"],
                split["val"],
                split["test"],
                one_step["train"],
                diag["max_abs_state"],
                string(diag["all_finite"]),
                m["generated_files"]["processed_jld2"],
            )
        end
    end
    return path
end

function write_generation_log(path::AbstractString, release_manifest::Dict{String,Any})
    ensure_parent_dir(path)
    open(path, "w") do io
        println(io, "dataset_id: ", release_manifest["dataset_id"])
        println(io, "profile: ", release_manifest["profile"])
        println(io, "generated_at: ", release_manifest["generated_at"])
        println(io, "object_count: ", length(release_manifest["objects"]))
        println(io, "all_passed: ", release_manifest["all_passed"])
        println(io, "total_state_vectors: ", release_manifest["totals"]["state_vectors"])
        println(io, "total_train_one_step_pairs: ", release_manifest["totals"]["train_one_step_pairs"])
        for obj in release_manifest["objects"]
            println(io, obj["object_id"], ": ", obj["generated_files"]["processed_jld2"])
        end
    end
    return path
end

function generate_standard_odes_v1(profile::Symbol)
    specs = profile_specs(profile)
    manifests = Dict{String,Any}[]
    for spec in specs
        @printf("generating %s (%s): R=%d M=%d d=%d\n", spec.object_id, profile, spec.num_trajectories, spec.trajectory_length, spec.state_dim)
        X0, X = generate_clean_state(spec)
        roles = split_roles(spec)
        manifest = save_object(profile, spec, X0, X, roles)
        push!(manifests, manifest)
        @printf("  saved: %s\n", manifest["generated_files"]["processed_jld2"])
    end
    paths = release_paths(profile)
    totals = Dict(
        "state_vectors" => sum(m["num_trajectories"] * m["num_snapshots"] for m in manifests),
        "state_scalars" => sum(m["num_trajectories"] * m["num_snapshots"] * m["state_dim"] for m in manifests),
        "train_one_step_pairs" => sum(m["diagnostics"]["one_step_counts"]["train"] for m in manifests),
    )
    release_manifest = Dict(
        "dataset_id" => STANDARD_ODES_V1,
        "profile" => string(profile),
        "generated_at" => string(now()),
        "dtype" => "Float32",
        "object_count" => length(manifests),
        "noise_levels_db" => collect(STANDARD_NOISE_LEVELS_DB),
        "all_passed" => all(m["diagnostics"]["all_finite"] for m in manifests),
        "totals" => totals,
        "objects" => manifests,
    )
    write_json(paths["manifest"], release_manifest)
    write_summary_csv(paths["summary"], manifests)
    release_manifest["generated_files"] = Dict(
        "release_manifest" => paths["manifest"],
        "summary_csv" => paths["summary"],
        "generation_log" => paths["log"],
    )
    write_json(paths["manifest"], release_manifest)
    write_generation_log(paths["log"], release_manifest)
    return release_manifest
end
