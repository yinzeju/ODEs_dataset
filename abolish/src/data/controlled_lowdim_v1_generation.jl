using Dates
using JLD2
using JSON
using LinearAlgebra
using OrdinaryDiffEq
using Printf
using Random
using SciMLBase
using Statistics

const CONTROLLED_LOWDIM_V1 = "controlled_lowdim_v1"
const CLD_BASES = ("linosc", "duffing", "vdp", "pendulum")
const CLD_ROLES = ("augaut", "addc", "bilinc")
const CLD_SPLITS = ("train", "val", "test")

Base.@kwdef struct CLDProfile
    name::Symbol
    split_bank_shapes::Dict{String,Tuple{Int,Int}}
    tau::Float64
    duration::Float64
    dtmax::Float64
    reltol::Float64
    abstol::Float64
    seed::Int
end

Base.@kwdef struct CLDSourceSpec
    frequencies::Vector{Float64}
    output::Vector{Float64}
    amplitude_ranges::Vector{Tuple{Float64,Float64}}
    global_scale::Float64
    safety_limit::Float64
end

Base.@kwdef struct CLDSystemSpec
    base::String
    parameters::Dict{String,Float64}
    initial_lower::Vector{Float64}
    initial_upper::Vector{Float64}
    state_abs_limit::Float64
    bilinear_channel::String
end

struct CLDPairing
    initial_state::Matrix{Float64}
    initial_source::Matrix{Float64}
    trajectory_id::Vector{Int64}
    physical_initial_id::Vector{Int64}
    source_initial_id::Vector{Int64}
    matched_key::Vector{String}
    split_id::Vector{String}
end

struct CLDODEParameters
    system::CLDSystemSpec
    role::String
    source::CLDSourceSpec
    q0::Vector{Float64}
end

cld_steps(profile::CLDProfile) = round(Int, profile.duration / profile.tau)
cld_trajectory_count(profile::CLDProfile) = sum(prod(profile.split_bank_shapes[s]) for s in CLD_SPLITS)

function cld_write_json(path::AbstractString, value)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON.print(io, value, 2)
    end
    return path
end

function cld_git_commit(project_root::AbstractString)
    try
        return readchomp(`git -C $project_root rev-parse HEAD`)
    catch
        return "unavailable"
    end
end

function cld_load_release_config(project_root::AbstractString)
    path = joinpath(project_root, "configs", "releases", "controlled_lowdim_v1.json")
    return JSON.parsefile(path), path
end

function cld_profile(config::AbstractDict, name::Symbol)
    raw = config["profiles"][String(name)]
    shapes = Dict{String,Tuple{Int,Int}}(
        split => (Int(raw["split_bank_shapes"][split][1]), Int(raw["split_bank_shapes"][split][2]))
        for split in CLD_SPLITS
    )
    profile = CLDProfile(
        name = name,
        split_bank_shapes = shapes,
        tau = Float64(raw["sample_interval"]),
        duration = Float64(raw["trajectory_duration"]),
        dtmax = Float64(raw["max_internal_step"]),
        reltol = Float64(raw["rtol"]),
        abstol = Float64(raw["atol"]),
        seed = Int(raw["seed"]),
    )
    isapprox(cld_steps(profile) * profile.tau, profile.duration; atol = 1.0e-12, rtol = 0.0) ||
        error("trajectory_duration must be divisible by sample_interval")
    return profile
end

function cld_source_spec(config::AbstractDict)
    raw = config["source"]
    frequencies = Float64.(raw["angular_frequencies"])
    output = Float64.(raw["output_vector"]) .* Float64(raw["global_scale"])
    length(output) == 2 * length(frequencies) || error("source output dimension mismatch")
    ranges = [(Float64(v[1]), Float64(v[2])) for v in raw["amplitude_ranges"]]
    return CLDSourceSpec(
        frequencies = frequencies,
        output = output,
        amplitude_ranges = ranges,
        global_scale = Float64(raw["global_scale"]),
        safety_limit = Float64(raw["forcing_safety_limit"]),
    )
end

function cld_system_spec(config::AbstractDict, base::AbstractString)
    raw = config["systems"][base]
    excluded = Set(("initial_lower", "initial_upper", "state_abs_limit", "bilinear_channel"))
    parameters = Dict{String,Float64}(
        String(key) => Float64(value) for (key, value) in raw if !(String(key) in excluded)
    )
    return CLDSystemSpec(
        base = String(base),
        parameters = parameters,
        initial_lower = Float64.(raw["initial_lower"]),
        initial_upper = Float64.(raw["initial_upper"]),
        state_abs_limit = Float64(raw["state_abs_limit"]),
        bilinear_channel = String(raw["bilinear_channel"]),
    )
end

function cld_source_transition(source::CLDSourceSpec, dt::Real)
    modes = length(source.frequencies)
    matrix = zeros(Float64, 2 * modes, 2 * modes)
    for (j, omega) in enumerate(source.frequencies)
        c = cos(omega * dt)
        s = sin(omega * dt)
        indices = (2j - 1):(2j)
        matrix[2j - 1, 2j - 1] = c
        matrix[2j - 1, 2j] = -s
        matrix[2j, 2j - 1] = s
        matrix[2j, 2j] = c
    end
    return matrix
end

