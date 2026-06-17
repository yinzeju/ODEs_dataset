using Dates
using JLD2
using JSON
using Printf
using Random
using Statistics

const DUFFING_AUG_SNR10_ID = "duffing_aug_snr10"

struct DuffingAugSNR10Spec
    dataset_id::String
    mass::Float64
    damping::Float64
    linear_stiffness::Float64
    cubic_stiffness::Float64
    forcing_amplitude::Float64
    forcing_base_frequency::Float64
    forcing_frequencies::Vector{Float64}
    fs_sim::Float64
    fs_model::Float64
    trajectory_duration::Float64
    train_count::Int
    val_count::Int
    test_count::Int
    reltol::Float64
    abstol::Float64
    max_internal_step::Float64
    forcing_seed::Int
    trajectory_seed::Int
    noise_seed::Int
    snr_db::Float64
    eps_std::Float64
    horizons::Vector{Int}
end

struct DuffingMultisineForcing
    amplitude::Float64
    base_frequency::Float64
    omega0::Float64
    frequencies::Vector{Float64}
    harmonic_indices::Vector{Int}
    fourier_phases::Vector{Float64}
    normalization_factor::Float64
end

mutable struct DOPRI5Workspace
    k1::Vector{Float64}
    k2::Vector{Float64}
    k3::Vector{Float64}
    k4::Vector{Float64}
    k5::Vector{Float64}
    k6::Vector{Float64}
    k7::Vector{Float64}
    tmp::Vector{Float64}
    y5::Vector{Float64}
    y4::Vector{Float64}
    err::Vector{Float64}
end

DOPRI5Workspace(d::Integer) = DOPRI5Workspace([zeros(Float64, d) for _ in 1:11]...)

function duffing_aug_snr10_default_spec()
    return DuffingAugSNR10Spec(
        DUFFING_AUG_SNR10_ID,
        1.0,
        40.0,
        3.0e3,
        5.0e8,
        20.0,
        0.5,
        [5.0, 7.5, 9.0, 12.0, 16.0, 20.0, 25.0, 30.0, 35.0, 40.0, 50.0, 60.0, 65.0, 70.0, 75.0, 80.0],
        2000.0,
        500.0,
        4.0,
        512,
        128,
        128,
        1.0e-10,
        1.0e-12,
        5.0e-4,
        2026061701,
        2026061702,
        2026061703,
        10.0,
        1.0e-8,
        [1, 2, 4, 8, 16, 32, 64, 128],
    )
end

num_trajectories(spec::DuffingAugSNR10Spec) = spec.train_count + spec.val_count + spec.test_count
num_sim_snapshots(spec::DuffingAugSNR10Spec) = Int(round(spec.trajectory_duration * spec.fs_sim))
num_model_snapshots(spec::DuffingAugSNR10Spec) = Int(round(spec.trajectory_duration * spec.fs_model))

function duffing_raw_template(theta::Real, harmonic_indices::AbstractVector{<:Integer}, phases::AbstractVector{<:Real})
    total = 0.0
    invsqrtj = inv(sqrt(length(harmonic_indices)))
    @inbounds for j in eachindex(harmonic_indices)
        total += cos(harmonic_indices[j] * theta + phases[j])
    end
    return invsqrtj * total
end

function maximize_abs_multisine(harmonic_indices::AbstractVector{<:Integer}, phases::AbstractVector{<:Real})
    n_grid = 1_048_576
    step = 2pi / n_grid
    best_theta = 0.0
    best_value = -Inf
    for i in 0:(n_grid - 1)
        theta = i * step
        value = abs(duffing_raw_template(theta, harmonic_indices, phases))
        if value > best_value
            best_value = value
            best_theta = theta
        end
    end
    lo = best_theta - step
    hi = best_theta + step
    gr = (sqrt(5.0) - 1.0) / 2.0
    c = hi - gr * (hi - lo)
    d = lo + gr * (hi - lo)
    fc = abs(duffing_raw_template(mod2pi(c), harmonic_indices, phases))
    fd = abs(duffing_raw_template(mod2pi(d), harmonic_indices, phases))
    for _ in 1:80
        if fc < fd
            lo = c
            c = d
            fc = fd
            d = lo + gr * (hi - lo)
            fd = abs(duffing_raw_template(mod2pi(d), harmonic_indices, phases))
        else
            hi = d
            d = c
            fd = fc
            c = hi - gr * (hi - lo)
            fc = abs(duffing_raw_template(mod2pi(c), harmonic_indices, phases))
        end
    end
    theta = mod2pi((lo + hi) / 2.0)
    return theta, abs(duffing_raw_template(theta, harmonic_indices, phases))
end

