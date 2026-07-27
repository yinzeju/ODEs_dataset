using JLD2
using JSON
using Printf
using Random
using Statistics
using Dates
using FFTW

const CLDHF_PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(CLDHF_PROJECT_ROOT, "src", "generators", "duffing_aug_snr10_generator.jl"))

const CLDHF_BASE = "duffing_hf"
const CLDHF_ROLES = ("augaut", "addc", "bilinc")

struct CLDHFSpec
    mass::Float64
    damping::Float64
    linear_stiffness::Float64
    cubic_stiffness::Float64
    stiffness_depth::Float64
    force_amplitude::Float64
    base_frequency_hz::Float64
    frequencies_hz::Vector{Float64}
    harmonic_weights::Vector{Float64}
    fs_sim::Float64
    fs_model::Float64
    duration::Float64
    max_internal_step::Float64
    reltol::Float64
    abstol::Float64
    filter_taps::Int
    filter_cutoff_hz::Float64
    phase_seed::Int
    fourier_phase_seed::Int
    train_count::Int
    val_count::Int
    test_count::Int
    position_range::NTuple{2,Float64}
    velocity_range::NTuple{2,Float64}
    state_abs_limit::Float64
end

struct CLDHFWeightedForcing
    amplitude::Float64
    base_frequency::Float64
    omega0::Float64
    frequencies::Vector{Float64}
    harmonic_indices::Vector{Int}
    fourier_phases::Vector{Float64}
    harmonic_weights::Vector{Float64}
    normalized_weights::Vector{Float64}
    normalization_factor::Float64
end

cldhf_trajectory_count(spec::CLDHFSpec) = spec.train_count + spec.val_count + spec.test_count
cldhf_sim_samples(spec::CLDHFSpec) = round(Int, spec.duration * spec.fs_sim)
cldhf_state_samples(spec::CLDHFSpec) = round(Int, spec.duration * spec.fs_model)
cldhf_transition_count(spec::CLDHFSpec) = cldhf_state_samples(spec) - 1
cldhf_tau(spec::CLDHFSpec) = inv(spec.fs_model)

function cldhf_load_spec(config_path::AbstractString)
    config = JSON.parsefile(config_path)
    time = config["time"]
    source = config["source"]
    base = config["base"]
    initial = config["initial_conditions"]
    split = config["split"]
    spec = CLDHFSpec(
        Float64(base["mass"]),
        Float64(base["damping"]),
        Float64(base["linear_stiffness"]),
        Float64(base["cubic_stiffness"]),
        Float64(base["bilinear_relative_stiffness_depth"]),
        Float64(source["additive_force_amplitude"]),
        Float64(source["base_frequency_hz"]),
        Float64.(source["frequencies_hz"]),
        Float64.(source["harmonic_weights"]),
        Float64(time["sim_sample_rate"]),
        Float64(time["model_sample_rate"]),
        Float64(time["trajectory_duration"]),
        Float64(time["max_internal_step"]),
        Float64(time["rtol"]),
        Float64(time["atol"]),
        Int(time["anti_alias_taps"]),
        Float64(time["anti_alias_cutoff_hz"]),
        Int(source["phase_initial_seed"]),
        Int(source["fourier_phase_seed"]),
        Int(split["train_trajectories"]),
        Int(split["validation_trajectories"]),
        Int(split["test_trajectories"]),
        (Float64(initial["position_range"][1]), Float64(initial["position_range"][2])),
        (Float64(initial["velocity_range"][1]), Float64(initial["velocity_range"][2])),
        Float64(base["state_abs_limit"]),
    )
    cldhf_sim_samples(spec) % cldhf_state_samples(spec) == 0 ||
        error("simulation and model sample counts must have an integer resample ratio")
    cldhf_sim_samples(spec) == 8_000 || error("DUF-HF profile must have 8,000 simulation samples")
    cldhf_state_samples(spec) == 2_000 || error("DUF-HF profile must have 2,000 state samples")
    cldhf_transition_count(spec) == 1_999 || error("DUF-HF profile must have 1,999 transitions")
    length(spec.frequencies_hz) == length(spec.harmonic_weights) ||
        error("each DUF-HF source frequency must have one harmonic weight")
    all(>(0.0), spec.harmonic_weights) || error("DUF-HF harmonic weights must be positive")
    maximum(spec.frequencies_hz) < spec.fs_model / 2 || error("forcing exceeds the model-grid Nyquist frequency")
    return config, spec
end

function cldhf_weighted_raw_template(
    theta::Real,
    harmonic_indices::AbstractVector{<:Integer},
    phases::AbstractVector{<:Real},
    normalized_weights::AbstractVector{<:Real},
)
    total = 0.0
    @inbounds for index in eachindex(harmonic_indices, phases, normalized_weights)
        total += normalized_weights[index] * cos(harmonic_indices[index] * theta + phases[index])
    end
    return total
end

function cldhf_weighted_peak(
    harmonic_indices::Vector{Int},
    phases::Vector{Float64},
    normalized_weights::Vector{Float64},
)
    grid_count = 1_048_576
    grid_step = 2pi / grid_count
    best_theta = 0.0
    best_value = -Inf
    for grid_index in 0:(grid_count - 1)
        theta = grid_index * grid_step
        value = abs(cldhf_weighted_raw_template(theta, harmonic_indices, phases, normalized_weights))
        if value > best_value
            best_value = value
            best_theta = theta
        end
    end

    lower = best_theta - grid_step
    upper = best_theta + grid_step
    golden_ratio = (sqrt(5.0) - 1.0) / 2.0
    left = upper - golden_ratio * (upper - lower)
    right = lower + golden_ratio * (upper - lower)
    left_value = abs(cldhf_weighted_raw_template(mod2pi(left), harmonic_indices, phases, normalized_weights))
    right_value = abs(cldhf_weighted_raw_template(mod2pi(right), harmonic_indices, phases, normalized_weights))
    for _ in 1:80
        if left_value < right_value
            lower = left
            left = right
            left_value = right_value
            right = lower + golden_ratio * (upper - lower)
            right_value = abs(cldhf_weighted_raw_template(mod2pi(right), harmonic_indices, phases, normalized_weights))
        else
            upper = right
            right = left
            right_value = left_value
            left = upper - golden_ratio * (upper - lower)
            left_value = abs(cldhf_weighted_raw_template(mod2pi(left), harmonic_indices, phases, normalized_weights))
        end
    end
    return max(left_value, right_value)
end

function cldhf_build_forcing(spec::CLDHFSpec)
    rng = MersenneTwister(spec.fourier_phase_seed)
    phases = 2pi .* rand(rng, length(spec.frequencies_hz))
    harmonic_indices = [round(Int, frequency / spec.base_frequency_hz) for frequency in spec.frequencies_hz]
    for (frequency, harmonic) in zip(spec.frequencies_hz, harmonic_indices)
        abs(frequency - harmonic * spec.base_frequency_hz) <= 1.0e-12 ||
            error("forcing frequency $(frequency) is not a harmonic of $(spec.base_frequency_hz) Hz")
    end
    normalized_weights = spec.harmonic_weights ./ sqrt(sum(abs2, spec.harmonic_weights))
    raw_peak = cldhf_weighted_peak(harmonic_indices, phases, normalized_weights)
    return CLDHFWeightedForcing(
        1.0,
        spec.base_frequency_hz,
        2pi * spec.base_frequency_hz,
        copy(spec.frequencies_hz),
        harmonic_indices,
        phases,
        copy(spec.harmonic_weights),
        normalized_weights,
        inv(raw_peak),
    )
end