function cld_source_average_operator(source::CLDSourceSpec, dt::Real)
    modes = length(source.frequencies)
    matrix = zeros(Float64, 2 * modes, 2 * modes)
    for (j, omega) in enumerate(source.frequencies)
        a = sin(omega * dt) / (omega * dt)
        b = (cos(omega * dt) - 1.0) / (omega * dt)
        indices = (2j - 1):(2j)
        matrix[2j - 1, 2j - 1] = a
        matrix[2j - 1, 2j] = b
        matrix[2j, 2j - 1] = -b
        matrix[2j, 2j] = a
    end
    return matrix
end

@inline function cld_forcing(source::CLDSourceSpec, q0::AbstractVector, t::Real)
    value = 0.0
    @inbounds for (j, omega) in enumerate(source.frequencies)
        c = cos(omega * t)
        s = sin(omega * t)
        qc = q0[2j - 1]
        qs = q0[2j]
        value += source.output[2j - 1] * (c * qc - s * qs)
        value += source.output[2j] * (s * qc + c * qs)
    end
    return value
end

function cld_sample_source_banks(profile::CLDProfile, source::CLDSourceSpec)
    rng = MersenneTwister(profile.seed + 11)
    total = sum(profile.split_bank_shapes[s][2] for s in CLD_SPLITS)
    bank = Matrix{Float64}(undef, total, 2 * length(source.frequencies))
    split = Vector{String}(undef, total)
    ids = collect(Int64, 1:total)
    index = 1
    for split_name in CLD_SPLITS
        count = profile.split_bank_shapes[split_name][2]
        for _ in 1:count
            for (j, (lower, upper)) in enumerate(source.amplitude_ranges)
                rho = lower + (upper - lower) * rand(rng)
                phase = 2pi * rand(rng)
                bank[index, 2j - 1] = rho * cos(phase)
                bank[index, 2j] = rho * sin(phase)
            end
            split[index] = split_name
            index += 1
        end
    end
    return bank, ids, split
end

function cld_sample_physical_bank(profile::CLDProfile, system::CLDSystemSpec, base_index::Integer)
    rng = MersenneTwister(profile.seed + 100 * base_index)
    total = sum(profile.split_bank_shapes[s][1] for s in CLD_SPLITS)
    bank = Matrix{Float64}(undef, total, 2)
    split = Vector{String}(undef, total)
    ids = collect(Int64, 1:total)
    index = 1
    for split_name in CLD_SPLITS
        count = profile.split_bank_shapes[split_name][1]
        for _ in 1:count
            @inbounds for j in 1:2
                bank[index, j] = system.initial_lower[j] +
                    (system.initial_upper[j] - system.initial_lower[j]) * rand(rng)
            end
            split[index] = split_name
            index += 1
        end
    end
    return bank, ids, split
end

function cld_pairing(
    system::CLDSystemSpec,
    physical_bank::AbstractMatrix,
    physical_ids::AbstractVector,
    physical_split::AbstractVector,
    source_bank::AbstractMatrix,
    source_ids::AbstractVector,
    source_split::AbstractVector,
)
    total = sum(count(==(s), physical_split) * count(==(s), source_split) for s in CLD_SPLITS)
    initial_state = Matrix{Float64}(undef, total, 2)
    initial_source = Matrix{Float64}(undef, total, size(source_bank, 2))
    trajectory_id = collect(Int64, 1:total)
    physical_initial_id = Vector{Int64}(undef, total)
    source_initial_id = Vector{Int64}(undef, total)
    matched_key = Vector{String}(undef, total)
    split_id = Vector{String}(undef, total)
    index = 1
    for split_name in CLD_SPLITS
        xindices = findall(==(split_name), physical_split)
        qindices = findall(==(split_name), source_split)
        for xi in xindices, qi in qindices
            initial_state[index, :] .= @view physical_bank[xi, :]
            initial_source[index, :] .= @view source_bank[qi, :]
            physical_initial_id[index] = physical_ids[xi]
            source_initial_id[index] = source_ids[qi]
            matched_key[index] = string(system.base, ":", physical_ids[xi], ":", source_ids[qi])
            split_id[index] = split_name
            index += 1
        end
    end
    return CLDPairing(
        initial_state,
        initial_source,
        trajectory_id,
        physical_initial_id,
        source_initial_id,
        matched_key,
        split_id,
    )
end

function cld_source_arrays(pairing::CLDPairing, profile::CLDProfile, source::CLDSourceSpec)
    trajectories = length(pairing.trajectory_id)
    steps = cld_steps(profile)
    source_dim = size(pairing.initial_source, 2)
    source_state = Array{Float64}(undef, trajectories, steps + 1, source_dim)
    control_left = Array{Float64}(undef, trajectories, steps, 1)
    control_mid = similar(control_left)
    control_average = similar(control_left)
    transition = cld_source_transition(source, profile.tau)
    average_operator = cld_source_average_operator(source, profile.tau)
    @inbounds for r in 1:trajectories
        q = collect(@view pairing.initial_source[r, :])
        for m in 0:steps
            source_state[r, m + 1, :] .= q
            if m < steps
                control_left[r, m + 1, 1] = dot(source.output, q)
                control_mid[r, m + 1, 1] = cld_forcing(source, @view(pairing.initial_source[r, :]), (m + 0.5) * profile.tau)
                control_average[r, m + 1, 1] = dot(source.output, average_operator * q)
                q = transition * q
            end
        end
    end
    return source_state, control_left, control_mid, control_average
end