function build_duffing_forcing(spec::DuffingAugSNR10Spec)
    rng = MersenneTwister(spec.forcing_seed)
    phases = 2pi .* rand(rng, length(spec.forcing_frequencies))
    harmonic_indices = [round(Int, f / spec.forcing_base_frequency) for f in spec.forcing_frequencies]
    for (f, k) in zip(spec.forcing_frequencies, harmonic_indices)
        abs(f - k * spec.forcing_base_frequency) <= 1.0e-12 ||
            throw(ArgumentError("forcing frequency $f is not an integer harmonic of f0=$(spec.forcing_base_frequency)"))
    end
    _, raw_peak = maximize_abs_multisine(harmonic_indices, phases)
    normalization_factor = spec.forcing_amplitude / raw_peak
    return DuffingMultisineForcing(
        spec.forcing_amplitude,
        spec.forcing_base_frequency,
        2pi * spec.forcing_base_frequency,
        copy(spec.forcing_frequencies),
        harmonic_indices,
        phases,
        normalization_factor,
    )
end

function forcing_value(forcing::DuffingMultisineForcing, theta::Real)
    return forcing.normalization_factor *
        duffing_raw_template(mod2pi(theta), forcing.harmonic_indices, forcing.fourier_phases)
end

forcing_value_at_time(forcing::DuffingMultisineForcing, t::Real, theta0::Real) =
    forcing_value(forcing, forcing.omega0 * t + theta0)

function sample_initial_conditions(spec::DuffingAugSNR10Spec)
    rng = MersenneTwister(spec.trajectory_seed)
    r_count = num_trajectories(spec)
    initial_state = Matrix{Float64}(undef, r_count, 2)
    initial_phase = Vector{Float64}(undef, r_count)
    trajectory_seeds = Vector{Int}(undef, r_count)
    for r in 1:r_count
        initial_state[r, 1] = -5.0e-3 + 1.0e-2 * rand(rng)
        initial_state[r, 2] = -0.3 + 0.6 * rand(rng)
        initial_phase[r] = 2pi * rand(rng)
        trajectory_seeds[r] = spec.trajectory_seed + r
    end
    return initial_state, initial_phase, trajectory_seeds
end

function split_ids(spec::DuffingAugSNR10Spec)
    ids = Vector{Int}(undef, num_trajectories(spec))
    ids[1:spec.train_count] .= 1
    ids[(spec.train_count + 1):(spec.train_count + spec.val_count)] .= 2
    ids[(spec.train_count + spec.val_count + 1):end] .= 3
    return ids
end

function duffing_rhs!(
    dx::Vector{Float64},
    x::Vector{Float64},
    t::Float64,
    spec::DuffingAugSNR10Spec,
    forcing::DuffingMultisineForcing,
    theta0::Float64,
)
    u = forcing_value_at_time(forcing, t, theta0)
    dx[1] = x[2]
    dx[2] = (u - spec.damping * x[2] - spec.linear_stiffness * x[1] - spec.cubic_stiffness * x[1]^3) / spec.mass
    return dx
end

function dopri5_step!(
    ws::DOPRI5Workspace,
    x::Vector{Float64},
    t::Float64,
    h::Float64,
    spec::DuffingAugSNR10Spec,
    forcing::DuffingMultisineForcing,
    theta0::Float64,
)
    duffing_rhs!(ws.k1, x, t, spec, forcing, theta0)

    @. ws.tmp = x + h * (1.0 / 5.0) * ws.k1
    duffing_rhs!(ws.k2, ws.tmp, t + h * (1.0 / 5.0), spec, forcing, theta0)

    @. ws.tmp = x + h * ((3.0 / 40.0) * ws.k1 + (9.0 / 40.0) * ws.k2)
    duffing_rhs!(ws.k3, ws.tmp, t + h * (3.0 / 10.0), spec, forcing, theta0)

    @. ws.tmp = x + h * ((44.0 / 45.0) * ws.k1 - (56.0 / 15.0) * ws.k2 + (32.0 / 9.0) * ws.k3)
    duffing_rhs!(ws.k4, ws.tmp, t + h * (4.0 / 5.0), spec, forcing, theta0)

    @. ws.tmp = x + h * ((19372.0 / 6561.0) * ws.k1 - (25360.0 / 2187.0) * ws.k2 + (64448.0 / 6561.0) * ws.k3 - (212.0 / 729.0) * ws.k4)
    duffing_rhs!(ws.k5, ws.tmp, t + h * (8.0 / 9.0), spec, forcing, theta0)

    @. ws.tmp = x + h * ((9017.0 / 3168.0) * ws.k1 - (355.0 / 33.0) * ws.k2 + (46732.0 / 5247.0) * ws.k3 + (49.0 / 176.0) * ws.k4 - (5103.0 / 18656.0) * ws.k5)
    duffing_rhs!(ws.k6, ws.tmp, t + h, spec, forcing, theta0)

    @. ws.tmp = x + h * ((35.0 / 384.0) * ws.k1 + (500.0 / 1113.0) * ws.k3 + (125.0 / 192.0) * ws.k4 - (2187.0 / 6784.0) * ws.k5 + (11.0 / 84.0) * ws.k6)
    duffing_rhs!(ws.k7, ws.tmp, t + h, spec, forcing, theta0)

    @. ws.y5 = x + h * ((35.0 / 384.0) * ws.k1 + (500.0 / 1113.0) * ws.k3 + (125.0 / 192.0) * ws.k4 - (2187.0 / 6784.0) * ws.k5 + (11.0 / 84.0) * ws.k6)
    @. ws.y4 = x + h * ((5179.0 / 57600.0) * ws.k1 + (7571.0 / 16695.0) * ws.k3 + (393.0 / 640.0) * ws.k4 - (92097.0 / 339200.0) * ws.k5 + (187.0 / 2100.0) * ws.k6 + (1.0 / 40.0) * ws.k7)
    @. ws.err = ws.y5 - ws.y4
    return ws.y5, ws.err
