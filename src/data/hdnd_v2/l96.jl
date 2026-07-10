Base.@kwdef struct HDNDL96Spec
    nx::Int = 40
    forcing::Float64 = 8.0
    tau::Float64 = 0.05
    reltol::Float64 = 1.0e-10
    abstol::Float64 = 1.0e-12
    dtmax::Float64 = 0.01
    reference_reltol::Float64 = 1.0e-12
    reference_abstol::Float64 = 1.0e-14
    reference_dtmax::Float64 = 0.0025
end

function hdnd_l96_rhs!(du::AbstractVector, x::AbstractVector, spec::HDNDL96Spec, _t)
    nx = spec.nx
    @inbounds for j in 1:nx
        jm2 = mod1(j - 2, nx)
        jm1 = mod1(j - 1, nx)
        jp1 = mod1(j + 1, nx)
        du[j] = (x[jp1] - x[jm2]) * x[jm1] - x[j] + spec.forcing
    end
    return nothing
end

function hdnd_l96_boundary_check(spec::HDNDL96Spec)
    x = collect(1.0:spec.nx)
    du = similar(x)
    hdnd_l96_rhs!(du, x, spec, 0.0)
    first_expected = (x[2] - x[39]) * x[40] - x[1] + spec.forcing
    last_expected = (x[1] - x[38]) * x[39] - x[40] + spec.forcing
    return isapprox(du[1], first_expected; atol = 0.0, rtol = 0.0) &&
        isapprox(du[40], last_expected; atol = 0.0, rtol = 0.0)
end

function sample_hdnd_l96_initial_condition(rng::AbstractRNG, spec::HDNDL96Spec)
    return spec.forcing .+ 0.01 .* randn(rng, spec.nx)
end

function solve_hdnd_l96_trajectory(
    initial::Vector{Float64},
    spec::HDNDL96Spec,
    burn::Real,
    steps::Integer;
    reference::Bool = false,
)
    record_time = steps * spec.tau
    save_times = burn .+ (0:steps) .* spec.tau
    prob = ODEProblem(hdnd_l96_rhs!, initial, (0.0, burn + record_time), spec)
    if reference
        solution = solve(
            prob,
            Vern9();
            reltol = spec.reference_reltol,
            abstol = spec.reference_abstol,
            dtmax = spec.reference_dtmax,
            saveat = save_times,
            save_everystep = false,
        )
    else
        solution = solve(
            prob,
            Vern9();
            reltol = spec.reltol,
            abstol = spec.abstol,
            dtmax = spec.dtmax,
            saveat = save_times,
            save_everystep = false,
        )
    end
    solution.retcode == ReturnCode.Success || error("L96 integration failed: $(solution.retcode)")
    trajectory = Matrix{Float64}(undef, steps + 1, spec.nx)
    @inbounds for i in eachindex(solution.u)
        trajectory[i, :] .= solution.u[i]
    end
    return trajectory
end

function propagate_hdnd_l96_one_step(state::Vector{Float64}, spec::HDNDL96Spec; reference::Bool = false)
    return vec(solve_hdnd_l96_trajectory(state, spec, 0.0, 1; reference = reference)[end, :])
end

function hdnd_l96_time_error(states::AbstractVector{<:AbstractVector}, spec::HDNDL96Spec)
    numerator = 0.0
    denominator = 0.0
    errors = Float64[]
    for state in states
        production = propagate_hdnd_l96_one_step(collect(state), spec)
        reference = propagate_hdnd_l96_one_step(collect(state), spec; reference = true)
        difference2 = sum(abs2, production .- reference)
        reference2 = sum(abs2, reference)
        numerator += difference2
        denominator += reference2
        push!(errors, sqrt(difference2 / (reference2 + eps(Float64))))
    end
    return Dict(
        "time_one_step_error" => sqrt(numerator / (denominator + eps(Float64))),
        "sample_errors" => errors,
        "sample_count" => length(states),
        "threshold" => 1.0e-8,
    )
end

function hdnd_l96_jacobian!(jacobian::AbstractMatrix, x::AbstractVector, spec::HDNDL96Spec)
    fill!(jacobian, 0.0)
    nx = spec.nx
    @inbounds for j in 1:nx
        jm2 = mod1(j - 2, nx)
        jm1 = mod1(j - 1, nx)
        jp1 = mod1(j + 1, nx)
        jacobian[j, jm2] = -x[jm1]
        jacobian[j, jm1] = x[jp1] - x[jm2]
        jacobian[j, j] = -1.0
        jacobian[j, jp1] = x[jm1]
    end
    return jacobian
end

function hdnd_l96_tangent_rhs!(dx, dq, x, q, spec, jacobian)
    hdnd_l96_rhs!(dx, x, spec, 0.0)
    hdnd_l96_jacobian!(jacobian, x, spec)
    mul!(dq, jacobian, q)
    return nothing
end

function hdnd_l96_rk4_tangent_step(x, q, spec, dt)
    nx = spec.nx
    jacobian = Matrix{Float64}(undef, nx, nx)
    k1x = similar(x); k2x = similar(x); k3x = similar(x); k4x = similar(x)
    k1q = similar(q); k2q = similar(q); k3q = similar(q); k4q = similar(q)
    xtmp = similar(x); qtmp = similar(q)
    hdnd_l96_tangent_rhs!(k1x, k1q, x, q, spec, jacobian)
    xtmp .= x .+ (dt / 2) .* k1x; qtmp .= q .+ (dt / 2) .* k1q
    hdnd_l96_tangent_rhs!(k2x, k2q, xtmp, qtmp, spec, jacobian)
    xtmp .= x .+ (dt / 2) .* k2x; qtmp .= q .+ (dt / 2) .* k2q
    hdnd_l96_tangent_rhs!(k3x, k3q, xtmp, qtmp, spec, jacobian)
    xtmp .= x .+ dt .* k3x; qtmp .= q .+ dt .* k3q
    hdnd_l96_tangent_rhs!(k4x, k4q, xtmp, qtmp, spec, jacobian)
    xnext = x .+ (dt / 6) .* (k1x .+ 2 .* k2x .+ 2 .* k3x .+ k4x)
    qnext = q .+ (dt / 6) .* (k1q .+ 2 .* k2q .+ 2 .* k3q .+ k4q)
    return xnext, qnext
end

function hdnd_l96_lyapunov(initial::AbstractVector, spec::HDNDL96Spec, duration::Real)
    dt = spec.reference_dtmax
    qr_interval = spec.tau
    steps_per_qr = round(Int, qr_interval / dt)
    blocks = max(1, round(Int, duration / qr_interval))
    x = collect(Float64, initial)
    q = Matrix{Float64}(I, spec.nx, spec.nx)
    sums = zeros(Float64, spec.nx)
    for _ in 1:blocks
        for _ in 1:steps_per_qr
            x, q = hdnd_l96_rk4_tangent_step(x, q, spec, dt)
        end
        factor = qr(q)
        q .= Matrix(factor.Q)
        diagonal = abs.(diag(factor.R))
        sums .+= log.(max.(diagonal, eps(Float64)))
    end
    result = lyapunov_summary(sums ./ (blocks * qr_interval))
    result["integration_time"] = blocks * qr_interval
    result["qr_interval"] = qr_interval
    result["diagnostic_trajectory_count"] = 1
    return result
end

function hdnd_l96_energy(trajectory::AbstractMatrix)
    return vec(sum(abs2, trajectory; dims = 2) ./ (2 * size(trajectory, 2)))
end

function hdnd_l96_spatial_variance(trajectory::AbstractMatrix)
    return vec(var(trajectory; dims = 2, corrected = false))
end