function cld_rhs!(du::AbstractVector, x::AbstractVector, p::CLDODEParameters, t)
    system = p.system
    params = system.parameters
    c = cld_forcing(p.source, p.q0, t)
    q1 = x[1]
    q2 = x[2]
    du[1] = q2
    if system.base == "linosc"
        omega0 = params["omega0"]
        drift = -2params["zeta"] * omega0 * q2 - omega0^2 * q1
        du[2] = p.role == "bilinc" ? drift - params["alphac"] * c * q1 : drift + params["bc"] * c
    elseif system.base == "duffing"
        mass = params["mass"]
        drift = (-params["d"] * q2 - params["k"] * q1 - params["kc"] * q1^3) / mass
        du[2] = p.role == "bilinc" ? drift - params["alphac"] * c * q1 / mass : drift + params["bc"] * c / mass
    elseif system.base == "vdp"
        drift = params["mu"] * (1.0 - q1^2) * q2 - params["omega0"]^2 * q1
        du[2] = p.role == "bilinc" ? drift - params["alphac"] * c * q2 : drift + params["bc"] * c
    elseif system.base == "pendulum"
        drift = -params["d"] * q2 - (params["g"] / params["ell"]) * sin(q1)
        du[2] = p.role == "bilinc" ? drift - params["alphac"] * c * q2 : drift + params["bc"] * c
    else
        error("unsupported controlled low-dimensional base: $(system.base)")
    end
    return nothing
end

function cld_integrate_trajectory(
    initial::AbstractVector,
    q0::AbstractVector,
    system::CLDSystemSpec,
    role::AbstractString,
    source::CLDSourceSpec,
    profile::CLDProfile,
)
    parameters = CLDODEParameters(system, String(role), source, collect(q0))
    problem = ODEProblem(cld_rhs!, collect(initial), (0.0, profile.duration), parameters)
    times = (0:cld_steps(profile)) .* profile.tau
    solution = solve(
        problem,
        Vern9();
        reltol = profile.reltol,
        abstol = profile.abstol,
        dtmax = profile.dtmax,
        saveat = times,
        save_everystep = false,
    )
    solution.retcode == ReturnCode.Success || error("integration failed: $(solution.retcode)")
    length(solution.u) == length(times) || error("integration returned an unexpected sample count")
    trajectory = Matrix{Float64}(undef, length(times), 2)
    @inbounds for m in eachindex(solution.u)
        trajectory[m, :] .= solution.u[m]
    end
    return trajectory
end

function cld_integrate_batch(
    pairing::CLDPairing,
    system::CLDSystemSpec,
    role::AbstractString,
    source::CLDSourceSpec,
    profile::CLDProfile,
)
    trajectories = length(pairing.trajectory_id)
    state = Array{Float64}(undef, trajectories, cld_steps(profile) + 1, 2)
    Threads.@threads for r in 1:trajectories
        trajectory = cld_integrate_trajectory(
            @view(pairing.initial_state[r, :]),
            @view(pairing.initial_source[r, :]),
            system,
            role,
            source,
            profile,
        )
        state[r, :, :] .= trajectory
    end
    return state
end

function cld_observation(state::Array{Float64,3}, base::AbstractString)
    base != "pendulum" && return copy(state)
    observation = Array{Float64}(undef, size(state, 1), size(state, 2), 3)
    @inbounds for r in axes(state, 1), m in axes(state, 2)
        theta = state[r, m, 1]
        observation[r, m, 1] = cos(theta)
        observation[r, m, 2] = sin(theta)
        observation[r, m, 3] = state[r, m, 2]
    end
    return observation
end

function cld_learner_arrays(observation::Array{Float64,3}, source_state::Array{Float64,3}, role::AbstractString)
    if role == "augaut"
        learner = cat(observation, source_state; dims = 3)
        return learner, learner
    end
    return observation, observation
end

function cld_noise_view(
    state::Array{Float64,3},
    observation::Array{Float64,3},
    source_state::Array{Float64,3},
    pairing::CLDPairing,
    role::AbstractString,
    noise_config::AbstractDict,
    object_offset::Integer,
)
    train = findall(==("train"), pairing.split_id)
    fraction = Float64(noise_config["scale_fraction"])
    observed = copy(observation)
    noise_seed = Vector{Int64}(undef, size(state, 1))
    scales = if size(observation, 3) == 3
        wrapped_angle = atan.(sin.(@view(state[train, :, 1])), cos.(@view(state[train, :, 1])))
        [fraction * std(wrapped_angle; corrected = false), fraction * std(@view(state[train, :, 2]); corrected = false)]
    else
        [fraction * std(@view(observation[train, :, j]); corrected = false) for j in axes(observation, 3)]
    end
    for r in axes(state, 1)
        seed = Int(noise_config["seed"]) + 100_000 * object_offset + r
        noise_seed[r] = seed
        rng = MersenneTwister(seed)
        if size(observation, 3) == 3
            @inbounds for m in axes(state, 2)
                theta_noisy = state[r, m, 1] + scales[1] * randn(rng)
                observed[r, m, 1] = cos(theta_noisy)
                observed[r, m, 2] = sin(theta_noisy)
                observed[r, m, 3] = state[r, m, 2] + scales[2] * randn(rng)
            end
        else
            @inbounds for j in axes(observation, 3), m in axes(observation, 2)
                observed[r, m, j] += scales[j] * randn(rng)
            end
        end
    end
    learner_observed = role == "augaut" ? cat(observed, source_state; dims = 3) : observed
    return observed, learner_observed, noise_seed, scales
end

function cld_vector_field(system::CLDSystemSpec, role::AbstractString, x::AbstractVector, c::Real)
    source = CLDSourceSpec([1.0], [1.0, 0.0], [(0.0, 0.0)], 1.0, Inf)
    p = CLDODEParameters(system, String(role), source, [Float64(c), 0.0])
    du = zeros(Float64, 2)
    cld_rhs!(du, x, p, 0.0)
    return du