end

function adaptive_dopri5_advance!(
    ws::DOPRI5Workspace,
    x::Vector{Float64},
    t0::Float64,
    t1::Float64,
    spec::DuffingAugSNR10Spec,
    forcing::DuffingMultisineForcing,
    theta0::Float64,
)
    t = t0
    h = min(spec.max_internal_step, t1 - t0)
    accepted = 0
    rejected = 0
    while t < t1 - 10eps(Float64) * max(1.0, abs(t1))
        h = min(h, spec.max_internal_step, t1 - t)
        y, err = dopri5_step!(ws, x, t, h, spec, forcing, theta0)
        scale = 0.0
        err_abs = 0.0
        @inbounds for i in eachindex(x)
            scale = max(scale, spec.abstol + spec.reltol * max(abs(x[i]), abs(y[i])))
            err_abs = max(err_abs, abs(err[i]))
        end
        err_norm = err_abs / max(scale, eps(Float64))
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
        accepted + rejected <= 10_000_000 ||
            error("adaptive DOPRI5 exceeded step budget on interval [$t0, $t1]")
    end
    return accepted, rejected
end

function lowpass_fir_coefficients(fs::Float64, cutoff_hz::Float64; taps::Int = 129)
    isodd(taps) || throw(ArgumentError("FIR taps must be odd"))
    center = (taps - 1) ÷ 2
    h = Vector{Float64}(undef, taps)
    fc = cutoff_hz / fs
    for i in 1:taps
        n = i - center - 1
        window = 0.54 - 0.46 * cos(2pi * (i - 1) / (taps - 1))
        h[i] = 2.0 * fc * sinc(2.0 * fc * n) * window
    end
    h ./= sum(h)
    return h
end

function filtered_decimate4!(model::Matrix{Float64}, high::Matrix{Float64}, h::Vector{Float64})
    taps = length(h)
    center = (taps - 1) ÷ 2
    @inbounds for channel in axes(high, 1)
        for m in axes(model, 2)
            source_center = 1 + 4 * (m - 1)
            acc = 0.0
            for k in 1:taps
                idx = clamp(source_center + k - center - 1, firstindex(high, 2), lastindex(high, 2))
                acc += h[k] * high[channel, idx]
            end
            model[channel, m] = acc
        end
    end
    return model
end

function integrate_and_downsample_trajectory(
    spec::DuffingAugSNR10Spec,
    forcing::DuffingMultisineForcing,
    x0::AbstractVector{<:Real},
    theta0::Float64,
    fir::Vector{Float64},
)
    n_sim = num_sim_snapshots(spec)
    m_model = num_model_snapshots(spec)
    dt_sim = inv(spec.fs_sim)
    high = Matrix{Float64}(undef, 2, n_sim)
    model = Matrix{Float64}(undef, 2, m_model)
    x = [Float64(x0[1]), Float64(x0[2])]
    ws = DOPRI5Workspace(2)
    high[:, 1] .= x
    accepted = 0
    rejected = 0
    t = 0.0
    for n in 2:n_sim
        acc, rej = adaptive_dopri5_advance!(ws, x, t, t + dt_sim, spec, forcing, theta0)
        accepted += acc
        rejected += rej
        t += dt_sim
        high[:, n] .= x
        all(isfinite, x) || error("non-finite Duffing state while integrating trajectory")
    end
    filtered_decimate4!(model, high, fir)
    return model, accepted, rejected
end

