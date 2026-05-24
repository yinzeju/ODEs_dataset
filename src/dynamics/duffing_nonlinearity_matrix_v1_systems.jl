## Duffing nonlinearity matrix v1 system definitions and high-accuracy stepping

using LinearAlgebra
using Random

struct DuffingNLMatrixSpec
    dataset_id::String
    object_id::String
    object_kind::String
    system_family::String
    alpha::Float64
    delta::Float64
    beta::Float64
    gamma::Float64
    amplitude_Q::Float64
    chi_nl::Float64
    damping_radius::Float64
    omega::Float64
    tau::Float64
    M::Int
    R::Int
    R_train::Int
    R_val::Int
    R_test::Int
    initial_condition_seed::Int
    solver_name::String
    reltol::Float64
    abstol::Float64
    max_internal_step::Float64
    energy_tolerance::Float64
end

function dnlmat_beta_code(beta::Real)
    return lpad(string(round(Int, 1000.0 * Float64(beta))), 4, '0')
end

function dnlmat_Q_code(Q::Real)
    return lpad(string(round(Int, 100.0 * Float64(Q))), 3, '0')
end

function dnlmat_duffing_object_id(beta::Real, Q::Real)
    return string("duffing_nlmat__D_beta_", dnlmat_beta_code(beta), "__Q_", dnlmat_Q_code(Q))
end

function dnlmat_discrete_rotation_matrix(spec::DuffingNLMatrixSpec)
    c = cos(spec.omega)
    s = sin(spec.omega)
    return spec.damping_radius .* [c -s; s c]
end

function dnlmat_linear_generator_matrix(spec::DuffingNLMatrixSpec)
    return [0.0 1.0; -spec.alpha -spec.delta]
end

function dnlmat_linear_flow_matrix(spec::DuffingNLMatrixSpec)
    return exp(spec.tau .* dnlmat_linear_generator_matrix(spec))
end

@inline function dnlmat_rhs(q::Float64, p::Float64, alpha::Float64, delta::Float64, beta::Float64)
    return p, -delta * p - alpha * q - beta * q^3
end

@inline function dnlmat_dopri5_trial(
    q::Float64,
    p::Float64,
    h::Float64,
    alpha::Float64,
    delta::Float64,
    beta::Float64,
    reltol::Float64,
    abstol::Float64,
)
    k1q, k1p = dnlmat_rhs(q, p, alpha, delta, beta)

    q2 = q + h * (1.0 / 5.0) * k1q
    p2 = p + h * (1.0 / 5.0) * k1p
    k2q, k2p = dnlmat_rhs(q2, p2, alpha, delta, beta)

    q3 = q + h * ((3.0 / 40.0) * k1q + (9.0 / 40.0) * k2q)
    p3 = p + h * ((3.0 / 40.0) * k1p + (9.0 / 40.0) * k2p)
    k3q, k3p = dnlmat_rhs(q3, p3, alpha, delta, beta)

    q4 = q + h * ((44.0 / 45.0) * k1q - (56.0 / 15.0) * k2q + (32.0 / 9.0) * k3q)
    p4 = p + h * ((44.0 / 45.0) * k1p - (56.0 / 15.0) * k2p + (32.0 / 9.0) * k3p)
    k4q, k4p = dnlmat_rhs(q4, p4, alpha, delta, beta)

    q5 = q + h * (
        (19372.0 / 6561.0) * k1q - (25360.0 / 2187.0) * k2q +
        (64448.0 / 6561.0) * k3q - (212.0 / 729.0) * k4q
    )
    p5 = p + h * (
        (19372.0 / 6561.0) * k1p - (25360.0 / 2187.0) * k2p +
        (64448.0 / 6561.0) * k3p - (212.0 / 729.0) * k4p
    )
    k5q, k5p = dnlmat_rhs(q5, p5, alpha, delta, beta)

    q6 = q + h * (
        (9017.0 / 3168.0) * k1q - (355.0 / 33.0) * k2q +
        (46732.0 / 5247.0) * k3q + (49.0 / 176.0) * k4q -
        (5103.0 / 18656.0) * k5q
    )
    p6 = p + h * (
        (9017.0 / 3168.0) * k1p - (355.0 / 33.0) * k2p +
        (46732.0 / 5247.0) * k3p + (49.0 / 176.0) * k4p -
        (5103.0 / 18656.0) * k5p
    )
    k6q, k6p = dnlmat_rhs(q6, p6, alpha, delta, beta)

    q7 = q + h * (
        (35.0 / 384.0) * k1q + (500.0 / 1113.0) * k3q +
        (125.0 / 192.0) * k4q - (2187.0 / 6784.0) * k5q +
        (11.0 / 84.0) * k6q
    )
    p7 = p + h * (
        (35.0 / 384.0) * k1p + (500.0 / 1113.0) * k3p +
        (125.0 / 192.0) * k4p - (2187.0 / 6784.0) * k5p +
        (11.0 / 84.0) * k6p
    )
    k7q, k7p = dnlmat_rhs(q7, p7, alpha, delta, beta)

    q4th = q + h * (
        (5179.0 / 57600.0) * k1q + (7571.0 / 16695.0) * k3q +
        (393.0 / 640.0) * k4q - (92097.0 / 339200.0) * k5q +
        (187.0 / 2100.0) * k6q + (1.0 / 40.0) * k7q
    )
    p4th = p + h * (
        (5179.0 / 57600.0) * k1p + (7571.0 / 16695.0) * k3p +
        (393.0 / 640.0) * k4p - (92097.0 / 339200.0) * k5p +
        (187.0 / 2100.0) * k6p + (1.0 / 40.0) * k7p
    )

    scale_q = abstol + reltol * max(abs(q), abs(q7))
    scale_p = abstol + reltol * max(abs(p), abs(p7))
    err_q = abs(q7 - q4th) / scale_q
    err_p = abs(p7 - p4th) / scale_p
    err_norm = max(err_q, err_p)
    return q7, p7, err_norm