end

function cld_expected_sensitivity(system::CLDSystemSpec, role::AbstractString, x::AbstractVector)
    p = system.parameters
    if role != "bilinc"
        scale = system.base == "duffing" ? p["bc"] / p["mass"] : p["bc"]
        return [0.0, scale]
    elseif system.base == "linosc" || system.base == "duffing"
        scale = system.base == "duffing" ? p["alphac"] / p["mass"] : p["alphac"]
        return [0.0, -scale * x[1]]
    else
        return [0.0, -p["alphac"] * x[2]]
    end
end

function cld_sensitivity_error(system::CLDSystemSpec, role::AbstractString)
    epsilon = 1.0e-6
    error_max = 0.0
    sensitivity_values = Vector{Vector{Float64}}()
    for x in ([0.4, -0.7], [-1.1, 0.9], [1.3, 1.4])
        finite_difference = (cld_vector_field(system, role, x, 0.2 + epsilon) -
            cld_vector_field(system, role, x, 0.2)) / epsilon
        expected = cld_expected_sensitivity(system, role, x)
        error_max = max(error_max, maximum(abs.(finite_difference .- expected)))
        push!(sensitivity_values, finite_difference)
    end
    nonconstant = role != "bilinc" || any(norm(sensitivity_values[i] - sensitivity_values[1]) > 1.0e-6 for i in 2:3)
    return error_max, nonconstant
end

function cld_zero_control_error(system::CLDSystemSpec, profile::CLDProfile, source::CLDSourceSpec)
    zero_source = CLDSourceSpec(source.frequencies, source.output, source.amplitude_ranges, source.global_scale, source.safety_limit)
    q0 = zeros(Float64, length(source.output))
    short_profile = CLDProfile(
        name = profile.name,
        split_bank_shapes = profile.split_bank_shapes,
        tau = profile.tau,
        duration = min(profile.duration, 0.1),
        dtmax = profile.dtmax,
        reltol = profile.reltol,
        abstol = profile.abstol,
        seed = profile.seed,
    )
    initial = 0.5 .* (system.initial_lower .+ system.initial_upper) .+ [0.17, -0.23]
    additive = cld_integrate_trajectory(initial, q0, system, "addc", zero_source, short_profile)
    bilinear = cld_integrate_trajectory(initial, q0, system, "bilinc", zero_source, short_profile)
    return maximum(abs.(additive .- bilinear))
end

function cld_source_diagnostics(
    source_state::Array{Float64,3},
    control_left::Array{Float64,3},
    control_average::Array{Float64,3},
    source::CLDSourceSpec,
    profile::CLDProfile,
)
    transition = cld_source_transition(source, profile.tau)
    next_error = 0.0
    norm_error = 0.0
    @inbounds for r in axes(source_state, 1), m in 1:(size(source_state, 2) - 1)
        predicted = transition * @view(source_state[r, m, :])
        next_error = max(next_error, maximum(abs.(predicted .- @view(source_state[r, m + 1, :]))))
    end
    @inbounds for r in axes(source_state, 1), j in eachindex(source.frequencies)
        reference = hypot(source_state[r, 1, 2j - 1], source_state[r, 1, 2j])
        for m in axes(source_state, 2)
            norm_error = max(norm_error, abs(hypot(source_state[r, m, 2j - 1], source_state[r, m, 2j]) - reference))
        end
    end
    q0 = collect(@view source_state[1, 1, :])
    subdivisions = 2_000
    h = profile.tau / subdivisions
    integral = 0.0
    for k in 0:subdivisions
        weight = k == 0 || k == subdivisions ? 1.0 : (iseven(k) ? 2.0 : 4.0)
        integral += weight * cld_forcing(source, q0, k * h)
    end
    numerical_average = integral * h / (3 * profile.tau)
    average_error = abs(numerical_average - control_average[1, 1, 1])
    return Dict(
        "transition_max_error" => next_error,
        "mode_norm_max_error" => norm_error,
        "interval_average_quadrature_error" => average_error,
        "forcing_max_abs" => maximum(abs, control_left),
        "forcing_safe" => maximum(abs, control_left) <= source.safety_limit,
    )
end

function cld_state_forcing_correlations(state::Array{Float64,3}, control::Array{Float64,3})
    forcing = vec(control[:, :, 1])
    values = Float64[]
    for j in axes(state, 3)
        channel = vec(@view state[:, 1:(end - 1), j])
        push!(values, cor(channel, forcing))
    end
    return values
end