function forcing_value(forcing::CLDHFWeightedForcing, theta::Real)
    raw = cldhf_weighted_raw_template(
        mod2pi(theta),
        forcing.harmonic_indices,
        forcing.fourier_phases,
        forcing.normalized_weights,
    )
    return forcing.normalization_factor * raw
end

forcing_value_at_time(forcing::CLDHFWeightedForcing, time::Real, initial_phase::Real) =
    forcing_value(forcing, forcing.omega0 * time + initial_phase)

function cldhf_with_stiffness_depth(spec::CLDHFSpec, stiffness_depth::Real)
    return CLDHFSpec(
        spec.mass,
        spec.damping,
        spec.linear_stiffness,
        spec.cubic_stiffness,
        Float64(stiffness_depth),
        spec.force_amplitude,
        spec.base_frequency_hz,
        copy(spec.frequencies_hz),
        copy(spec.harmonic_weights),
        spec.fs_sim,
        spec.fs_model,
        spec.duration,
        spec.max_internal_step,
        spec.reltol,
        spec.abstol,
        spec.filter_taps,
        spec.filter_cutoff_hz,
        spec.phase_seed,
        spec.fourier_phase_seed,
        spec.train_count,
        spec.val_count,
        spec.test_count,
        spec.position_range,
        spec.velocity_range,
        spec.state_abs_limit,
    )
end

function cldhf_sample_initial_banks(spec::CLDHFSpec)
    trajectory_count = cldhf_trajectory_count(spec)
    rng = MersenneTwister(spec.phase_seed)
    initial_state = Matrix{Float64}(undef, trajectory_count, 2)
    initial_phase = Vector{Float64}(undef, trajectory_count)
    split_id = Vector{String}(undef, trajectory_count)
    for trajectory in 1:trajectory_count
        initial_state[trajectory, 1] = rand(rng) * (spec.position_range[2] - spec.position_range[1]) + spec.position_range[1]
        initial_state[trajectory, 2] = rand(rng) * (spec.velocity_range[2] - spec.velocity_range[1]) + spec.velocity_range[1]
        initial_phase[trajectory] = 2pi * rand(rng)
        split_id[trajectory] = trajectory <= spec.train_count ? "train" :
            (trajectory <= spec.train_count + spec.val_count ? "val" : "test")
    end
    initial_source = hcat(cos.(initial_phase), sin.(initial_phase))
    return initial_state, initial_phase, initial_source, split_id
end

function cldhf_rhs!(
    derivative::Vector{Float64},
    state::Vector{Float64},
    time::Float64,
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
    initial_phase::Float64,
    role::String,
)
    source_signal = forcing_value_at_time(forcing, time, initial_phase)
    derivative[1] = state[2]
    if role == "bilinc"
        stiffness = spec.linear_stiffness * (1 - spec.stiffness_depth * source_signal)
        derivative[2] = (-spec.damping * state[2] - stiffness * state[1] - spec.cubic_stiffness * state[1]^3) / spec.mass
    else
        force = spec.force_amplitude * source_signal
        derivative[2] = (force - spec.damping * state[2] - spec.linear_stiffness * state[1] - spec.cubic_stiffness * state[1]^3) / spec.mass
    end
    return derivative
end

function cldhf_dopri5_step!(
    workspace::DOPRI5Workspace,
    state::Vector{Float64},
    time::Float64,
    step::Float64,
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
    initial_phase::Float64,
    role::String,
)
    cldhf_rhs!(workspace.k1, state, time, spec, forcing, initial_phase, role)
    @. workspace.tmp = state + step * (1.0 / 5.0) * workspace.k1
    cldhf_rhs!(workspace.k2, workspace.tmp, time + step * (1.0 / 5.0), spec, forcing, initial_phase, role)
    @. workspace.tmp = state + step * ((3.0 / 40.0) * workspace.k1 + (9.0 / 40.0) * workspace.k2)
    cldhf_rhs!(workspace.k3, workspace.tmp, time + step * (3.0 / 10.0), spec, forcing, initial_phase, role)
    @. workspace.tmp = state + step * ((44.0 / 45.0) * workspace.k1 - (56.0 / 15.0) * workspace.k2 + (32.0 / 9.0) * workspace.k3)
    cldhf_rhs!(workspace.k4, workspace.tmp, time + step * (4.0 / 5.0), spec, forcing, initial_phase, role)
    @. workspace.tmp = state + step * ((19372.0 / 6561.0) * workspace.k1 - (25360.0 / 2187.0) * workspace.k2 + (64448.0 / 6561.0) * workspace.k3 - (212.0 / 729.0) * workspace.k4)
    cldhf_rhs!(workspace.k5, workspace.tmp, time + step * (8.0 / 9.0), spec, forcing, initial_phase, role)
    @. workspace.tmp = state + step * ((9017.0 / 3168.0) * workspace.k1 - (355.0 / 33.0) * workspace.k2 + (46732.0 / 5247.0) * workspace.k3 + (49.0 / 176.0) * workspace.k4 - (5103.0 / 18656.0) * workspace.k5)
    cldhf_rhs!(workspace.k6, workspace.tmp, time + step, spec, forcing, initial_phase, role)
    @. workspace.tmp = state + step * ((35.0 / 384.0) * workspace.k1 + (500.0 / 1113.0) * workspace.k3 + (125.0 / 192.0) * workspace.k4 - (2187.0 / 6784.0) * workspace.k5 + (11.0 / 84.0) * workspace.k6)
    cldhf_rhs!(workspace.k7, workspace.tmp, time + step, spec, forcing, initial_phase, role)
    @. workspace.y5 = state + step * ((35.0 / 384.0) * workspace.k1 + (500.0 / 1113.0) * workspace.k3 + (125.0 / 192.0) * workspace.k4 - (2187.0 / 6784.0) * workspace.k5 + (11.0 / 84.0) * workspace.k6)
    @. workspace.y4 = state + step * ((5179.0 / 57600.0) * workspace.k1 + (7571.0 / 16695.0) * workspace.k3 + (393.0 / 640.0) * workspace.k4 - (92097.0 / 339200.0) * workspace.k5 + (187.0 / 2100.0) * workspace.k6 + (1.0 / 40.0) * workspace.k7)
    @. workspace.err = workspace.y5 - workspace.y4
    return workspace.y5, workspace.err
end

function cldhf_adaptive_advance!(
    workspace::DOPRI5Workspace,
    state::Vector{Float64},
    start_time::Float64,
    stop_time::Float64,
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
    initial_phase::Float64,
    role::String,
)
    time = start_time
    step = min(spec.max_internal_step, stop_time - start_time)
    accepted = 0
    rejected = 0
    while time < stop_time - 10eps(Float64) * max(1.0, abs(stop_time))
        step = min(step, spec.max_internal_step, stop_time - time)
        proposal, error_estimate = cldhf_dopri5_step!(workspace, state, time, step, spec, forcing, initial_phase, role)
        scale = 0.0
        error_abs = 0.0
        @inbounds for index in eachindex(state)
            scale = max(scale, spec.abstol + spec.reltol * max(abs(state[index]), abs(proposal[index])))
            error_abs = max(error_abs, abs(error_estimate[index]))
        end
        error_norm = error_abs / max(scale, eps(Float64))
        if error_norm <= 1.0 || step <= eps(Float64) * max(1.0, abs(time))
            state .= proposal
            time += step
            accepted += 1
            factor = error_norm == 0.0 ? 5.0 : min(5.0, max(0.2, 0.9 * error_norm^(-0.2)))
            step *= factor
        else
            rejected += 1
            step *= max(0.1, 0.9 * error_norm^(-0.25))
        end
        accepted + rejected <= 10_000_000 || error("DUF-HF integrator exceeded step budget")
    end
    return accepted, rejected