end

function dnlmat_integrate_interval(
    q0::Float64,
    p0::Float64,
    dt::Float64,
    spec::DuffingNLMatrixSpec,
)
    t = 0.0
    q = q0
    p = p0
    h = min(spec.max_internal_step, dt)
    min_h = max(eps(Float64), dt * 1.0e-12)
    accepted = 0
    rejected = 0
    while t < dt
        h = min(h, dt - t, spec.max_internal_step)
        q_new, p_new, err_norm = dnlmat_dopri5_trial(
            q,
            p,
            h,
            spec.alpha,
            spec.delta,
            spec.beta,
            spec.reltol,
            spec.abstol,
        )
        if err_norm <= 1.0 || h <= min_h
            q = q_new
            p = p_new
            t += h
            accepted += 1
        else
            rejected += 1
        end
        factor = err_norm == 0.0 ? 5.0 : clamp(0.9 * err_norm^(-0.2), 0.1, 5.0)
        h = clamp(h * factor, min_h, spec.max_internal_step)
        accepted + rejected <= 1_000_000 ||
            throw(ArgumentError("adaptive integration exceeded step budget"))
    end
    return q, p, accepted, rejected
end

function dnlmat_generate_trajectory(spec::DuffingNLMatrixSpec, x0::AbstractVector{<:Real})
    length(x0) == 2 || throw(ArgumentError("initial condition must be length 2"))
    X = Matrix{Float64}(undef, spec.M + 1, 2)
    X[1, 1] = Float64(x0[1])
    X[1, 2] = Float64(x0[2])
    if spec.object_kind == "L0"
        A = dnlmat_discrete_rotation_matrix(spec)
        @inbounds for m in 1:spec.M
            q = X[m, 1]
            p = X[m, 2]
            X[m + 1, 1] = A[1, 1] * q + A[1, 2] * p
            X[m + 1, 2] = A[2, 1] * q + A[2, 2] * p
        end
    else
        q = X[1, 1]
        p = X[1, 2]
        @inbounds for m in 1:spec.M
            q, p, _, _ = dnlmat_integrate_interval(q, p, spec.tau, spec)
            X[m + 1, 1] = q
            X[m + 1, 2] = p
        end
    end
    all(isfinite, X) || throw(ArgumentError("non-finite trajectory for $(spec.object_id)"))
    return X