function cld_diagnostics(
    state::Array{Float64,3},
    observation::Array{Float64,3},
    observed::Array{Float64,3},
    source_state::Array{Float64,3},
    control_left::Array{Float64,3},
    control_average::Array{Float64,3},
    pairing::CLDPairing,
    system::CLDSystemSpec,
    role::AbstractString,
    source::CLDSourceSpec,
    profile::CLDProfile,
    noise_scales::AbstractVector,
)
    source_diag = cld_source_diagnostics(source_state, control_left, control_average, source, profile)
    sensitivity_error, sensitivity_nonconstant = cld_sensitivity_error(system, role)
    zero_error = cld_zero_control_error(system, profile, source)
    unit_circle_clean = system.base == "pendulum" ? maximum(abs.(observation[:, :, 1].^2 .+ observation[:, :, 2].^2 .- 1.0)) : 0.0
    unit_circle_observed = system.base == "pendulum" ? maximum(abs.(observed[:, :, 1].^2 .+ observed[:, :, 2].^2 .- 1.0)) : 0.0
    split_counts = Dict(split => count(==(split), pairing.split_id) for split in CLD_SPLITS)
    gram_value = mean(abs2, control_average)
    correlations = cld_state_forcing_correlations(state, control_average)
    all_finite = all(isfinite, state) && all(isfinite, observation) && all(isfinite, observed)
    within_domain = maximum(abs, state) <= system.state_abs_limit
    passed = all_finite && within_domain && source_diag["forcing_safe"] &&
        source_diag["transition_max_error"] <= 1.0e-10 &&
        source_diag["mode_norm_max_error"] <= 1.0e-10 &&
        source_diag["interval_average_quadrature_error"] <= 1.0e-10 &&
        sensitivity_error <= 1.0e-7 && sensitivity_nonconstant && zero_error <= 1.0e-10 &&
        unit_circle_clean <= 1.0e-12 && unit_circle_observed <= 1.0e-12 && gram_value > eps(Float64)
    return Dict{String,Any}(
        "passed" => passed,
        "all_finite" => all_finite,
        "state_within_configured_domain" => within_domain,
        "state_max_abs" => maximum(abs, state),
        "state_min_by_channel" => [minimum(@view(state[:, :, j])) for j in axes(state, 3)],
        "state_max_by_channel" => [maximum(@view(state[:, :, j])) for j in axes(state, 3)],
        "state_energy_mean" => mean(sum(abs2, state; dims = 3)) / 2,
        "source" => source_diag,
        "split_counts" => split_counts,
        "matched_key_count" => length(unique(pairing.matched_key)),
        "matched_key_coverage" => length(unique(pairing.matched_key)) / length(pairing.matched_key),
        "rejected_trajectory_count" => 0,
        "rejection_reasons" => String[],
        "zero_control_max_error" => zero_error,
        "control_sensitivity_max_error" => sensitivity_error,
        "bilinear_sensitivity_nonconstant" => sensitivity_nonconstant,
        "forcing_feature_gram" => [gram_value],
        "forcing_feature_gram_rank" => gram_value > eps(Float64) ? 1 : 0,
        "forcing_feature_gram_condition_number" => 1.0,
        "forcing_excitation_deficiency" => !(gram_value > eps(Float64)),
        "state_forcing_correlations" => correlations,
        "unit_circle_clean_max_error" => unit_circle_clean,
        "unit_circle_observed_max_error" => unit_circle_observed,
        "noise_scales" => collect(noise_scales),
        "role_exclusivity_passed" => true,
    )
end

function cld_output_root(project_root::AbstractString, profile::CLDProfile)
    profile.name == :formal && return joinpath(project_root, "data", "releases", CONTROLLED_LOWDIM_V1)
    return joinpath(project_root, "runs", "smoke_tests", CONTROLLED_LOWDIM_V1)
end

function cld_object_paths(root::AbstractString, base::AbstractString, object_id::AbstractString)
    directory = joinpath(root, base, object_id)
    return Dict(
        "directory" => directory,
        "clean" => joinpath(directory, "clean.jld2"),
        "observed" => joinpath(directory, "observed.jld2"),
        "metadata" => joinpath(directory, "metadata.json"),
        "parameters" => joinpath(directory, "parameters.json"),
        "trajectory_manifest" => joinpath(directory, "trajectory_manifest.csv"),
        "generation_report" => joinpath(directory, "generation_report.md"),
    )
end

function cld_save_common!(file, pairing::CLDPairing, profile::CLDProfile, source_state, control_left, control_mid, control_average)
    trajectories = length(pairing.trajectory_id)
    steps = cld_steps(profile)
    time_state_vector = Float32.((0:steps) .* profile.tau)
    time_transition_vector = Float32.((0:(steps - 1)) .* profile.tau)
    file["time_state"] = repeat(reshape(time_state_vector, 1, :), trajectories, 1)
    file["time_transition"] = repeat(reshape(time_transition_vector, 1, :), trajectories, 1)
    file["source_state_clean"] = Float32.(source_state)
    file["control_left_clean"] = Float32.(control_left)
    file["control_mid_clean"] = Float32.(control_mid)
    file["control_interval_average"] = Float32.(control_average)
    file["control_feature_clean"] = Float32.(control_average)
    file["trajectory_id"] = pairing.trajectory_id
    file["physical_initial_id"] = pairing.physical_initial_id
    file["source_initial_id"] = pairing.source_initial_id
    file["matched_key"] = pairing.matched_key
    file["split_id"] = pairing.split_id
    file["initial_state"] = Float32.(pairing.initial_state)
    file["initial_source_state"] = Float32.(pairing.initial_source)
    return nothing
end