end

function cldhf_integrate_high(
    initial_state::AbstractVector{<:Real},
    initial_phase::Float64,
    role::String,
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
)
    sample_count = cldhf_sim_samples(spec)
    dt = inv(spec.fs_sim)
    high_state = Matrix{Float64}(undef, 2, sample_count)
    state = Float64[initial_state[1], initial_state[2]]
    workspace = DOPRI5Workspace(2)
    high_state[:, 1] .= state
    accepted_steps = 0
    rejected_steps = 0
    time = 0.0
    for sample in 2:sample_count
        accepted, rejected = cldhf_adaptive_advance!(workspace, state, time, time + dt, spec, forcing, initial_phase, role)
        accepted_steps += accepted
        rejected_steps += rejected
        time += dt
        all(isfinite, state) || error("non-finite DUF-HF state during integration")
        high_state[:, sample] .= state
    end
    return high_state, accepted_steps, rejected_steps
end

function cldhf_phase_source_model(
    initial_phase::Float64,
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
    filter_coefficients::Vector{Float64},
)
    high_count = cldhf_sim_samples(spec)
    model_count = cldhf_state_samples(spec)
    high = Matrix{Float64}(undef, 3, high_count)
    for sample in 1:high_count
        time = (sample - 1) / spec.fs_sim
        theta = forcing.omega0 * time + initial_phase
        high[1, sample] = cos(theta)
        high[2, sample] = sin(theta)
        high[3, sample] = forcing_value(forcing, theta)
    end
    filtered = Matrix{Float64}(undef, 3, model_count)
    filtered_decimate4!(filtered, high, filter_coefficients)
    source_state = Matrix{Float64}(undef, 2, model_count)
    source_signal = Vector{Float64}(undef, model_count)
    reconstruction_error = 0.0
    for sample in 1:model_count
        norm_q = hypot(filtered[1, sample], filtered[2, sample])
        norm_q > eps(Float64) || error("filtered DUF-HF phase state has zero norm")
        qc = filtered[1, sample] / norm_q
        qs = filtered[2, sample] / norm_q
        source_state[1, sample] = qc
        source_state[2, sample] = qs
        source_signal[sample] = forcing_value(forcing, atan(qs, qc))
        reconstruction_error = max(reconstruction_error, abs(source_signal[sample] - filtered[3, sample]))
    end
    return source_state, source_signal, reconstruction_error
end

function cldhf_exact_interval_fields(
    initial_phase::Float64,
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
)
    transition_count = cldhf_transition_count(spec)
    tau = cldhf_tau(spec)
    left = Vector{Float64}(undef, transition_count)
    middle = Vector{Float64}(undef, transition_count)
    average = Vector{Float64}(undef, transition_count)
    for transition in 1:transition_count
        theta = forcing.omega0 * ((transition - 1) * tau) + initial_phase
        left[transition] = forcing_value(forcing, theta)
        middle[transition] = forcing_value(forcing, theta + forcing.omega0 * tau / 2)
        accumulator = 0.0
        for index in eachindex(forcing.harmonic_indices)
            harmonic = forcing.harmonic_indices[index]
            phase = forcing.fourier_phases[index]
            accumulator += forcing.normalized_weights[index] * (
                sin(harmonic * (theta + forcing.omega0 * tau) + phase) -
                sin(harmonic * theta + phase)
            ) / (harmonic * forcing.omega0)
        end
        average[transition] = forcing.normalization_factor * accumulator / tau
    end
    return left, middle, average
end

function cldhf_integrate_and_resample(
    initial_state::Matrix{Float64},
    initial_phase::Vector{Float64},
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
)
    trajectory_count = size(initial_state, 1)
    state_count = cldhf_state_samples(spec)
    transition_count = cldhf_transition_count(spec)
    state_additive = Array{Float64}(undef, trajectory_count, state_count, 2)
    state_bilinear = Array{Float64}(undef, trajectory_count, state_count, 2)
    source_state = Array{Float64}(undef, trajectory_count, state_count, 2)
    source_signal = Array{Float64}(undef, trajectory_count, state_count, 1)
    control_left = Array{Float64}(undef, trajectory_count, transition_count, 1)
    control_mid = Array{Float64}(undef, trajectory_count, transition_count, 1)
    control_average = Array{Float64}(undef, trajectory_count, transition_count, 1)
    accepted_additive = zeros(Int, trajectory_count)
    rejected_additive = zeros(Int, trajectory_count)
    accepted_bilinear = zeros(Int, trajectory_count)
    rejected_bilinear = zeros(Int, trajectory_count)
    source_reconstruction_error = zeros(Float64, trajectory_count)
    filter_coefficients = lowpass_fir_coefficients(spec.fs_sim, spec.filter_cutoff_hz; taps = spec.filter_taps)

    Threads.@threads for trajectory in 1:trajectory_count
        high_additive, accepted_add, rejected_add = cldhf_integrate_high(
            @view(initial_state[trajectory, :]), initial_phase[trajectory], "addc", spec, forcing,
        )
        high_bilinear, accepted_bil, rejected_bil = cldhf_integrate_high(
            @view(initial_state[trajectory, :]), initial_phase[trajectory], "bilinc", spec, forcing,
        )
        model_additive = Matrix{Float64}(undef, 2, state_count)
        model_bilinear = Matrix{Float64}(undef, 2, state_count)
        filtered_decimate4!(model_additive, high_additive, filter_coefficients)
        filtered_decimate4!(model_bilinear, high_bilinear, filter_coefficients)
        phase_model, signal_model, reconstruction_error = cldhf_phase_source_model(
            initial_phase[trajectory], spec, forcing, filter_coefficients,
        )
        left, middle, average = cldhf_exact_interval_fields(initial_phase[trajectory], spec, forcing)
        @views state_additive[trajectory, :, :] .= permutedims(model_additive)
        @views state_bilinear[trajectory, :, :] .= permutedims(model_bilinear)
        @views source_state[trajectory, :, :] .= permutedims(phase_model)
        @views source_signal[trajectory, :, 1] .= signal_model
        @views control_left[trajectory, :, 1] .= left
        @views control_mid[trajectory, :, 1] .= middle
        @views control_average[trajectory, :, 1] .= average
        accepted_additive[trajectory] = accepted_add
        rejected_additive[trajectory] = rejected_add
        accepted_bilinear[trajectory] = accepted_bil
        rejected_bilinear[trajectory] = rejected_bil
        source_reconstruction_error[trajectory] = reconstruction_error
    end
    return (
        state_additive = state_additive,
        state_bilinear = state_bilinear,
        source_state = source_state,
        source_signal = source_signal,
        control_left = control_left,
        control_mid = control_mid,
        control_average = control_average,
        accepted_additive = accepted_additive,
        rejected_additive = rejected_additive,
        accepted_bilinear = accepted_bilinear,
        rejected_bilinear = rejected_bilinear,
        source_reconstruction_error = source_reconstruction_error,
        filter_coefficients = filter_coefficients,
    )
end

function cldhf_interval_quadrature_error(initial_phase::Float64, spec::CLDHFSpec, forcing::CLDHFWeightedForcing, exact_average::Float64)
    subdivisions = 2_000
    step = cldhf_tau(spec) / subdivisions
    integral = 0.0
    for index in 0:subdivisions
        weight = index == 0 || index == subdivisions ? 1.0 : (iseven(index) ? 2.0 : 4.0)
        integral += weight * forcing_value_at_time(forcing, index * step, initial_phase)
    end
    numerical_average = integral * step / (3 * cldhf_tau(spec))
    return abs(numerical_average - exact_average)
end