end

function dnlmat_sample_initial_conditions(Q::Real, R::Integer, seed::Integer)
    rng = MersenneTwister(Int(seed) + round(Int, 10_000.0 * Float64(Q)))
    x0s = Matrix{Float64}(undef, Int(R), 2)
    q_min = Inf
    q_max = -Inf
    p_min = Inf
    p_max = -Inf
    for r in 1:Int(R)
        theta = 2.0 * pi * rand(rng)
        u = rand(rng)
        radius = sqrt((0.75 * Float64(Q))^2 + u * (Float64(Q)^2 - (0.75 * Float64(Q))^2))
        q0 = radius * cos(theta)
        p0 = radius * sin(theta)
        x0s[r, 1] = q0
        x0s[r, 2] = p0
        q_min = min(q_min, q0)
        q_max = max(q_max, q0)
        p_min = min(p_min, p0)
        p_max = max(p_max, p0)
    end
    stats = Dict(
        "Q" => Float64(Q),
        "q0_min" => q_min,
        "q0_max" => q_max,
        "p0_min" => p_min,
        "p0_max" => p_max,
        "radius_min" => minimum(hypot(x0s[r, 1], x0s[r, 2]) for r in axes(x0s, 1)),
        "radius_max" => maximum(hypot(x0s[r, 1], x0s[r, 2]) for r in axes(x0s, 1)),
    )
    return x0s, stats
end

function dnlmat_time_grid(spec::DuffingNLMatrixSpec)
    return collect(range(0.0; step = spec.tau, length = spec.M + 1))
end

function dnlmat_matrix_rows(A::AbstractMatrix{<:Real})
    return [[Float64(A[i, j]) for j in axes(A, 2)] for i in axes(A, 1)]
end

function dnlmat_complex_parts(values::AbstractVector{<:Complex})
    return Dict(
        "real" => Float64.(real.(values)),
        "imag" => Float64.(imag.(values)),
    )
end

function dnlmat_true_system_metadata(spec::DuffingNLMatrixSpec)
    if spec.object_kind == "L0"
        A = dnlmat_discrete_rotation_matrix(spec)
        lambdas = ComplexF64[
            spec.damping_radius * cis(spec.omega),
            spec.damping_radius * cis(-spec.omega),
        ]
        return Dict{String,Any}(
            "true_discrete_matrix" => dnlmat_matrix_rows(A),
            "true_continuous_matrix" => Vector{Vector{Float64}}(),
            "true_discrete_spectrum" => dnlmat_complex_parts(lambdas),
            "true_continuous_spectrum" => Dict("real" => Float64[], "imag" => Float64[]),
        )
    elseif spec.object_kind == "L1" || spec.beta == 0.0
        A = dnlmat_linear_generator_matrix(spec)
        F = dnlmat_linear_flow_matrix(spec)
        omega_d = sqrt(spec.alpha - spec.delta^2 / 4.0)
        continuous = ComplexF64[
            -spec.delta / 2.0 + im * omega_d,
            -spec.delta / 2.0 - im * omega_d,
        ]
        discrete = exp.(spec.tau .* continuous)
        return Dict{String,Any}(
            "true_discrete_matrix" => dnlmat_matrix_rows(F),
            "true_continuous_matrix" => dnlmat_matrix_rows(A),
            "true_discrete_spectrum" => dnlmat_complex_parts(discrete),
            "true_continuous_spectrum" => dnlmat_complex_parts(continuous),
        )
    end
    return Dict{String,Any}(
        "true_discrete_matrix" => Vector{Vector{Float64}}(),
        "true_continuous_matrix" => Vector{Vector{Float64}}(),
        "true_discrete_spectrum" => Dict("real" => Float64[], "imag" => Float64[]),
        "true_continuous_spectrum" => Dict("real" => Float64[], "imag" => Float64[]),
    )
end

@inline function dnlmat_energy(q::Float64, p::Float64, alpha::Float64, beta::Float64)
    return 0.5 * p^2 + 0.5 * alpha * q^2 + 0.25 * beta * q^4
end