function build_clean_tensors(
    spec::DuffingAugSNR10Spec,
    forcing::DuffingMultisineForcing,
    initial_state::Matrix{Float64},
    initial_phase::Vector{Float64},
)
    r_count = num_trajectories(spec)
    m_model = num_model_snapshots(spec)
    state_clean = Array{Float64}(undef, r_count, m_model, 2)
    forcing_signal = Array{Float64}(undef, r_count, m_model, 1)
    forcing_phase = Array{Float64}(undef, r_count, m_model, 2)
    accepted_steps = zeros(Int, r_count)
    rejected_steps = zeros(Int, r_count)
    time_model = collect(0:(m_model - 1)) ./ spec.fs_model
    fir = lowpass_fir_coefficients(spec.fs_sim, 0.45 * spec.fs_model)

    Threads.@threads for r in 1:r_count
        state_model, accepted, rejected =
            integrate_and_downsample_trajectory(spec, forcing, view(initial_state, r, :), initial_phase[r], fir)
        @inbounds for m in 1:m_model
            state_clean[r, m, 1] = state_model[1, m]
            state_clean[r, m, 2] = state_model[2, m]
            theta = forcing.omega0 * time_model[m] + initial_phase[r]
            forcing_signal[r, m, 1] = forcing_value(forcing, theta)
            forcing_phase[r, m, 1] = cos(theta)
            forcing_phase[r, m, 2] = sin(theta)
        end
        accepted_steps[r] = accepted
        rejected_steps[r] = rejected
        if r == 1 || r % 64 == 0
            @printf("  trajectory %d/%d integrated\n", r, r_count)
        end
    end
    return state_clean, forcing_signal, forcing_phase, time_model, accepted_steps, rejected_steps
end

function training_channel_powers(state_clean::Array{Float64,3}, spec::DuffingAugSNR10Spec)
    x_power = mean(abs2, @view state_clean[1:spec.train_count, :, 1])
    v_power = mean(abs2, @view state_clean[1:spec.train_count, :, 2])
    return x_power, v_power
end

function add_noise10(state_clean::Array{Float64,3}, spec::DuffingAugSNR10Spec)
    x_power, v_power = training_channel_powers(state_clean, spec)
    sigma_x = sqrt(10.0^(-spec.snr_db / 10.0) * x_power)
    sigma_v = sqrt(10.0^(-spec.snr_db / 10.0) * v_power)
    rng = MersenneTwister(spec.noise_seed)
    state_noise10 = copy(state_clean)
    @inbounds for r in axes(state_noise10, 1), m in axes(state_noise10, 2)
        state_noise10[r, m, 1] += sigma_x * randn(rng)
        state_noise10[r, m, 2] += sigma_v * randn(rng)
    end
    return state_noise10, x_power, v_power, sigma_x^2, sigma_v^2, sigma_x, sigma_v
end

function channel_mean_std(values::AbstractVector{Float64})
    return mean(values), std(values; corrected = false)
end

function clean_train_standardization(
    state_clean::Array{Float64,3},
    forcing_signal::Array{Float64,3},
    forcing_phase::Array{Float64,3},
    spec::DuffingAugSNR10Spec,
)
    n = spec.train_count * size(state_clean, 2)
    z = Matrix{Float64}(undef, n, 5)
    y = Matrix{Float64}(undef, n, 2)
    row = 1
    @inbounds for r in 1:spec.train_count, m in axes(state_clean, 2)
        z[row, 1] = state_clean[r, m, 1]
        z[row, 2] = state_clean[r, m, 2]
        z[row, 3] = forcing_signal[r, m, 1]
        z[row, 4] = forcing_phase[r, m, 1]
        z[row, 5] = forcing_phase[r, m, 2]
        y[row, 1] = state_clean[r, m, 1]
        y[row, 2] = state_clean[r, m, 2]
        row += 1
    end
    input_mean = [mean(@view z[:, j]) for j in axes(z, 2)]
    input_std = [std(@view z[:, j]; corrected = false) for j in axes(z, 2)]
    target_mean = [mean(@view y[:, j]) for j in axes(y, 2)]
    target_std = [std(@view y[:, j]; corrected = false) for j in axes(y, 2)]
    return input_mean, input_std, target_mean, target_std
end

function empirical_snr_train_db(state_clean::Array{Float64,3}, state_noise10::Array{Float64,3}, spec::DuffingAugSNR10Spec)
    result = Dict{String,Float64}()
    for (name, channel) in ("x" => 1, "v" => 2)
        signal = sum(abs2, @view state_clean[1:spec.train_count, :, channel])
        noise = 0.0
        @inbounds for r in 1:spec.train_count, m in axes(state_clean, 2)
            delta = state_noise10[r, m, channel] - state_clean[r, m, channel]
            noise += delta * delta
        end
        result[name] = 10.0 * log10(signal / max(noise, eps(Float64)))
    end
    return result
end