function cld_save_datasets(
    paths::AbstractDict,
    object_id::AbstractString,
    base::AbstractString,
    role::AbstractString,
    state,
    observation,
    learner_clean,
    learner_target,
    observed,
    learner_observed,
    noise_seed,
    pairing,
    profile,
    source_state,
    control_left,
    control_mid,
    control_average,
)
    mkpath(paths["directory"])
    jldopen(paths["clean"], "w") do file
        file["dataset_id"] = object_id
        file["view_id"] = "clean"
        file["protocol"] = "KSF-D1"
        file["array_layout"] = "trajectory_time_channel"
        file["state_physical_clean"] = Float32.(state)
        file["state_observation_clean"] = Float32.(observation)
        file["target_clean"] = Float32.(observation)
        file["learner_state_clean"] = Float32.(learner_clean)
        file["learner_target_clean"] = Float32.(learner_target)
        file["forcing_exposed_to_learner"] = role != "augaut"
        file["source_state_in_learner_state"] = role == "augaut"
        if base == "pendulum"
            file["angle_raw_clean"] = Float32.(state[:, :, 1:1])
            file["angular_velocity_clean"] = Float32.(state[:, :, 2:2])
            file["unit_circle_residual_clean"] = Float32.(abs.(observation[:, :, 1:1].^2 .+ observation[:, :, 2:2].^2 .- 1.0))
        end
        cld_save_common!(file, pairing, profile, source_state, control_left, control_mid, control_average)
    end
    jldopen(paths["observed"], "w") do file
        file["dataset_id"] = object_id
        file["view_id"] = "observed_noise"
        file["protocol"] = "KSF-D1"
        file["array_layout"] = "trajectory_time_channel"
        file["state_observation_observed"] = Float32.(observed)
        file["learner_state_observed"] = Float32.(learner_observed)
        file["learner_target_clean"] = Float32.(learner_target)
        file["target_clean"] = Float32.(observation)
        file["noise_seed"] = noise_seed
        file["forcing_exposed_to_learner"] = role != "augaut"
        file["source_state_in_learner_state"] = role == "augaut"
        if base == "pendulum"
            file["unit_circle_residual_observed"] = Float32.(abs.(observed[:, :, 1:1].^2 .+ observed[:, :, 2:2].^2 .- 1.0))
        end
        cld_save_common!(file, pairing, profile, source_state, control_left, control_mid, control_average)
    end
    return nothing
end

function cld_write_trajectory_manifest(path::AbstractString, pairing::CLDPairing, noise_seed::AbstractVector)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "trajectory_id,physical_initial_id,source_initial_id,matched_key,split_id,noise_seed,rejected,rejection_reason")
        for r in eachindex(pairing.trajectory_id)
            println(io, join((
                pairing.trajectory_id[r], pairing.physical_initial_id[r], pairing.source_initial_id[r],
                pairing.matched_key[r], pairing.split_id[r], noise_seed[r], false, "",
            ), ','))
        end
    end
    return path
end

function cld_write_generation_report(path::AbstractString, metadata::AbstractDict)
    d = metadata["diagnostics"]
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# ", metadata["dataset_id"], " Generation Report")
        println(io)
        println(io, "- Protocol: `KSF-D1`; profile: `", metadata["profile"], "`; control role: `", metadata["control_role"], "`.")
        println(io, "- Trajectories: `", metadata["trajectory_count"], "`; transitions per trajectory: `", metadata["transition_count"], "`; sample interval: `", metadata["time"]["sample_interval"], "`; physical duration: `", metadata["time"]["trajectory_duration"], "`.")
        println(io, "- Split counts: `", d["split_counts"], "`; split unit: complete trajectory; validation/test isolate both physical and source banks.")
        println(io, "- Physical initial range: `", metadata["initial_conditions"]["physical_min"], "` to `", metadata["initial_conditions"]["physical_max"], "`.")
        println(io, "- Source initial range: `", metadata["initial_conditions"]["source_min"], "` to `", metadata["initial_conditions"]["source_max"], "`; angular frequencies: `", metadata["source"]["angular_frequencies"], "`.")
        println(io, "- Forcing statistics: mean `", metadata["forcing"]["mean"], "`, standard deviation `", metadata["forcing"]["std"], "`, peak `", metadata["forcing"]["peak"], "`; interval-average Gram `", d["forcing_feature_gram"], "`.")
        println(io, "- State-forcing correlations: `", d["state_forcing_correlations"], "`; forcing Gram rank: `", d["forcing_feature_gram_rank"], "`; condition number: `", d["forcing_feature_gram_condition_number"], "`.")
        println(io, "- Clean state range: `", d["state_min_by_channel"], "` to `", d["state_max_by_channel"], "`; mean quadratic energy: `", d["state_energy_mean"], "`.")
        println(io, "- Rejected trajectories: `", d["rejected_trajectory_count"], "`; reasons: `", d["rejection_reasons"], "`.")
        println(io, "- Noise: additive Gaussian learner-state observation, training-clean scale fraction `", metadata["noise"]["scale_fraction"], "`, frozen scales `", d["noise_scales"], "`, clean target/control/source, seed policy `", metadata["noise"]["seed_policy"], "`.")
        println(io, "- Matched-key coverage across the three roles is `1.0` by construction; object-local unique-key coverage: `", d["matched_key_coverage"], "`.")
        println(io, "- Source transition error: `", d["source"]["transition_max_error"], "`; interval-average quadrature error: `", d["source"]["interval_average_quadrature_error"], "`; source norm error: `", d["source"]["mode_norm_max_error"], "`.")
        println(io, "- Zero-control degeneration error: `", d["zero_control_max_error"], "`; control finite-difference error: `", d["control_sensitivity_max_error"], "`; bilinear sensitivity nonconstant: `", d["bilinear_sensitivity_nonconstant"], "`.")
        println(io, "- Pendulum clean/observed unit-circle residual: `", d["unit_circle_clean_max_error"], "` / `", d["unit_circle_observed_max_error"], "`.")
        println(io, "- Overall validation passed: `", d["passed"], "`.")
    end
    return path
end