function cldhf_sensitivity_error(spec::CLDHFSpec)
    epsilon = 1.0e-6
    additive_error = 0.0
    bilinear_error = 0.0
    bilinear_sensitivities = Float64[]
    for x in ([0.002, -0.1], [-0.003, 0.2], [0.004, -0.15])
        additive = [x[2], (spec.force_amplitude * 0.2 - spec.damping * x[2] - spec.linear_stiffness * x[1] - spec.cubic_stiffness * x[1]^3) / spec.mass]
        additive_eps = [x[2], (spec.force_amplitude * (0.2 + epsilon) - spec.damping * x[2] - spec.linear_stiffness * x[1] - spec.cubic_stiffness * x[1]^3) / spec.mass]
        bilinear = [x[2], (-spec.damping * x[2] - spec.linear_stiffness * (1 - spec.stiffness_depth * 0.2) * x[1] - spec.cubic_stiffness * x[1]^3) / spec.mass]
        bilinear_eps = [x[2], (-spec.damping * x[2] - spec.linear_stiffness * (1 - spec.stiffness_depth * (0.2 + epsilon)) * x[1] - spec.cubic_stiffness * x[1]^3) / spec.mass]
        additive_fd = (additive_eps - additive) / epsilon
        bilinear_fd = (bilinear_eps - bilinear) / epsilon
        additive_error = max(additive_error, maximum(abs.(additive_fd .- [0.0, spec.force_amplitude / spec.mass])))
        expected_bilinear = [0.0, spec.stiffness_depth * spec.linear_stiffness * x[1] / spec.mass]
        bilinear_error = max(bilinear_error, maximum(abs.(bilinear_fd .- expected_bilinear)))
        push!(bilinear_sensitivities, bilinear_fd[2])
    end
    nonconstant = any(abs(value - first(bilinear_sensitivities)) > 1.0e-6 for value in bilinear_sensitivities[2:end])
    return additive_error, bilinear_error, nonconstant
end

function cldhf_split_counts(split_id::Vector{String})
    return Dict(split => count(==(split), split_id) for split in ("train", "val", "test"))
end

function cldhf_integrate_role_model(
    initial_state::AbstractMatrix{<:Real},
    initial_phase::AbstractVector{<:Real},
    role::String,
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
)
    trajectory_count = size(initial_state, 1)
    state_count = cldhf_state_samples(spec)
    state_model = Array{Float64}(undef, trajectory_count, state_count, 2)
    filter_coefficients = lowpass_fir_coefficients(
        spec.fs_sim,
        spec.filter_cutoff_hz;
        taps = spec.filter_taps,
    )
    Threads.@threads for trajectory in 1:trajectory_count
        high_state, _, _ = cldhf_integrate_high(
            @view(initial_state[trajectory, :]),
            initial_phase[trajectory],
            role,
            spec,
            forcing,
        )
        filtered_state = Matrix{Float64}(undef, 2, state_count)
        filtered_decimate4!(filtered_state, high_state, filter_coefficients)
        @views state_model[trajectory, :, :] .= permutedims(filtered_state)
    end
    return state_model
end

function cldhf_source_signal_model(
    initial_phase::AbstractVector{<:Real},
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
)
    trajectory_count = length(initial_phase)
    state_count = cldhf_state_samples(spec)
    source_signal = Array{Float64}(undef, trajectory_count, state_count, 1)
    filter_coefficients = lowpass_fir_coefficients(
        spec.fs_sim,
        spec.filter_cutoff_hz;
        taps = spec.filter_taps,
    )
    Threads.@threads for trajectory in eachindex(initial_phase)
        _, signal_model, _ = cldhf_phase_source_model(
            initial_phase[trajectory],
            spec,
            forcing,
            filter_coefficients,
        )
        @views source_signal[trajectory, :, 1] .= signal_model
    end
    return source_signal
end

function cldhf_bilinear_metrics(
    state_bilinear::AbstractArray{<:Real,3},
    state_additive::AbstractArray{<:Real,3},
    source_signal::AbstractArray{<:Real,3},
    spec::CLDHFSpec;
    high_frequency_cutoff_hz::Real = 20.0,
    continuous_window_seconds::Real = 0.5,
    continuous_window_stride_seconds::Real = 0.1,
    minimum_window_relative_rms::Real = 0.1,
)
    size(state_bilinear) == size(state_additive) ||
        error("bilinear and additive state tensors must have the same shape")
    size(state_bilinear, 1) == size(source_signal, 1) ||
        error("state and source trajectory counts must match")
    size(state_bilinear, 2) == size(source_signal, 2) ||
        error("state and source sample counts must match")

    trajectory_count = size(state_bilinear, 1)
    head_last = round(Int, spec.fs_model)
    tail_first = round(Int, 3 * spec.fs_model) + 1
    tail_range = tail_first:size(state_bilinear, 2)
    transition_range = 1:(size(state_bilinear, 2) - 1)
    tau = cldhf_tau(spec)
    persistence_ratio = Vector{Float64}(undef, trajectory_count)
    work_damping_ratio = Vector{Float64}(undef, trajectory_count)
    signed_work_damping_ratio = Vector{Float64}(undef, trajectory_count)
    tail_high_frequency_ratio = Vector{Float64}(undef, trajectory_count)
    minimum_window_rms = Vector{Float64}(undef, trajectory_count)
    minimum_window_relative_rms_values = Vector{Float64}(undef, trajectory_count)
    difference_squared = 0.0
    additive_squared = 0.0

    tail_sample_count = length(tail_range)
    frequency_step = spec.fs_model / tail_sample_count
    window_sample_count = round(Int, continuous_window_seconds * spec.fs_model)
    window_stride = round(Int, continuous_window_stride_seconds * spec.fs_model)
    window_sample_count > 0 || error("continuous-window sample count must be positive")
    window_stride > 0 || error("continuous-window stride must be positive")
    window_starts = collect(1:window_stride:(size(state_bilinear, 2) - window_sample_count + 1))
    isempty(window_starts) && error("continuous-window configuration exceeds trajectory length")
    for trajectory in 1:trajectory_count
        head_energy = 0.0
        tail_energy = 0.0
        @inbounds for sample in 1:head_last
            head_energy += state_bilinear[trajectory, sample, 1]^2 +
                state_bilinear[trajectory, sample, 2]^2
        end
        @inbounds for sample in tail_range
            tail_energy += state_bilinear[trajectory, sample, 1]^2 +
                state_bilinear[trajectory, sample, 2]^2
        end
        head_rms = sqrt(head_energy / head_last)
        tail_rms = sqrt(tail_energy / tail_sample_count)
        persistence_ratio[trajectory] = tail_rms / (head_rms + eps(Float64))

        bilinear_work = 0.0
        damping_loss = 0.0
        @inbounds for sample in transition_range
            position = state_bilinear[trajectory, sample, 1]
            velocity = state_bilinear[trajectory, sample, 2]
            control = source_signal[trajectory, sample, 1]
            bilinear_work += spec.stiffness_depth * spec.linear_stiffness * control * position * velocity
            damping_loss += spec.damping * velocity^2
        end
        bilinear_work *= tau
        damping_loss *= tau
        signed_work_damping_ratio[trajectory] = bilinear_work / (damping_loss + eps(Float64))
        work_damping_ratio[trajectory] = abs(bilinear_work) / (damping_loss + eps(Float64))

        velocity_tail = Float64.(@view state_bilinear[trajectory, tail_range, 2])
        tail_power = abs2.(rfft(velocity_tail))
        total_ac_power = sum(@view tail_power[2:end])
        high_frequency_power = 0.0
        @inbounds for frequency_index in eachindex(tail_power)
            frequency = (frequency_index - 1) * frequency_step
            if frequency > high_frequency_cutoff_hz
                high_frequency_power += tail_power[frequency_index]
            end
        end
        tail_high_frequency_ratio[trajectory] =
            high_frequency_power / (total_ac_power + eps(Float64))

        window_rms = Vector{Float64}(undef, length(window_starts))
        @inbounds for (window_index, window_start) in pairs(window_starts)
            window_stop = window_start + window_sample_count - 1
            window_energy = 0.0
            for sample in window_start:window_stop
                window_energy += state_bilinear[trajectory, sample, 1]^2 +
                    state_bilinear[trajectory, sample, 2]^2
            end
            window_rms[window_index] = sqrt(window_energy / window_sample_count)
        end
        minimum_window_rms[trajectory] = minimum(window_rms)
        minimum_window_relative_rms_values[trajectory] =
            minimum_window_rms[trajectory] / (median(window_rms) + eps(Float64))

        @inbounds for channel in axes(state_bilinear, 3), sample in axes(state_bilinear, 2)
            difference = state_bilinear[trajectory, sample, channel] -
                state_additive[trajectory, sample, channel]
            difference_squared += difference^2
            additive_squared += state_additive[trajectory, sample, channel]^2
        end
    end

    persistence_mask = (0.2 .<= persistence_ratio) .& (persistence_ratio .<= 5.0)
    window_persistence_mask =
        minimum_window_relative_rms_values .>= Float64(minimum_window_relative_rms)
    return Dict{String,Any}(
        "trajectory_count" => trajectory_count,
        "persistence_ratio_bounds" => [0.2, 5.0],
        "persistence_passing_fraction" => mean(persistence_mask),
        "persistence_ratio_quantiles" => quantile(persistence_ratio, [0.0, 0.25, 0.5, 0.75, 1.0]),
        "persistence_ratio_median" => median(persistence_ratio),
        "work_damping_abs_ratio_quantiles" => quantile(work_damping_ratio, [0.0, 0.25, 0.5, 0.75, 1.0]),
        "work_damping_abs_ratio_median" => median(work_damping_ratio),
        "work_damping_signed_ratio_median" => median(signed_work_damping_ratio),
        "bilinear_additive_relative_frobenius" =>
            sqrt(difference_squared) / (sqrt(additive_squared) + eps(Float64)),
        "tail_high_frequency_cutoff_hz" => Float64(high_frequency_cutoff_hz),
        "tail_high_frequency_energy_ratio_quantiles" =>
            quantile(tail_high_frequency_ratio, [0.0, 0.25, 0.5, 0.75, 1.0]),
        "tail_high_frequency_energy_ratio_median" => median(tail_high_frequency_ratio),
        "continuous_window_seconds" => Float64(continuous_window_seconds),
        "continuous_window_stride_seconds" => Float64(continuous_window_stride_seconds),
        "minimum_window_relative_rms_threshold" => Float64(minimum_window_relative_rms),
        "minimum_window_relative_rms_quantiles" =>
            quantile(minimum_window_relative_rms_values, [0.0, 0.25, 0.5, 0.75, 1.0]),
        "minimum_window_relative_rms_median" => median(minimum_window_relative_rms_values),
        "minimum_window_rms_median" => median(minimum_window_rms),
        "continuous_window_passing_fraction" => mean(window_persistence_mask),
        "state_max_abs" => maximum(abs, state_bilinear),
        "state_abs_limit" => spec.state_abs_limit,
        "all_finite" => all(isfinite, state_bilinear),
    )