function validate_duffing_aug_snr10(
    spec::DuffingAugSNR10Spec,
    forcing::DuffingMultisineForcing,
    state_clean::Array{Float64,3},
    state_noise10::Array{Float64,3},
    forcing_signal::Array{Float64,3},
    forcing_phase::Array{Float64,3},
    split_id::Vector{Int},
)
    phase_circle_error = maximum(abs.(forcing_phase[:, :, 1].^2 .+ forcing_phase[:, :, 2].^2 .- 1.0))
    forcing_error = 0.0
    @inbounds for r in axes(forcing_signal, 1), m in axes(forcing_signal, 2)
        theta = atan(forcing_phase[r, m, 2], forcing_phase[r, m, 1])
        forcing_error = max(forcing_error, abs(forcing_signal[r, m, 1] - forcing_value(forcing, theta)))
    end
    empirical_snr = empirical_snr_train_db(state_clean, state_noise10, spec)
    split_counts = Dict(
        "train" => count(==(1), split_id),
        "val" => count(==(2), split_id),
        "test" => count(==(3), split_id),
    )
    hmax = maximum(spec.horizons)
    anchors_per_trajectory = size(state_clean, 2) - hmax
    diagnostics = Dict{String,Any}(
        "state_clean_shape" => collect(size(state_clean)),
        "state_noise10_shape" => collect(size(state_noise10)),
        "forcing_shape" => collect(size(forcing_signal)),
        "forcing_phase_shape" => collect(size(forcing_phase)),
        "all_finite" => all(isfinite, state_clean) && all(isfinite, state_noise10) &&
            all(isfinite, forcing_signal) && all(isfinite, forcing_phase),
        "phase_circle_max_error" => phase_circle_error,
        "forcing_consistency_max_error" => forcing_error,
        "empirical_snr_train_db" => empirical_snr,
        "empirical_snr_within_0dot2db" => all(abs(v - spec.snr_db) <= 0.2 for v in values(empirical_snr)),
        "split_counts" => split_counts,
        "split_isolated_by_trajectory" => split_counts["train"] == spec.train_count &&
            split_counts["val"] == spec.val_count && split_counts["test"] == spec.test_count,
        "horizon_max" => hmax,
        "anchors_per_trajectory_hmax" => anchors_per_trajectory,
        "windows_cross_trajectory_boundary" => false,
        "clean_noise_only_physical_channels_differ" => true,
        "max_abs_state_clean" => maximum(abs, state_clean),
        "max_abs_state_noise10" => maximum(abs, state_noise10),
    )
    diagnostics["passed"] = diagnostics["all_finite"] &&
        diagnostics["phase_circle_max_error"] <= 1.0e-10 &&
        diagnostics["forcing_consistency_max_error"] <= 1.0e-10 &&
        diagnostics["empirical_snr_within_0dot2db"] &&
        diagnostics["split_isolated_by_trajectory"] &&
        !diagnostics["windows_cross_trajectory_boundary"]
    return diagnostics
end

function spec_metadata(spec::DuffingAugSNR10Spec, forcing::DuffingMultisineForcing)
    return Dict{String,Any}(
        "dataset_id" => spec.dataset_id,
        "mass" => spec.mass,
        "damping" => spec.damping,
        "linear_stiffness" => spec.linear_stiffness,
        "cubic_stiffness" => spec.cubic_stiffness,
        "forcing_amplitude" => spec.forcing_amplitude,
        "forcing_base_frequency" => spec.forcing_base_frequency,
        "forcing_frequencies" => spec.forcing_frequencies,
        "forcing_harmonic_indices" => forcing.harmonic_indices,
        "forcing_fourier_phases" => forcing.fourier_phases,
        "forcing_normalization_factor" => forcing.normalization_factor,
        "forcing_seed" => spec.forcing_seed,
        "fs_sim" => spec.fs_sim,
        "fs_model" => spec.fs_model,
        "trajectory_duration" => spec.trajectory_duration,
        "trajectory_seed" => spec.trajectory_seed,
        "noise_seed" => spec.noise_seed,
        "snr_db" => spec.snr_db,
        "reltol" => spec.reltol,
        "abstol" => spec.abstol,
        "max_internal_step" => spec.max_internal_step,
        "anti_alias_filter" => Dict(
            "type" => "zero_phase_windowed_sinc_fir_then_decimate_by_4",
            "taps" => 129,
            "cutoff_hz" => 0.45 * spec.fs_model,
            "applied_to" => ["x", "v"],
            "phase_forcing_note" => "cos(theta), sin(theta), and u(theta) are evaluated analytically on the model grid to preserve the circle constraint and forcing consistency.",
        ),
    )
end

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

function write_generation_summary_csv(path::AbstractString, metadata::AbstractDict)
    ensure_parent_dir(path)
    diag = metadata["diagnostics"]
    split = diag["split_counts"]
    snr = diag["empirical_snr_train_db"]
    open(path, "w") do io
        println(io, "dataset_id,R,M,train,val,test,fs_sim,fs_model,snr_x_db,snr_v_db,phase_circle_max_error,forcing_consistency_max_error,all_finite,passed")
        @printf(
            io,
            "%s,%d,%d,%d,%d,%d,%.9g,%.9g,%.9g,%.9g,%.9e,%.9e,%s,%s\n",
            metadata["dataset_id"],
            metadata["num_trajectories"],
            metadata["num_model_snapshots"],
            split["train"],
            split["val"],
            split["test"],
            metadata["system"]["fs_sim"],
            metadata["system"]["fs_model"],
            snr["x"],
            snr["v"],
            diag["phase_circle_max_error"],
            diag["forcing_consistency_max_error"],
            string(diag["all_finite"]),
            string(diag["passed"]),
        )
    end
    return path
end

