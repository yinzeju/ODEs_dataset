## Purpose and mathematical object

struct KDSMDuffingObjectSpec
    release_id::String
    object_id::String
    regime_id::String
    forcing::KDSMDuffingForcingSpec
    alpha::Float64
    beta::Float64
    delta::Float64
    gamma::Float64
    tau::Float64
    M::Int
    R::Int
    generation_seed::Int
    split_seed::Int
    ic_policy::String
    default_observation::String
    default_target::String
    recommended_downstream_input::String
    noise_level_id::String
    noise_sigma::Float64
    intended_diagnostics::Vector{String}
    raw_config::Dict{String,Any}
end

## Duffing parameter validation

function kdsm_duffing_object_spec(
    release_config::AbstractDict,
    object_config::AbstractDict;
    difficulty::AbstractString = "default",
)
    profile = release_config["difficulty"][difficulty]
    intended = String.(object_config["intended_diagnostics"])
    spec = KDSMDuffingObjectSpec(
        String(release_config["release_id"]),
        String(object_config["object_id"]),
        String(object_config["regime_id"]),
        kdsm_duffing_forcing_spec(object_config),
        Float64(object_config["alpha"]),
        Float64(object_config["beta"]),
        Float64(object_config["delta"]),
        Float64(object_config["gamma"]),
        Float64(profile["tau"]),
        Int(profile["M"]),
        Int(profile["R"]),
        Int(release_config["generation_seed"]),
        Int(release_config["split_seed"]),
        String(object_config["ic_policy"]),
        String(object_config["default_observation"]),
        String(object_config["default_target"]),
        String(object_config["recommended_downstream_input"]),
        String(object_config["noise_level_id"]),
        Float64(object_config["noise_sigma"]),
        intended,
        Dict{String,Any}(String(k) => v for (k, v) in object_config),
    )
    kdsm_validate_duffing_object_spec(spec)
    return spec
end

function kdsm_validate_duffing_object_spec(spec::KDSMDuffingObjectSpec)
    spec.release_id == "kdsm_duffing_diagnostic_v1" ||
        throw(ArgumentError("release_id must be kdsm_duffing_diagnostic_v1"))
    all(isfinite, (spec.alpha, spec.beta, spec.delta, spec.gamma)) ||
        throw(ArgumentError("Duffing parameters must be finite"))
    spec.delta >= 0.0 || throw(ArgumentError("delta must be nonnegative"))
    spec.tau > 0.0 || throw(ArgumentError("tau must be positive"))
    spec.M >= 1 || throw(ArgumentError("M must be at least 1"))
    spec.R >= 1 || throw(ArgumentError("R must be at least 1"))
    spec.noise_sigma >= 0.0 || throw(ArgumentError("noise_sigma must be nonnegative"))
    spec.default_observation in ("obs_aug_full", "obs_phys_only") ||
        throw(ArgumentError("unsupported default observation"))
    spec.default_target in ("target_phys", "target_aug", "target_poly9", "target_energy5") ||
        throw(ArgumentError("unsupported default target"))
    return true
end

## Forcing state dimension rules

kdsm_state_dim(spec::KDSMDuffingObjectSpec) = 2 + kdsm_forcing_state_dim(spec.forcing)

## Augmented Duffing vector-field construction

function kdsm_duffing_rhs!(
    dx::AbstractVector{Float64},
    x::AbstractVector{Float64},
    spec::KDSMDuffingObjectSpec,
)
    fill!(dx, 0.0)
    q = x[1]
    p = x[2]
    a = kdsm_forcing_signal(spec.forcing, x)
    dx[1] = p
    dx[2] = -spec.delta * p - spec.alpha * q - spec.beta * q^3 + spec.gamma * a
    kdsm_forcing_rhs!(dx, x, spec.forcing)
    return dx
end

function kdsm_rk4_step!(
    x_next::AbstractVector{Float64},
    x::AbstractVector{Float64},
    k1::AbstractVector{Float64},
    k2::AbstractVector{Float64},
    k3::AbstractVector{Float64},
    k4::AbstractVector{Float64},
    tmp::AbstractVector{Float64},
    spec::KDSMDuffingObjectSpec,
)
    dt = spec.tau
    kdsm_duffing_rhs!(k1, x, spec)
    @. tmp = x + 0.5 * dt * k1
    kdsm_duffing_rhs!(k2, tmp, spec)
    @. tmp = x + 0.5 * dt * k2
    kdsm_duffing_rhs!(k3, tmp, spec)
    @. tmp = x + dt * k3
    kdsm_duffing_rhs!(k4, tmp, spec)
    @. x_next = x + dt * (k1 + 2.0 * k2 + 2.0 * k3 + k4) / 6.0
    return x_next
end

function kdsm_time_grid(spec::KDSMDuffingObjectSpec)
    return collect(range(0.0; step = spec.tau, length = spec.M + 1))
end

function kdsm_integrate_augmented_trajectory(
    spec::KDSMDuffingObjectSpec,
    x0::AbstractVector{<:Real},
)
    dx = kdsm_state_dim(spec)
    length(x0) == dx || throw(ArgumentError("initial state length does not match augmented dimension"))
    X = Matrix{Float64}(undef, dx, spec.M + 1)
    X[:, 1] = Float64.(x0)
    x = copy(X[:, 1])
    x_next = similar(x)
    k1 = similar(x)
    k2 = similar(x)
    k3 = similar(x)
    k4 = similar(x)
    tmp = similar(x)
    @inbounds for m in 1:spec.M
        kdsm_rk4_step!(x_next, x, k1, k2, k3, k4, tmp, spec)
        all(isfinite, x_next) || throw(ArgumentError("non-finite state in $(spec.object_id) at step $(m)"))
        X[:, m + 1] = x_next
        x, x_next = x_next, x
    end
    return X
end

## Physical-state extraction

kdsm_state_phys(state_aug::AbstractArray{<:Real,3}) = Array{Float64}(state_aug[1:2, :, :])

## Forcing-state extraction

function kdsm_forcing_state_tensor(
    state_aug::AbstractArray{<:Real,3},
    spec::KDSMDuffingObjectSpec,
)
    d_u = kdsm_forcing_state_dim(spec.forcing)
    if d_u == 0
        return Array{Float64}(undef, 0, size(state_aug, 2), size(state_aug, 3))
    end
    return Array{Float64}(state_aug[3:(2 + d_u), :, :])
end

## Forcing-signal evaluation

function kdsm_forcing_signal_tensor(
    state_aug::AbstractArray{<:Real,3},
    spec::KDSMDuffingObjectSpec,
)
    signal = Array{Float64}(undef, 1, size(state_aug, 2), size(state_aug, 3))
    @inbounds for r in axes(state_aug, 3), m in axes(state_aug, 2)
        signal[1, m, r] = kdsm_forcing_signal(spec.forcing, view(state_aug, :, m, r))
    end
    return signal
end

## Numerical sanity checks

function kdsm_duffing_parameter_metadata(spec::KDSMDuffingObjectSpec)
    return Dict(
        "alpha" => spec.alpha,
        "beta" => spec.beta,
        "delta" => spec.delta,
        "gamma" => spec.gamma,
    )
end