end

function cldhf_bilinear_acceptance(metrics::AbstractDict, pilot_config::AbstractDict)
    persistence_bounds = Float64.(pilot_config["persistence_ratio_bounds"])
    work_bounds = Float64.(pilot_config["work_damping_ratio_bounds"])
    checks = Dict{String,Bool}(
        "all_finite" => Bool(metrics["all_finite"]),
        "state_within_domain" => metrics["state_max_abs"] <= metrics["state_abs_limit"],
        "persistence_fraction" =>
            metrics["persistence_passing_fraction"] >= Float64(pilot_config["minimum_passing_fraction"]),
        "median_persistence_in_bounds" =>
            persistence_bounds[1] <= metrics["persistence_ratio_median"] <= persistence_bounds[2],
        "work_damping_same_order" =>
            work_bounds[1] <= metrics["work_damping_abs_ratio_median"] <= work_bounds[2],
        "bilinear_distinct_from_additive" =>
            metrics["bilinear_additive_relative_frobenius"] >=
            Float64(pilot_config["minimum_bilinear_additive_relative_frobenius"]),
        "tail_high_frequency_visible" =>
            metrics["tail_high_frequency_energy_ratio_median"] >=
            Float64(pilot_config["minimum_tail_high_frequency_energy_ratio"]),
        "continuous_window_persistence" =>
            metrics["continuous_window_passing_fraction"] >=
            Float64(pilot_config["minimum_window_passing_fraction"]),
    )
    return all(values(checks)), checks
end

function cldhf_run_bilinear_pilot(project_root::AbstractString)
    config_path = joinpath(
        project_root,
        "configs",
        "releases",
        "controlled_lowdim_v1_duffing_hf.json",
    )
    config, spec = cldhf_load_spec(config_path)
    pilot_config = config["bilinear_pilot"]
    forcing = cldhf_build_forcing(spec)
    initial_state, initial_phase, _, _ = cldhf_sample_initial_banks(spec)
    pilot_count = min(Int(pilot_config["pilot_training_trajectories"]), spec.train_count)
    pilot_state = @view initial_state[1:pilot_count, :]
    pilot_phase = @view initial_phase[1:pilot_count]
    additive_state = cldhf_integrate_role_model(pilot_state, pilot_phase, "addc", spec, forcing)
    source_signal = cldhf_source_signal_model(pilot_phase, spec, forcing)

    records = Dict{String,Any}[]
    selected_depth = nothing
    selected_score = nothing
    for candidate in Float64.(pilot_config["candidate_relative_stiffness_depths"])
        candidate_spec = cldhf_with_stiffness_depth(spec, candidate)
        bilinear_state = cldhf_integrate_role_model(
            pilot_state,
            pilot_phase,
            "bilinc",
            candidate_spec,
            forcing,
        )
        metrics = cldhf_bilinear_metrics(
            bilinear_state,
            additive_state,
            source_signal,
            candidate_spec;
            high_frequency_cutoff_hz = Float64(pilot_config["tail_high_frequency_cutoff_hz"]),
            continuous_window_seconds = Float64(pilot_config["continuous_window_seconds"]),
            continuous_window_stride_seconds =
                Float64(pilot_config["continuous_window_stride_seconds"]),
            minimum_window_relative_rms =
                Float64(pilot_config["minimum_window_relative_rms"]),
        )
        passed, checks = cldhf_bilinear_acceptance(metrics, pilot_config)
        score = passed ? candidate : nothing
        push!(records, Dict(
            "relative_stiffness_depth" => candidate,
            "passed" => passed,
            "selection_score" => score,
            "checks" => checks,
            "metrics" => metrics,
        ))
        @printf(
            "  rho=%4.2f passed=%-5s persist=%.3f window=%.3f median_gamma=%.3g work/damp=%.3g hf_tail=%.3g state_max=%.3g\n",
            candidate,
            string(passed),
            metrics["persistence_passing_fraction"],
            metrics["continuous_window_passing_fraction"],
            metrics["persistence_ratio_median"],
            metrics["work_damping_abs_ratio_median"],
            metrics["tail_high_frequency_energy_ratio_median"],
            metrics["state_max_abs"],
        )
        if passed && isnothing(selected_depth)
            selected_depth = candidate
            selected_score = score
        end
    end

    output_path = joinpath(
        project_root,
        "runs",
        "smoke_tests",
        "controlled_lowdim_v1_duffing_hf_bilinear_window_pilot.json",
    )
    payload = Dict{String,Any}(
        "task" => "controlled_lowdim_v1_duffing_hf_bilinear_window_pilot",
        "profile" => "training_side_pilot",
        "pilot_trajectory_count" => pilot_count,
        "candidate_records" => records,
        "selected_relative_stiffness_depth" => selected_depth,
        "selection_rule" => "smallest_candidate_passing_all_physical_gates",
        "selected_score" => selected_score,
        "source_frequencies_hz" => forcing.frequencies,
        "source_harmonic_weights" => forcing.harmonic_weights,
        "output_path" => output_path,
    )
    cldhf_write_json(output_path, payload)
    isnothing(selected_depth) &&
        error("no DUF-HF bilinear pilot candidate passed the physical acceptance criteria")
    return payload