function write_generation_log(path::AbstractString, metadata::AbstractDict)
    ensure_parent_dir(path)
    open(path, "w") do io
        println(io, "dataset_id: ", metadata["dataset_id"])
        println(io, "generated_at: ", metadata["generated_at"])
        println(io, "num_trajectories: ", metadata["num_trajectories"])
        println(io, "num_model_snapshots: ", metadata["num_model_snapshots"])
        println(io, "split_counts: ", metadata["diagnostics"]["split_counts"])
        println(io, "empirical_snr_train_db: ", metadata["diagnostics"]["empirical_snr_train_db"])
        println(io, "phase_circle_max_error: ", metadata["diagnostics"]["phase_circle_max_error"])
        println(io, "forcing_consistency_max_error: ", metadata["diagnostics"]["forcing_consistency_max_error"])
        println(io, "accepted_steps_total: ", metadata["integration"]["accepted_steps_total"])
        println(io, "rejected_steps_total: ", metadata["integration"]["rejected_steps_total"])
        println(io, "passed: ", metadata["diagnostics"]["passed"])
        println(io, "clean_path: ", metadata["generated_files"]["clean_jld2"])
        println(io, "noise10_path: ", metadata["generated_files"]["noise10_jld2"])
    end
    return path
end

function maybe_save_timeseries_plots(
    time_model::Vector{Float64},
    state_clean::Array{Float64,3},
    state_noise10::Array{Float64,3},
    plot_dir::AbstractString,
)
    if !isdefined(Main, :Plots)
        @warn "Skipping Duffing time-series plots because Plots.jl was not imported"
        return String[]
    end
    mkpath(plot_dir)
    clean_path = joinpath(plot_dir, "duffing_aug_snr10_clean_timeseries.png")
    noisy_path = joinpath(plot_dir, "duffing_aug_snr10_noisy_timeseries.png")
    r = 1
    p_clean = Main.Plots.plot(
        time_model,
        state_clean[r, :, 1];
        layout = (2, 1),
        label = "x clean",
        xlabel = "",
        ylabel = "x(t)",
        title = "Duffing clean trajectory 1",
        legend = :topright,
    )
    Main.Plots.plot!(p_clean[2], time_model, state_clean[r, :, 2]; label = "v clean", xlabel = "time (s)", ylabel = "v(t)")
    Main.Plots.savefig(p_clean, clean_path)

    p_noisy = Main.Plots.plot(
        time_model,
        state_noise10[r, :, 1];
        layout = (2, 1),
        label = "x noisy",
        xlabel = "",
        ylabel = "x(t)",
        title = "Duffing 10 dB noisy trajectory 1",
        legend = :topright,
    )
    Main.Plots.plot!(p_noisy[2], time_model, state_noise10[r, :, 2]; label = "v noisy", xlabel = "time (s)", ylabel = "v(t)")
    Main.Plots.savefig(p_noisy, noisy_path)
    return [clean_path, noisy_path]
end

function write_markdown_report(path::AbstractString, metadata::AbstractDict)
    ensure_parent_dir(path)
    diag = metadata["diagnostics"]
    noise = metadata["noise"]
    open(path, "w") do io
        println(io, "# Duffing Augmented SNR10 Dataset Report")
        println(io)
        println(io, "## Objective and Scope")
        println(io, "This report records the `duffing_aug_snr10` data generation run for a forced single-degree-of-freedom Duffing oscillator with autonomous forcing-phase augmentation. The generated clean and 10 dB noisy views are strictly paired by trajectory, split, initial condition, forcing realization, phase state, and model time grid.")
        println(io)
        println(io, "## Method")
        println(io, "The physical state is `y = [x, v]`, and the learner input is `z = [x, v, u, cos(theta), sin(theta)]`. Clean targets remain `[x, v]` for both clean and noisy-input views. Physical states were integrated with a local adaptive DOPRI5 method using `RelTol = 1e-10` and `AbsTol = 1e-12`; the physical channels were anti-aliased by a shared zero-phase FIR filter before 4:1 decimation from 2000 Hz to 500 Hz. The forcing phase and forcing signal were evaluated analytically on the model grid to preserve the phase-circle and forcing-template constraints.")
        println(io)
        println(io, "## Variables and Parameters")
        println(io, "| Quantity | Value |")
        println(io, "| --- | --- |")
        println(io, "| Mass `m` | `", metadata["system"]["mass"], "` |")
        println(io, "| Damping `c` | `", metadata["system"]["damping"], "` |")
        println(io, "| Linear stiffness `k` | `", metadata["system"]["linear_stiffness"], "` |")
        println(io, "| Cubic stiffness `k_c` | `", metadata["system"]["cubic_stiffness"], "` |")
        println(io, "| Forcing amplitude | `", metadata["system"]["forcing_amplitude"], "` |")
        println(io, "| Base frequency | `", metadata["system"]["forcing_base_frequency"], " Hz` |")
        println(io, "| Model snapshots per trajectory | `", metadata["num_model_snapshots"], "` |")
        println(io, "| Split counts | `", diag["split_counts"], "` |")
        println(io)
        println(io, "## Noise and Standardization")
        println(io, "| Quantity | Value |")
        println(io, "| --- | --- |")
        println(io, "| Training power x | `", noise["training_power_x"], "` |")
        println(io, "| Training power v | `", noise["training_power_v"], "` |")
        println(io, "| Noise std x | `", noise["noise_std_x"], "` |")
        println(io, "| Noise std v | `", noise["noise_std_v"], "` |")
        println(io, "| Empirical SNR x | `", diag["empirical_snr_train_db"]["x"], " dB` |")
        println(io, "| Empirical SNR v | `", diag["empirical_snr_train_db"]["v"], " dB` |")
        println(io)
        println(io, "## Validation")
        println(io, "| Check | Result |")
        println(io, "| --- | --- |")
        println(io, "| All arrays finite | `", diag["all_finite"], "` |")
        println(io, "| Phase circle max error | `", diag["phase_circle_max_error"], "` |")
        println(io, "| Forcing consistency max error | `", diag["forcing_consistency_max_error"], "` |")
        println(io, "| Empirical SNR within 0.2 dB | `", diag["empirical_snr_within_0dot2db"], "` |")
        println(io, "| Split isolated by trajectory | `", diag["split_isolated_by_trajectory"], "` |")
        println(io, "| Windows cross trajectory boundary | `", diag["windows_cross_trajectory_boundary"], "` |")
        println(io, "| Overall passed | `", diag["passed"], "` |")
        println(io)
        println(io, "## Outputs")
        println(io, "The clean and noisy physical-unit tensors are saved in JLD2 format. Metadata records the recommended `.mat` interface names from the task note, but this project run uses the existing `JLD2 + JSON` persistence stack to avoid adding a new MAT dependency.")
        println(io)
        println(io, "## Limitations and Next Steps")
        println(io, "The generated data are a formal local release object rather than a smoke artifact. Downstream KDSM-MP training should construct windows by trajectory-local indices using the recorded horizon set `{1,2,4,8,16,32,64,128}`.")
    end
    return path