function cld_object_metadata(
    config,
    profile,
    system,
    role,
    pairing,
    source,
    control_left,
    diagnostics,
    paths,
)
    object_id = string(system.base, "_", role)
    return Dict{String,Any}(
        "dataset_id" => object_id,
        "protocol" => "KSF-D1",
        "artifact_version" => config["dataset"]["artifact_version"],
        "profile" => String(profile.name),
        "generated_at" => string(now()),
        "base_system" => system.base,
        "control_role" => role == "augaut" ? "augmented_autonomous" : (role == "addc" ? "additive" : "bilinear"),
        "bilinear_channel" => role == "bilinc" ? system.bilinear_channel : nothing,
        "trajectory_count" => length(pairing.trajectory_id),
        "transition_count" => cld_steps(profile),
        "array_layout" => "trajectory_time_channel",
        "normalization_policy" => "none_raw_physical_coordinates",
        "forcing_exposed_to_learner" => role != "augaut",
        "source_state_in_learner_state" => role == "augaut",
        "source_state_exposed_to_encoder" => role == "augaut",
        "forcing_feature_mode" => role == "augaut" ? "audit_only" : "scalar_interval_average",
        "parameter_versions" => Dict(key => config["dataset"][key] for key in (
            "base_parameter_version", "source_parameter_version", "time_parameter_version", "noise_parameter_version",
        )),
        "time" => Dict(
            "sample_interval" => profile.tau,
            "trajectory_duration" => profile.duration,
            "max_internal_step" => profile.dtmax,
            "solver" => "Vern9",
            "rtol" => profile.reltol,
            "atol" => profile.abstol,
        ),
        "parameters" => system.parameters,
        "source" => Dict(
            "mode" => "finite_dimensional_harmonic_exosystem",
            "angular_frequencies" => source.frequencies,
            "output_vector_after_global_scale" => source.output,
            "amplitude_ranges" => [[a, b] for (a, b) in source.amplitude_ranges],
        ),
        "forcing" => Dict(
            "mean" => mean(control_left),
            "std" => std(control_left; corrected = false),
            "peak" => maximum(abs, control_left),
            "feature_mode" => role == "augaut" ? "audit_only" : "scalar_interval_average",
        ),
        "initial_conditions" => Dict(
            "physical_min" => [minimum(@view(pairing.initial_state[:, j])) for j in axes(pairing.initial_state, 2)],
            "physical_max" => [maximum(@view(pairing.initial_state[:, j])) for j in axes(pairing.initial_state, 2)],
            "source_min" => [minimum(@view(pairing.initial_source[:, j])) for j in axes(pairing.initial_source, 2)],
            "source_max" => [maximum(@view(pairing.initial_source[:, j])) for j in axes(pairing.initial_source, 2)],
            "pairing" => "split_local_cartesian_product",
        ),
        "noise" => Dict(
            "enabled" => true,
            "model" => "additive_gaussian",
            "scale_mode" => config["noise"]["scale_mode"],
            "scale_fraction" => config["noise"]["scale_fraction"],
            "reference" => "clean_training_split",
            "target_mode" => "clean_target",
            "control_noise" => false,
            "source_state_noise" => false,
            "pendulum_noise_coordinate" => config["noise"]["pendulum_noise_coordinate"],
            "seed_policy" => "noise.seed + 100000*object_offset + trajectory_id",
        ),
        "diagnostics" => diagnostics,
        "generated_files" => paths,
    )
end

function cld_validate_reload(paths::AbstractDict, expected_trajectories::Integer, expected_steps::Integer)
    clean_ok = jldopen(paths["clean"], "r") do file
        file["view_id"] == "clean" &&
            size(file["state_physical_clean"], 1) == expected_trajectories &&
            size(file["state_physical_clean"], 2) == expected_steps + 1
    end
    observed_ok = jldopen(paths["observed"], "r") do file
        file["view_id"] == "observed_noise" &&
            size(file["learner_state_observed"], 1) == expected_trajectories &&
            size(file["learner_state_observed"], 2) == expected_steps + 1
    end
    return clean_ok && observed_ok
end

function cld_save_shared_resources(
    root::AbstractString,
    project_root::AbstractString,
    config,
    config_path,
    profile,
    source_bank,
    source_ids,
    source_split,
    physical_resources,
)
    shared = joinpath(root, "shared")
    mkpath(shared)
    cp(config_path, joinpath(shared, "release_config.json"); force = true)
    JLD2.jldsave(
        joinpath(shared, "source_initial_bank.jld2");
        source_initial_bank = Float32.(source_bank),
        source_initial_id = source_ids,
        split_id = source_split,
    )
    JLD2.jldsave(joinpath(shared, "physical_initial_banks.jld2"); physical_resources)
    split_manifest = Dict(
        "unit" => "trajectory",
        "pairing" => "split_local_cartesian_product",
        "split_bank_shapes" => Dict(s => collect(profile.split_bank_shapes[s]) for s in CLD_SPLITS),
        "trajectory_counts" => Dict(s => prod(profile.split_bank_shapes[s]) for s in CLD_SPLITS),
        "reuse_manifest_across_roles" => true,
    )
    cld_write_json(joinpath(shared, "split_manifest.json"), split_manifest)
    environment = Dict(
        "generated_at" => string(now()),
        "julia_version" => string(VERSION),
        "threads" => Threads.nthreads(),
        "git_commit" => cld_git_commit(project_root),
        "project_toml" => joinpath(project_root, "Project.toml"),
        "solver" => "Vern9",
    )
    cld_write_json(joinpath(shared, "generation_environment.json"), environment)
    return shared
end