end

function cldhf_diagnostics(
    simulation,
    initial_phase::Vector{Float64},
    split_id::Vector{String},
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
    pilot_config::AbstractDict,
)
    phase_circle_error = maximum(abs.(simulation.source_state[:, :, 1].^2 .+ simulation.source_state[:, :, 2].^2 .- 1.0))
    direct_signal_error = 0.0
    for trajectory in axes(simulation.source_state, 1), sample in axes(simulation.source_state, 2)
        qc = simulation.source_state[trajectory, sample, 1]
        qs = simulation.source_state[trajectory, sample, 2]
        expected = forcing_value(forcing, atan(qs, qc))
        direct_signal_error = max(direct_signal_error, abs(simulation.source_signal[trajectory, sample, 1] - expected))
    end
    additive_sensitivity_error, bilinear_sensitivity_error, bilinear_nonconstant = cldhf_sensitivity_error(spec)
    source_peak = maximum(abs, simulation.source_signal)
    physical_peak = spec.force_amplitude * source_peak
    bilinear_stiffness =
        spec.linear_stiffness .* (1 .- spec.stiffness_depth .* simulation.source_signal)
    minimum_stiffness = minimum(bilinear_stiffness)
    maximum_stiffness = maximum(bilinear_stiffness)
    negative_stiffness_fraction = mean(bilinear_stiffness .< 0)
    additive_augaut_difference = 0.0
    quadrature_error = cldhf_interval_quadrature_error(
        initial_phase[1], spec, forcing, simulation.control_average[1, 1, 1],
    )
    counts = cldhf_split_counts(split_id)
    all_finite = all(isfinite, simulation.state_additive) && all(isfinite, simulation.state_bilinear) &&
        all(isfinite, simulation.source_state) && all(isfinite, simulation.source_signal) &&
        all(isfinite, simulation.control_average)
    state_bound = max(maximum(abs, simulation.state_additive), maximum(abs, simulation.state_bilinear))
    bilinear_metrics = cldhf_bilinear_metrics(
        simulation.state_bilinear,
        simulation.state_additive,
        simulation.source_signal,
        spec;
        high_frequency_cutoff_hz = Float64(pilot_config["tail_high_frequency_cutoff_hz"]),
        continuous_window_seconds = Float64(pilot_config["continuous_window_seconds"]),
        continuous_window_stride_seconds =
            Float64(pilot_config["continuous_window_stride_seconds"]),
        minimum_window_relative_rms =
            Float64(pilot_config["minimum_window_relative_rms"]),
    )
    bilinear_acceptance_passed, bilinear_acceptance_checks =
        cldhf_bilinear_acceptance(bilinear_metrics, pilot_config)
    stiffness_switching_passed = minimum_stiffness < 0 < maximum_stiffness
    passed = all_finite && state_bound <= spec.state_abs_limit && phase_circle_error <= 1.0e-12 &&
        direct_signal_error <= 1.0e-12 && quadrature_error <= 1.0e-10 &&
        additive_sensitivity_error <= 2.0e-4 && bilinear_sensitivity_error <= 2.0e-4 &&
        bilinear_nonconstant && bilinear_acceptance_passed && stiffness_switching_passed &&
        counts["train"] == spec.train_count &&
        counts["val"] == spec.val_count && counts["test"] == spec.test_count
    return Dict{String,Any}(
        "passed" => passed,
        "all_finite" => all_finite,
        "split_counts" => counts,
        "state_additive_shape" => collect(size(simulation.state_additive)),
        "state_bilinear_shape" => collect(size(simulation.state_bilinear)),
        "transition_count" => cldhf_transition_count(spec),
        "state_sample_count" => cldhf_state_samples(spec),
        "phase_circle_max_error" => phase_circle_error,
        "source_signal_reconstruction_max_error" => direct_signal_error,
        "source_filter_reconstruction_max_error" => maximum(simulation.source_reconstruction_error),
        "source_sampled_peak_abs" => source_peak,
        "source_configured_peak_abs" => 1.0,
        "physical_forcing_configured_peak_abs" => spec.force_amplitude,
        "interval_average_quadrature_error" => quadrature_error,
        "frequency_nyquist_passed" => maximum(spec.frequencies_hz) < spec.fs_model / 2,
        "additive_augaut_max_difference" => additive_augaut_difference,
        "bilinear_minimum_linear_stiffness" => minimum_stiffness,
        "bilinear_maximum_linear_stiffness" => maximum_stiffness,
        "bilinear_negative_stiffness_fraction" => negative_stiffness_fraction,
        "bilinear_stiffness_switching_passed" => stiffness_switching_passed,
        "additive_sensitivity_max_error" => additive_sensitivity_error,
        "bilinear_sensitivity_max_error" => bilinear_sensitivity_error,
        "bilinear_sensitivity_nonconstant" => bilinear_nonconstant,
        "bilinear_physical_acceptance_passed" => bilinear_acceptance_passed,
        "bilinear_physical_acceptance_checks" => bilinear_acceptance_checks,
        "bilinear_physical_diagnostics" => bilinear_metrics,
        "state_max_abs" => state_bound,
        "state_within_configured_domain" => state_bound <= spec.state_abs_limit,
        "integrator" => "local_adaptive_dopri5",
        "accepted_steps_additive_total" => sum(simulation.accepted_additive),
        "rejected_steps_additive_total" => sum(simulation.rejected_additive),
        "accepted_steps_bilinear_total" => sum(simulation.accepted_bilinear),
        "rejected_steps_bilinear_total" => sum(simulation.rejected_bilinear),
    )
end

function cldhf_object_paths(project_root::AbstractString, object_id::AbstractString)
    directory = joinpath(project_root, "data", "releases", "controlled_lowdim_v1", CLDHF_BASE, object_id)
    return Dict(
        "directory" => directory,
        "clean" => joinpath(directory, "clean.jld2"),
        "metadata" => joinpath(directory, "metadata.json"),
        "parameters" => joinpath(directory, "parameters.json"),
        "trajectory_manifest" => joinpath(directory, "trajectory_manifest.csv"),
        "generation_report" => joinpath(directory, "generation_report.md"),
    )
end

function cldhf_write_json(path::AbstractString, value)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON.print(io, value, 2)
    end
    return path
end

function cldhf_role_control_feature(role::String, simulation, spec::CLDHFSpec)
    role == "addc" && return spec.force_amplitude .* simulation.control_average
    return simulation.control_average
end

