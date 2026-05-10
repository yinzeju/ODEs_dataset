## Dataset family constants and object ids

using LinearAlgebra

struct KDSMBasicObjectSpec
    release_id::String
    object_id::String
    regime_id::String
    system_kind::String
    alpha::Float64
    beta::Float64
    delta::Float64
    gamma::Float64
    damping_radius::Float64
    omega::Float64
    tau::Float64
    M::Int
    R::Int
    generation_seed::Int
    split_seed::Int
    q_min::Float64
    q_max::Float64
    p_min::Float64
    p_max::Float64
    ic_policy::String
    solver_name::String
    default_observation::String
    default_target::String
    recommended_downstream_input::String
    intended_diagnostics::Vector{String}
    raw_config::Dict{String,Any}
end

function kbasic_release_id()
    return "kdsm_basic_diagnostic_v1"
end

function kbasic_expected_object_ids()
    return [
        "kdsm_basic__L0_discrete_damped_rotation",
        "kdsm_basic__L1_continuous_linear_oscillator",
        "kdsm_basic__BETA_0000_linear_duffing",
        "kdsm_basic__BETA_0001_weak_duffing",
        "kdsm_basic__BETA_0010_weak_duffing",
        "kdsm_basic__BETA_0050_weak_duffing",
        "kdsm_basic__BETA_0100_weak_duffing",
        "kdsm_basic__D0_reference_near_linear_damped",
    ]
end

## Parameter validation rules

function kbasic_profile(system_config::AbstractDict, difficulty::AbstractString)
    difficulty_config = system_config["difficulty"]
    key = haskey(difficulty_config, difficulty) ? String(difficulty) : "default"
    return difficulty_config[key]
end

function kbasic_object_spec(
    system_config::AbstractDict,
    object_config::AbstractDict;
    difficulty::AbstractString = "default",
)
    profile = kbasic_profile(system_config, difficulty)
    raw = Dict{String,Any}(String(k) => v for (k, v) in object_config)
    intended = String.(object_config["intended_diagnostics"])
    spec = KDSMBasicObjectSpec(
        String(system_config["release_id"]),
        String(object_config["object_id"]),
        String(object_config["regime_id"]),
        String(object_config["system_kind"]),
        Float64(get(object_config, "alpha", 0.0)),
        Float64(get(object_config, "beta", 0.0)),
        Float64(get(object_config, "delta", 0.0)),
        Float64(get(object_config, "gamma", 0.0)),
        Float64(get(object_config, "damping_radius", 0.0)),
        Float64(get(object_config, "omega", 0.0)),
        Float64(profile["tau"]),
        Int(profile["M"]),
        Int(profile["R"]),
        Int(system_config["generation_seed"]),
        Int(system_config["split_seed"]),
        Float64(system_config["q_min"]),
        Float64(system_config["q_max"]),
        Float64(system_config["p_min"]),
        Float64(system_config["p_max"]),
        String(system_config["initial_condition_policy"]),
        String(object_config["solver_name"]),
        String(object_config["default_observation"]),
        String(object_config["default_target"]),
        String(object_config["recommended_downstream_input"]),
        intended,
        raw,
    )
    kbasic_validate_object_spec(spec)
    return spec
end

function kbasic_validate_object_spec(spec::KDSMBasicObjectSpec)
    spec.release_id == kbasic_release_id() ||
        throw(ArgumentError("release_id must be $(kbasic_release_id())"))
    spec.object_id in kbasic_expected_object_ids() ||
        throw(ArgumentError("unknown kdsm_basic object_id: $(spec.object_id)"))
    spec.system_kind in ("discrete_damped_rotation", "continuous_linear_oscillator", "weak_duffing") ||
        throw(ArgumentError("unsupported system_kind: $(spec.system_kind)"))
    spec.tau > 0.0 || throw(ArgumentError("tau must be positive"))
    spec.M >= 16 || throw(ArgumentError("M must support horizon 16"))
    spec.R >= 1 || throw(ArgumentError("R must be positive"))
    spec.default_observation in ("obs_phys", "obs_aug_full") ||
        throw(ArgumentError("unsupported default observation"))
    spec.default_target == "target_phys" || throw(ArgumentError("target must be target_phys"))
    spec.gamma == 0.0 || throw(ArgumentError("kdsm_basic objects must be unforced"))
    if spec.system_kind == "discrete_damped_rotation"
        0.0 < spec.damping_radius < 1.0 ||
            throw(ArgumentError("damping_radius must lie in (0, 1)"))
        spec.omega > 0.0 || throw(ArgumentError("omega must be positive"))
    else
        spec.alpha > 0.0 || throw(ArgumentError("alpha must be positive"))
        spec.delta >= 0.0 || throw(ArgumentError("delta must be nonnegative"))
        spec.beta >= 0.0 || throw(ArgumentError("beta must be nonnegative"))
    end
    return true
end

## Discrete damped rotation specification