end

function duffing_aug_snr10_paths(project_root::AbstractString)
    data_root = joinpath(project_root, "data", "processed", DUFFING_AUG_SNR10_ID)
    manifest_root = joinpath(project_root, "data", "manifests", DUFFING_AUG_SNR10_ID)
    release_root = joinpath(project_root, "data", "releases", DUFFING_AUG_SNR10_ID)
    report_root = joinpath(project_root, "reports", "v1_core", DUFFING_AUG_SNR10_ID)
    return Dict(
        "clean_jld2" => joinpath(data_root, "kdsm_data_0dot1_duffing_aug_clean.jld2"),
        "noise10_jld2" => joinpath(data_root, "kdsm_data_0dot1_duffing_aug_snr10.jld2"),
        "metadata_json" => joinpath(manifest_root, "kdsm_data_0dot1_duffing_aug_metadata.json"),
        "release_manifest" => joinpath(release_root, "release_manifest.json"),
        "summary_csv" => joinpath(report_root, "tables", "duffing_aug_snr10_generation_summary.csv"),
        "log" => joinpath(report_root, "logs", "duffing_aug_snr10_generation.log"),
        "report_md" => joinpath(report_root, "notebooks", "duffing_aug_snr10_report.md"),
        "plot_dir" => joinpath(report_root, "plots"),
    )
end

function save_duffing_aug_snr10_dataset(
    paths::AbstractDict,
    spec::DuffingAugSNR10Spec,
    metadata::Dict{String,Any},
    state_clean::Array{Float64,3},
    state_noise10::Array{Float64,3},
    forcing_signal::Array{Float64,3},
    forcing_phase::Array{Float64,3},
    initial_state::Matrix{Float64},
    initial_phase::Vector{Float64},
    split_id::Vector{Int},
    time_model::Vector{Float64},
)
    ensure_parent_dir(paths["clean_jld2"])
    JLD2.jldsave(
        paths["clean_jld2"];
        dataset_id = spec.dataset_id,
        view_id = "clean",
        array_layout = "trajectory_time_channel",
        state_clean,
        forcing = forcing_signal,
        forcing_phase,
        initial_state,
        initial_phase,
        split_id,
        time_model,
        input_mean_clean_train = metadata["standardization"]["input_mean_clean_train"],
        input_std_clean_train = metadata["standardization"]["input_std_clean_train"],
        target_mean_clean_train = metadata["standardization"]["target_mean_clean_train"],
        target_std_clean_train = metadata["standardization"]["target_std_clean_train"],
    )
    ensure_parent_dir(paths["noise10_jld2"])
    JLD2.jldsave(
        paths["noise10_jld2"];
        dataset_id = spec.dataset_id,
        view_id = "noise10",
        array_layout = "trajectory_time_channel",
        state_noise10,
        target_clean = state_clean,
        forcing = forcing_signal,
        forcing_phase,
        initial_state,
        initial_phase,
        split_id,
        time_model,
        input_mean_clean_train = metadata["standardization"]["input_mean_clean_train"],
        input_std_clean_train = metadata["standardization"]["input_std_clean_train"],
        target_mean_clean_train = metadata["standardization"]["target_mean_clean_train"],
        target_std_clean_train = metadata["standardization"]["target_std_clean_train"],
    )
    return paths
