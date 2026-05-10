## Purpose and forcing registry boundary

using Random

struct KDSMDuffingForcingSpec
    forcing_id::String
    params::Dict{String,Float64}
end

function kdsm_duffing_forcing_spec(object_config::AbstractDict)
    forcing_id = String(object_config["forcing_id"])
    params = Dict{String,Float64}()
    if haskey(object_config, "omega")
        params["omega"] = Float64(object_config["omega"])
    end
    if haskey(object_config, "omega1")
        params["omega1"] = Float64(object_config["omega1"])
    end
    if haskey(object_config, "omega2")
        params["omega2"] = Float64(object_config["omega2"])
    end
    if haskey(object_config, "eta")
        params["eta"] = Float64(object_config["eta"])
    end
    if forcing_id == "force_lorenz_readout"
        params["sigma_L"] = Float64(get(object_config, "sigma_L", 10.0))
        params["rho_L"] = Float64(get(object_config, "rho_L", 28.0))
        params["b_L"] = Float64(get(object_config, "b_L", 8.0 / 3.0))
        params["s_L"] = Float64(get(object_config, "s_L", 10.0))
    end
    spec = KDSMDuffingForcingSpec(forcing_id, params)
    kdsm_validate_forcing_spec(spec)
    return spec
end

## force_none specification

function kdsm_forcing_state_dim(spec::KDSMDuffingForcingSpec)
    if spec.forcing_id == "force_none"
        return 0
    elseif spec.forcing_id == "force_harmonic_1"
        return 2
    elseif spec.forcing_id == "force_harmonic_2"
        return 4
    elseif spec.forcing_id == "force_lorenz_readout"
        return 3
    else
        throw(ArgumentError("unsupported forcing_id: $(spec.forcing_id)"))
    end
end

## force_harmonic_1 specification

function kdsm_validate_forcing_spec(spec::KDSMDuffingForcingSpec)
    spec.forcing_id in (
        "force_none",
        "force_harmonic_1",
        "force_harmonic_2",
        "force_lorenz_readout",
    ) || throw(ArgumentError("unsupported forcing_id: $(spec.forcing_id)"))
    if spec.forcing_id == "force_harmonic_1"
        haskey(spec.params, "omega") || throw(ArgumentError("force_harmonic_1 requires omega"))
        spec.params["omega"] > 0 || throw(ArgumentError("omega must be positive"))
    elseif spec.forcing_id == "force_harmonic_2"
        for key in ("omega1", "omega2", "eta")
            haskey(spec.params, key) || throw(ArgumentError("force_harmonic_2 requires $(key)"))
        end
        spec.params["omega1"] > 0 || throw(ArgumentError("omega1 must be positive"))
        spec.params["omega2"] > 0 || throw(ArgumentError("omega2 must be positive"))
    end
    return true
end

## Forcing initial-condition construction

function kdsm_forcing_initial_state(
    rng::AbstractRNG,
    spec::KDSMDuffingForcingSpec,
)
    d_u = kdsm_forcing_state_dim(spec)
    u0 = Vector{Float64}(undef, d_u)
    if spec.forcing_id == "force_none"
        return u0, Dict{String,Any}()
    elseif spec.forcing_id == "force_harmonic_1"
        phi = 2.0 * pi * rand(rng)
        u0[1] = cos(phi)
        u0[2] = sin(phi)
        return u0, Dict{String,Any}("phase_1" => phi)
    elseif spec.forcing_id == "force_harmonic_2"
        phi1 = 2.0 * pi * rand(rng)
        phi2 = 2.0 * pi * rand(rng)
        u0[1] = cos(phi1)
        u0[2] = sin(phi1)
        u0[3] = cos(phi2)
        u0[4] = sin(phi2)
        return u0, Dict{String,Any}("phase_1" => phi1, "phase_2" => phi2)
    elseif spec.forcing_id == "force_lorenz_readout"
        u0 .= (1.0 .+ 0.1 .* randn(rng, 3))
        return u0, Dict{String,Any}("lorenz_readout_initialization" => "near_ones")
    end
    error("unreachable forcing id")
end

## Forcing readout validation

function kdsm_forcing_signal(spec::KDSMDuffingForcingSpec, x::AbstractVector{<:Real})
    if spec.forcing_id == "force_none"
        return 0.0
    elseif spec.forcing_id == "force_harmonic_1"
        return Float64(x[3])
    elseif spec.forcing_id == "force_harmonic_2"
        return Float64(x[3] + spec.params["eta"] * x[5])
    elseif spec.forcing_id == "force_lorenz_readout"
        return tanh(Float64(x[3]) / spec.params["s_L"])
    end
    error("unreachable forcing id")
end

## Forcing invariant checks

function kdsm_forcing_rhs!(
    dx::AbstractVector{Float64},
    x::AbstractVector{Float64},
    spec::KDSMDuffingForcingSpec,
)
    if spec.forcing_id == "force_none"
        return dx
    elseif spec.forcing_id == "force_harmonic_1"
        omega = spec.params["omega"]
        dx[3] = -omega * x[4]
        dx[4] = omega * x[3]
    elseif spec.forcing_id == "force_harmonic_2"
        omega1 = spec.params["omega1"]
        omega2 = spec.params["omega2"]
        dx[3] = -omega1 * x[4]
        dx[4] = omega1 * x[3]
        dx[5] = -omega2 * x[6]
        dx[6] = omega2 * x[5]
    elseif spec.forcing_id == "force_lorenz_readout"
        sigma_L = spec.params["sigma_L"]
        rho_L = spec.params["rho_L"]
        b_L = spec.params["b_L"]
        u1, u2, u3 = x[3], x[4], x[5]
        dx[3] = sigma_L * (u2 - u1)
        dx[4] = u1 * (rho_L - u3) - u2
        dx[5] = u1 * u2 - b_L * u3
    else
        throw(ArgumentError("unsupported forcing_id: $(spec.forcing_id)"))
    end
    return dx
end