function kbasic_discrete_rotation_matrix(spec::KDSMBasicObjectSpec)
    c = cos(spec.omega)
    s = sin(spec.omega)
    return spec.damping_radius .* [c -s; s c]
end

## Continuous linear oscillator specification

function kbasic_linear_generator_matrix(spec::KDSMBasicObjectSpec)
    return [0.0 1.0; -spec.alpha -spec.delta]
end

function kbasic_linear_flow_matrix(spec::KDSMBasicObjectSpec)
    return exp(spec.tau .* kbasic_linear_generator_matrix(spec))
end

## Weak Duffing beta-scan specifications

function kbasic_duffing_rhs(x::AbstractVector{<:Real}, spec::KDSMBasicObjectSpec)
    q = Float64(x[1])
    p = Float64(x[2])
    return [p, -spec.delta * p - spec.alpha * q - spec.beta * q^3]
end

function kbasic_rk4_step(x::AbstractVector{<:Real}, spec::KDSMBasicObjectSpec)
    dt = spec.tau
    k1 = kbasic_duffing_rhs(x, spec)
    k2 = kbasic_duffing_rhs(x .+ 0.5 .* dt .* k1, spec)
    k3 = kbasic_duffing_rhs(x .+ 0.5 .* dt .* k2, spec)
    k4 = kbasic_duffing_rhs(x .+ dt .* k3, spec)
    return Float64.(x .+ dt .* (k1 .+ 2.0 .* k2 .+ 2.0 .* k3 .+ k4) ./ 6.0)
end

function kbasic_generate_trajectory(spec::KDSMBasicObjectSpec, x0::AbstractVector{<:Real})
    length(x0) == 2 || throw(ArgumentError("initial condition must be length 2"))
    X = Matrix{Float64}(undef, spec.M + 1, 2)
    X[1, :] .= Float64.(x0)
    if spec.system_kind == "discrete_damped_rotation"
        A = kbasic_discrete_rotation_matrix(spec)
        @inbounds for m in 1:spec.M
            X[m + 1, :] .= A * view(X, m, :)
        end
    elseif spec.system_kind == "continuous_linear_oscillator"
        F = kbasic_linear_flow_matrix(spec)
        @inbounds for m in 1:spec.M
            X[m + 1, :] .= F * view(X, m, :)
        end
    else
        x = collect(Float64, x0)
        @inbounds for m in 1:spec.M
            x = kbasic_rk4_step(x, spec)
            X[m + 1, :] .= x
        end
    end
    all(isfinite, X) || throw(ArgumentError("non-finite trajectory for $(spec.object_id)"))
    return X
end

function kbasic_time_grid(spec::KDSMBasicObjectSpec)
    return collect(range(0.0; step = spec.tau, length = spec.M + 1))
end

function kbasic_matrix_rows(A::AbstractMatrix{<:Real})
    return [[Float64(A[i, j]) for j in axes(A, 2)] for i in axes(A, 1)]
end

## True-spectrum metadata rules

function kbasic_true_system_metadata(spec::KDSMBasicObjectSpec)
    if spec.system_kind == "discrete_damped_rotation"
        lambdas = [
            spec.damping_radius * cis(spec.omega),
            spec.damping_radius * cis(-spec.omega),
        ]
        return Dict{String,Any}(
            "true_discrete_matrix" => kbasic_matrix_rows(kbasic_discrete_rotation_matrix(spec)),
            "true_discrete_spectrum_real" => real.(lambdas),
            "true_discrete_spectrum_imag" => imag.(lambdas),
            "true_continuous_spectrum_real" => Float64[],
            "true_continuous_spectrum_imag" => Float64[],
        )
    elseif spec.system_kind == "continuous_linear_oscillator"
        omega_d = sqrt(spec.alpha - spec.delta^2 / 4.0)
        continuous = ComplexF64[-spec.delta / 2.0 + im * omega_d, -spec.delta / 2.0 - im * omega_d]
        discrete = exp.(spec.tau .* continuous)
        return Dict{String,Any}(
            "true_discrete_matrix" => kbasic_matrix_rows(kbasic_linear_flow_matrix(spec)),
            "true_discrete_spectrum_real" => real.(discrete),
            "true_discrete_spectrum_imag" => imag.(discrete),
            "true_continuous_spectrum_real" => real.(continuous),
            "true_continuous_spectrum_imag" => imag.(continuous),
        )
    end
    return Dict{String,Any}(
        "true_discrete_matrix" => Vector{Vector{Float64}}(),
        "true_discrete_spectrum_real" => Float64[],
        "true_discrete_spectrum_imag" => Float64[],
        "true_continuous_spectrum_real" => Float64[],
        "true_continuous_spectrum_imag" => Float64[],
    )
end

function kbasic_parameter_metadata(spec::KDSMBasicObjectSpec)
    return Dict(
        "alpha" => spec.alpha,
        "beta" => spec.beta,
        "delta" => spec.delta,
        "gamma" => spec.gamma,
        "damping_radius" => spec.damping_radius,
        "omega" => spec.omega,
    )
end