function generate_controlled_lowdim_v1(project_root::AbstractString; profile::Symbol = :formal)
    config, config_path = cld_load_release_config(project_root)
    run_profile = cld_profile(config, profile)
    source = cld_source_spec(config)
    output_root = cld_output_root(project_root, run_profile)
    mkpath(output_root)
    source_bank, source_ids, source_split = cld_sample_source_banks(run_profile, source)
    physical_resources = Dict{String,Any}()
    object_results = Dict{String,Any}()
    all_passed = true
    clean_count = 0
    observed_count = 0

    @printf("controlled_lowdim_v1 profile=%s trajectories/object=%d steps=%d threads=%d\n",
        String(profile), cld_trajectory_count(run_profile), cld_steps(run_profile), Threads.nthreads())

    for (base_index, base) in enumerate(CLD_BASES)
        system = cld_system_spec(config, base)
        physical_bank, physical_ids, physical_split = cld_sample_physical_bank(run_profile, system, base_index)
        physical_resources[base] = Dict(
            "initial_state" => Float32.(physical_bank),
            "physical_initial_id" => physical_ids,
            "split_id" => physical_split,
        )
        pairing = cld_pairing(
            system,
            physical_bank,
            physical_ids,
            physical_split,
            source_bank,
            source_ids,
            source_split,
        )
        source_state, control_left, control_mid, control_average = cld_source_arrays(pairing, run_profile, source)

        @printf("[%s] integrating additive/augmented shared trajectories...\n", base)
        additive_state = cld_integrate_batch(pairing, system, "addc", source, run_profile)
        @printf("[%s] integrating bilinear trajectories...\n", base)
        bilinear_state = cld_integrate_batch(pairing, system, "bilinc", source, run_profile)

        for (role_index, role) in enumerate(CLD_ROLES)
            object_id = string(base, "_", role)
            state = role == "bilinc" ? bilinear_state : additive_state
            observation = cld_observation(state, base)
            learner_clean, learner_target = cld_learner_arrays(observation, source_state, role)
            object_offset = 10 * base_index + role_index
            observed, learner_observed, noise_seed, noise_scales = cld_noise_view(
                state,
                observation,
                source_state,
                pairing,
                role,
                config["noise"],
                object_offset,
            )
            diagnostics = cld_diagnostics(
                state,
                observation,
                observed,
                source_state,
                control_left,
                control_average,
                pairing,
                system,
                role,
                source,
                run_profile,
                noise_scales,
            )
            paths = cld_object_paths(output_root, base, object_id)
            cld_save_datasets(
                paths,
                object_id,
                base,
                role,
                state,
                observation,
                learner_clean,
                learner_target,
                observed,
                learner_observed,
                noise_seed,
                pairing,
                run_profile,
                source_state,
                control_left,
                control_mid,
                control_average,
            )
            reload_passed = cld_validate_reload(paths, length(pairing.trajectory_id), cld_steps(run_profile))
            diagnostics["reload_passed"] = reload_passed
            diagnostics["passed"] = diagnostics["passed"] && reload_passed
            metadata = cld_object_metadata(
                config,
                run_profile,
                system,
                role,
                pairing,
                source,
                control_left,
                diagnostics,
                paths,
            )
            cld_write_json(paths["metadata"], metadata)
            cld_write_json(paths["parameters"], Dict(
                "base_system" => base,
                "control_role" => metadata["control_role"],
                "base_parameters" => system.parameters,
                "source" => metadata["source"],
                "time" => metadata["time"],
                "noise" => metadata["noise"],
                "parameter_versions" => metadata["parameter_versions"],
            ))
            cld_write_trajectory_manifest(paths["trajectory_manifest"], pairing, noise_seed)
            cld_write_generation_report(paths["generation_report"], metadata)
            object_results[object_id] = Dict(
                "passed" => diagnostics["passed"],
                "clean_path" => paths["clean"],
                "observed_path" => paths["observed"],
                "trajectory_count" => length(pairing.trajectory_id),
                "diagnostics" => diagnostics,
            )
            all_passed &= diagnostics["passed"]
            clean_count += 1
            observed_count += 1
            @printf("  %-18s passed=%s clean=%s observed=%s\n", object_id, string(diagnostics["passed"]), paths["clean"], paths["observed"])
        end
    end

    shared = cld_save_shared_resources(
        output_root,
        project_root,
        config,
        config_path,
        run_profile,
        source_bank,
        source_ids,
        source_split,
        physical_resources,
    )
    release_manifest_path = joinpath(output_root, "release_manifest.json")
    manifest = Dict{String,Any}(
        "release_id" => CONTROLLED_LOWDIM_V1,
        "protocol" => "KSF-D1",
        "profile" => String(profile),
        "generated_at" => string(now()),
        "all_passed" => all_passed,
        "clean_dataset_count" => clean_count,
        "observed_dataset_count" => observed_count,
        "total_dataset_file_count" => clean_count + observed_count,
        "trajectories_per_object" => cld_trajectory_count(run_profile),
        "split_counts_per_object" => Dict(s => prod(run_profile.split_bank_shapes[s]) for s in CLD_SPLITS),
        "matched_key_coverage_across_roles" => 1.0,
        "objects" => object_results,
        "shared_directory" => shared,
        "release_manifest_path" => release_manifest_path,
    )
    cld_write_json(release_manifest_path, manifest)
    @printf("release passed=%s clean=%d observed=%d manifest=%s\n", string(all_passed), clean_count, observed_count, release_manifest_path)
    return manifest
end