function cldhf_write_clean_dataset(
    paths::AbstractDict,
    object_id::String,
    role::String,
    state::Array{Float64,3},
    simulation,
    initial_state::Matrix{Float64},
    initial_source::Matrix{Float64},
    split_id::Vector{String},
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
)
    trajectory_count = size(state, 1)
    time_state_vector = Float32.((0:(cldhf_state_samples(spec) - 1)) .* cldhf_tau(spec))
    time_transition_vector = Float32.((0:(cldhf_transition_count(spec) - 1)) .* cldhf_tau(spec))
    time_state = repeat(reshape(time_state_vector, 1, :), trajectory_count, 1)
    time_transition = repeat(reshape(time_transition_vector, 1, :), trajectory_count, 1)
    learner_state = role == "augaut" ? cat(state, simulation.source_state; dims = 3) : state
    feature = cldhf_role_control_feature(role, simulation, spec)
    trajectory_id = collect(Int64, 1:trajectory_count)
    matched_key = ["duffing_hf:$(trajectory)" for trajectory in trajectory_id]
    physical_force = spec.force_amplitude .* simulation.source_signal
    physical_average = spec.force_amplitude .* simulation.control_average
    mkpath(paths["directory"])
    JLD2.jldsave(
        paths["clean"];
        dataset_id = object_id,
        view_id = "clean",
        protocol = "KSF-D1",
        array_layout = "trajectory_time_channel",
        state_physical_clean = Float32.(state),
        state_observation_clean = Float32.(state),
        target_clean = Float32.(state),
        learner_state_clean = Float32.(learner_state),
        learner_target_clean = Float32.(learner_state),
        time_state = time_state,
        time_transition = time_transition,
        source_state_clean = Float32.(simulation.source_state),
        forcing_phase_clean = Float32.(simulation.source_state),
        source_signal_unit_peak = Float32.(simulation.source_signal),
        forcing_additive_physical = Float32.(physical_force),
        forcing_additive_interval_average = Float32.(physical_average),
        control_left_clean = Float32.(simulation.control_left),
        control_mid_clean = Float32.(simulation.control_mid),
        control_interval_average = Float32.(simulation.control_average),
        control_feature_clean = Float32.(feature),
        forcing_exposed_to_learner = role != "augaut",
        source_state_in_learner_state = role == "augaut",
        source_state_exposed_to_encoder = role == "augaut",
        trajectory_id = trajectory_id,
        physical_initial_id = trajectory_id,
        source_initial_id = trajectory_id,
        matched_key = matched_key,
        split_id = split_id,
        initial_state = Float32.(initial_state),
        initial_source_state = Float32.(initial_source),
        forcing_frequency_hz = Float64.(forcing.frequencies),
        forcing_harmonic_indices = Int64.(forcing.harmonic_indices),
        forcing_harmonic_weights = Float64.(forcing.harmonic_weights),
        forcing_normalized_weights = Float64.(forcing.normalized_weights),
        forcing_fourier_phases = Float64.(forcing.fourier_phases),
        forcing_normalization = Float64(forcing.normalization_factor),
        fs_sim = spec.fs_sim,
        fs_model = spec.fs_model,
        resample_ratio = Int(spec.fs_sim / spec.fs_model),
        endpoint_policy = "half_open",
        normalization_policy = "none_raw_physical_coordinates",
    )
    return paths["clean"]
end

function cldhf_write_trajectory_manifest(path::AbstractString, split_id::Vector{String})
    open(path, "w") do io
        println(io, "trajectory_id,physical_initial_id,source_initial_id,matched_key,split_id")
        for trajectory in eachindex(split_id)
            println(io, "$(trajectory),$(trajectory),$(trajectory),duffing_hf:$(trajectory),$(split_id[trajectory])")
        end
    end
    return path
end

function cldhf_write_generation_report(path::AbstractString, metadata::AbstractDict)
    diagnostics = metadata["diagnostics"]
    open(path, "w") do io
        println(io, "# ", metadata["dataset_id"], " Generation Report")
        println(io)
        println(io, "- Protocol: `KSF-D1`; profile: `formal`; role: `", metadata["control_role"], "`.")
        println(io, "- Trajectories: `", metadata["trajectory_count"], "`; split counts: `", diagnostics["split_counts"], "`.")
        println(io, "- Time grid: `", metadata["time"], "`.")
        println(io, "- Source frequencies (Hz): `", metadata["source"]["frequencies_hz"], "`; configured source / physical-force peaks: `", diagnostics["source_configured_peak_abs"], "` / `", diagnostics["physical_forcing_configured_peak_abs"], "`.")
        println(io, "- Validation: phase circle error `", diagnostics["phase_circle_max_error"], "`; exact interval-average quadrature error `", diagnostics["interval_average_quadrature_error"], "`; bilinear stiffness range `[", diagnostics["bilinear_minimum_linear_stiffness"], ", ", diagnostics["bilinear_maximum_linear_stiffness"], "]`.")
        println(io, "- Bilinear physical acceptance: `", diagnostics["bilinear_physical_acceptance_passed"], "`; diagnostics: `", diagnostics["bilinear_physical_diagnostics"], "`.")
        println(io, "- Overall validation passed: `", diagnostics["passed"], "`.")
    end
    return path
end

function cldhf_metadata(
    config::AbstractDict,
    object_id::String,
    role::String,
    paths::AbstractDict,
    diagnostics::AbstractDict,
    initial_state::Matrix{Float64},
    initial_source::Matrix{Float64},
    split_id::Vector{String},
    spec::CLDHFSpec,
    forcing::CLDHFWeightedForcing,
)
    feature_mode = role == "augaut" ? "audit_only" : (role == "addc" ? "physical_force_interval_average" : "unit_peak_source_interval_average")
    return Dict{String,Any}(
        "dataset_id" => object_id,
        "protocol" => "KSF-D1",
        "artifact_version" => config["dataset"]["artifact_version"],
        "profile" => "formal",
        "base_system" => CLDHF_BASE,
        "control_role" => role == "augaut" ? "augmented_autonomous" : (role == "addc" ? "additive" : "bilinear"),
        "bilinear_channel" => role == "bilinc" ? "relative_linear_stiffness_modulation_x" : nothing,
        "bilinear_stiffness_form" => role == "bilinc" ? "k*(1-rho_k*c_hf)" : nothing,
        "trajectory_count" => cldhf_trajectory_count(spec),
        "transition_count" => cldhf_transition_count(spec),
        "array_layout" => "trajectory_time_channel",
        "normalization_policy" => "none_raw_physical_coordinates",
        "forcing_exposed_to_learner" => role != "augaut",
        "source_state_in_learner_state" => role == "augaut",
        "forcing_feature_mode" => feature_mode,
        "parameter_versions" => config["dataset"],
        "time" => Dict(
            "sample_interval" => cldhf_tau(spec),
            "trajectory_duration" => spec.duration,
            "endpoint_policy" => "half_open",
            "fs_sim" => spec.fs_sim,
            "fs_model" => spec.fs_model,
            "max_internal_step" => spec.max_internal_step,
            "rtol" => spec.reltol,
            "atol" => spec.abstol,
            "anti_alias_filter" => Dict(
                "type" => "zero_phase_windowed_sinc_fir_then_decimate_by_4",
                "taps" => spec.filter_taps,
                "cutoff_hz" => spec.filter_cutoff_hz,
                "applied_to" => ["x", "p", "q_c", "q_s", "source_signal"],
            ),
        ),
        "parameters" => Dict(
            "mass" => spec.mass,
            "damping" => spec.damping,
            "linear_stiffness" => spec.linear_stiffness,
            "cubic_stiffness" => spec.cubic_stiffness,
            "bilinear_relative_stiffness_depth" => spec.stiffness_depth,
            "bilinear_stiffness_form" => "k*(1-rho_k*c_hf)",
            "additive_force_amplitude" => spec.force_amplitude,
        ),
        "source" => Dict(
            "mode" => "phase_locked_multisine_exosystem",
            "base_frequency_hz" => spec.base_frequency_hz,
            "frequencies_hz" => forcing.frequencies,
            "harmonic_indices" => forcing.harmonic_indices,
            "harmonic_weights" => forcing.harmonic_weights,
            "normalized_weights" => forcing.normalized_weights,
            "fourier_phases" => forcing.fourier_phases,
            "normalization_factor" => forcing.normalization_factor,
            "fourier_phase_seed" => spec.fourier_phase_seed,
            "phase_initial_seed" => spec.phase_seed,
        ),
        "initial_conditions" => Dict(
            "physical_min" => [minimum(@view(initial_state[:, channel])) for channel in axes(initial_state, 2)],
            "physical_max" => [maximum(@view(initial_state[:, channel])) for channel in axes(initial_state, 2)],
            "source_min" => [minimum(@view(initial_source[:, channel])) for channel in axes(initial_source, 2)],
            "source_max" => [maximum(@view(initial_source[:, channel])) for channel in axes(initial_source, 2)],
            "pairing" => "paired_by_trajectory_id",
            "split_counts" => cldhf_split_counts(split_id),
        ),
        "noise" => config["noise"],
        "diagnostics" => diagnostics,
        "generated_files" => paths,
    )