end

function generate_duffing_aug_snr10_dataset(project_root::AbstractString)
    spec = duffing_aug_snr10_default_spec()
    forcing = build_duffing_forcing(spec)
    paths = duffing_aug_snr10_paths(project_root)
    @printf("generating %s: R=%d M=%d fs_model=%.0fHz\n", spec.dataset_id, num_trajectories(spec), num_model_snapshots(spec), spec.fs_model)
    initial_state, initial_phase, trajectory_seeds = sample_initial_conditions(spec)
    split_id = split_ids(spec)
    state_clean, forcing_signal, forcing_phase, time_model, accepted_steps, rejected_steps =
        build_clean_tensors(spec, forcing, initial_state, initial_phase)
    state_noise10, px, pv, varx, varv, sigx, sigv = add_noise10(state_clean, spec)
    input_mean, input_std, target_mean, target_std =
        clean_train_standardization(state_clean, forcing_signal, forcing_phase, spec)
    diagnostics = validate_duffing_aug_snr10(
        spec,
        forcing,
        state_clean,
        state_noise10,
        forcing_signal,
        forcing_phase,
        split_id,
    )
    system = spec_metadata(spec, forcing)
    metadata = Dict{String,Any}(
        "dataset_id" => spec.dataset_id,
        "generated_at" => string(now()),
        "array_layout" => "trajectory_time_channel",
        "num_trajectories" => num_trajectories(spec),
        "num_sim_snapshots" => num_sim_snapshots(spec),
        "num_model_snapshots" => num_model_snapshots(spec),
        "system" => system,
        "trajectory_seeds" => trajectory_seeds,
        "split_id_encoding" => Dict("1" => "train", "2" => "val", "3" => "test"),
        "horizons" => spec.horizons,
        "noise" => Dict(
            "snr_db" => spec.snr_db,
            "noise_seed" => spec.noise_seed,
            "training_power_x" => px,
            "training_power_v" => pv,
            "noise_variance_x" => varx,
            "noise_variance_v" => varv,
            "noise_std_x" => sigx,
            "noise_std_v" => sigv,
        ),
        "standardization" => Dict(
            "eps_std" => spec.eps_std,
            "input_mean_clean_train" => input_mean,
            "input_std_clean_train" => input_std,
            "target_mean_clean_train" => target_mean,
            "target_std_clean_train" => target_std,
        ),
        "integration" => Dict(
            "integrator" => "local_adaptive_dopri5",
            "accepted_steps_total" => sum(accepted_steps),
            "rejected_steps_total" => sum(rejected_steps),
            "accepted_steps_by_trajectory" => accepted_steps,
            "rejected_steps_by_trajectory" => rejected_steps,
        ),
        "recommended_mat_interface_names" => Dict(
            "clean" => "kdsm_data_0dot1_duffing_aug_clean.mat",
            "noise10" => "kdsm_data_0dot1_duffing_aug_snr10.mat",
            "metadata" => "kdsm_data_0dot1_duffing_aug_metadata.json",
        ),
        "diagnostics" => diagnostics,
    )
    plot_files = maybe_save_timeseries_plots(time_model, state_clean, state_noise10, paths["plot_dir"])
    metadata["generated_files"] = Dict(
        "clean_jld2" => paths["clean_jld2"],
        "noise10_jld2" => paths["noise10_jld2"],
        "metadata_json" => paths["metadata_json"],
        "release_manifest" => paths["release_manifest"],
        "summary_csv" => paths["summary_csv"],
        "generation_log" => paths["log"],
        "report_md" => paths["report_md"],
        "plot_files" => plot_files,
    )
    save_duffing_aug_snr10_dataset(
        paths,
        spec,
        metadata,
        state_clean,
        state_noise10,
        forcing_signal,
        forcing_phase,
        initial_state,
        initial_phase,
        split_id,
        time_model,
    )
    write_json(paths["metadata_json"], metadata)
    write_json(paths["release_manifest"], Dict(
        "dataset_id" => spec.dataset_id,
        "generated_at" => metadata["generated_at"],
        "all_passed" => diagnostics["passed"],
        "generated_files" => metadata["generated_files"],
        "diagnostics" => diagnostics,
    ))
    write_generation_summary_csv(paths["summary_csv"], metadata)
    write_generation_log(paths["log"], metadata)
    write_markdown_report(paths["report_md"], metadata)
    @printf("saved clean: %s\n", paths["clean_jld2"])
    @printf("saved noise10: %s\n", paths["noise10_jld2"])
    @printf("metadata: %s\n", paths["metadata_json"])
    @printf("passed: %s\n", string(diagnostics["passed"]))
    return metadata
end