end

function cldhf_validate_reload(path::AbstractString, object_id::String, spec::CLDHFSpec)
    return JLD2.jldopen(path, "r") do file
        file["dataset_id"] == object_id && file["view_id"] == "clean" &&
            size(file["state_physical_clean"]) == (cldhf_trajectory_count(spec), cldhf_state_samples(spec), 2) &&
            size(file["control_feature_clean"]) == (cldhf_trajectory_count(spec), cldhf_transition_count(spec), 1) &&
            file["endpoint_policy"] == "half_open"
    end
end

function cldhf_write_shared_resources(project_root::AbstractString, config::AbstractDict, initial_state, initial_phase, initial_source, split_id, forcing)
    directory = joinpath(project_root, "data", "releases", "controlled_lowdim_v1", "shared")
    mkpath(directory)
    JLD2.jldsave(
        joinpath(directory, "duffing_hf_initial_banks.jld2");
        physical_initial_bank = Float32.(initial_state),
        phase_initial_bank = Float64.(initial_phase),
        source_initial_bank = Float32.(initial_source),
        split_id = split_id,
    )
    return cldhf_write_json(joinpath(directory, "duffing_hf_source_realization.json"), Dict(
        "config" => config,
        "harmonic_indices" => forcing.harmonic_indices,
        "harmonic_weights" => forcing.harmonic_weights,
        "normalized_weights" => forcing.normalized_weights,
        "fourier_phases" => forcing.fourier_phases,
        "normalization_factor" => forcing.normalization_factor,
    ))
end

function cldhf_merge_release_manifest(project_root::AbstractString, results::AbstractDict, all_passed::Bool)
    manifest_path = joinpath(project_root, "data", "releases", "controlled_lowdim_v1", "release_manifest.json")
    manifest = JSON.parsefile(manifest_path)
    objects = manifest["objects"]
    for (object_id, result) in results
        objects[object_id] = result
    end
    manifest["objects"] = objects
    manifest["all_passed"] = Bool(manifest["all_passed"]) && all_passed
    manifest["clean_dataset_count"] = length(objects)
    manifest["observed_dataset_count"] = Int(manifest["observed_dataset_count"])
    manifest["total_dataset_file_count"] = manifest["clean_dataset_count"] + manifest["observed_dataset_count"]
    manifest["duffing_hf_release"] = Dict(
        "base_system" => CLDHF_BASE,
        "object_count" => length(results),
        "trajectory_count" => first(values(results))["trajectory_count"],
        "all_passed" => all_passed,
    )
    manifest["generated_at"] = string(Dates.now())
    cldhf_write_json(manifest_path, manifest)
    return manifest_path
end

function generate_controlled_lowdim_v1_duffing_hf(project_root::AbstractString)
    config_path = joinpath(project_root, "configs", "releases", "controlled_lowdim_v1_duffing_hf.json")
    config, spec = cldhf_load_spec(config_path)
    pilot_path = joinpath(
        project_root,
        "runs",
        "smoke_tests",
        "controlled_lowdim_v1_duffing_hf_bilinear_window_pilot.json",
    )
    isfile(pilot_path) || error("missing required DUF-HF bilinear pilot: $(pilot_path)")
    pilot_result = JSON.parsefile(pilot_path)
    selected_depth = Float64(pilot_result["selected_relative_stiffness_depth"])
    selected_depth == spec.stiffness_depth ||
        error("DUF-HF pilot selected rho=$(selected_depth), but formal config uses rho=$(spec.stiffness_depth)")
    forcing = cldhf_build_forcing(spec)
    initial_state, initial_phase, initial_source, split_id = cldhf_sample_initial_banks(spec)
    @printf("DUF-HF formal generation: trajectories=%d state_samples=%d transitions=%d threads=%d\n", cldhf_trajectory_count(spec), cldhf_state_samples(spec), cldhf_transition_count(spec), Threads.nthreads())
    simulation = cldhf_integrate_and_resample(initial_state, initial_phase, spec, forcing)
    diagnostics = cldhf_diagnostics(
        simulation,
        initial_phase,
        split_id,
        spec,
        forcing,
        config["bilinear_pilot"],
    )
    diagnostics["bilinear_pilot"] = pilot_result
    results = Dict{String,Any}()
    all_passed = diagnostics["passed"]
    for role in CLDHF_ROLES
        object_id = "$(CLDHF_BASE)_$(role)"
        state = role == "bilinc" ? simulation.state_bilinear : simulation.state_additive
        paths = cldhf_object_paths(project_root, object_id)
        cldhf_write_clean_dataset(paths, object_id, role, state, simulation, initial_state, initial_source, split_id, spec, forcing)
        reload_passed = cldhf_validate_reload(paths["clean"], object_id, spec)
        object_diagnostics = copy(diagnostics)
        object_diagnostics["reload_passed"] = reload_passed
        object_diagnostics["passed"] = object_diagnostics["passed"] && reload_passed
        metadata = cldhf_metadata(config, object_id, role, paths, object_diagnostics, initial_state, initial_source, split_id, spec, forcing)
        cldhf_write_json(paths["metadata"], metadata)
        cldhf_write_json(paths["parameters"], Dict(
            "base_system" => CLDHF_BASE,
            "control_role" => metadata["control_role"],
            "parameters" => metadata["parameters"],
            "source" => metadata["source"],
            "time" => metadata["time"],
            "noise" => metadata["noise"],
            "parameter_versions" => metadata["parameter_versions"],
        ))
        cldhf_write_trajectory_manifest(paths["trajectory_manifest"], split_id)
        cldhf_write_generation_report(paths["generation_report"], metadata)
        results[object_id] = Dict(
            "passed" => object_diagnostics["passed"],
            "clean_path" => paths["clean"],
            "observed_path" => nothing,
            "trajectory_count" => cldhf_trajectory_count(spec),
            "diagnostics" => object_diagnostics,
        )
        all_passed &= object_diagnostics["passed"]
        @printf("  %-20s passed=%s clean=%s\n", object_id, string(object_diagnostics["passed"]), paths["clean"])
    end
    shared_path = cldhf_write_shared_resources(project_root, config, initial_state, initial_phase, initial_source, split_id, forcing)
    manifest_path = cldhf_merge_release_manifest(project_root, results, all_passed)
    @printf("DUF-HF release passed=%s shared=%s manifest=%s\n", string(all_passed), shared_path, manifest_path)
    return Dict("all_passed" => all_passed, "objects" => results, "manifest_path" => manifest_path)
end
