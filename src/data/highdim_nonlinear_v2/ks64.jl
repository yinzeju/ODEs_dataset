Base.@kwdef struct HDNDKSSpec
    nx::Int = 64
    domain_length::Float64 = 22.0
    tau::Float64 = 0.05
    dt::Float64 = 0.01
    reference_dt::Float64 = 0.005
    contour_nodes::Int = 64
    reference_nx::Int = 128
end

struct HDNDKSStepper
    kappa::Vector{Float64}
    mask::Vector{Float64}
    E::Vector{ComplexF64}
    E2::Vector{ComplexF64}
    Q::Vector{ComplexF64}
    f1::Vector{ComplexF64}
    f2::Vector{ComplexF64}
    f3::Vector{ComplexF64}
end

function hdnd_fft_modes(nx::Integer)
    return vcat(0:(nx ÷ 2), (-(nx ÷ 2 - 1)):-1)
end

function hdnd_ks_stepper(spec::HDNDKSSpec; nx::Integer = spec.nx, dt::Real = spec.dt)
    modes = hdnd_fft_modes(nx)
    kappa = (2π / spec.domain_length) .* Float64.(modes)
    linear = kappa .^ 2 .- kappa .^ 4
    E = exp.(dt .* linear)
    E2 = exp.((dt / 2) .* linear)
    roots = exp.(im * π .* (((1:spec.contour_nodes) .- 0.5) ./ spec.contour_nodes))
    Q = similar(E, ComplexF64); f1 = similar(Q); f2 = similar(Q); f3 = similar(Q)
    for j in eachindex(linear)
        lr = dt * linear[j] .+ roots
        Q[j] = dt * real(mean((exp.(lr ./ 2) .- 1) ./ lr))
        f1[j] = dt * real(mean((-4 .- lr .+ exp.(lr) .* (4 .- 3 .* lr .+ lr .^ 2)) ./ lr .^ 3))
        f2[j] = dt * real(mean((2 .+ lr .+ exp.(lr) .* (-2 .+ lr)) ./ lr .^ 3))
        f3[j] = dt * real(mean((-4 .- 3 .* lr .- lr .^ 2 .+ exp.(lr) .* (4 .- lr)) ./ lr .^ 3))
    end
    cutoff = floor(Int, nx / 3)
    mask = Float64.(abs.(modes) .<= cutoff)
    return HDNDKSStepper(kappa, mask, ComplexF64.(E), ComplexF64.(E2), Q, f1, f2, f3)
end

function hdnd_ks_nonlinear(vhat::AbstractVector{ComplexF64}, stepper::HDNDKSStepper)
    u = real.(ifft(vhat))
    result = -0.5im .* stepper.kappa .* fft(u .^ 2)
    result .*= stepper.mask
    result[1] = 0.0im
    return result
end

function hdnd_ks_step(vhat::Vector{ComplexF64}, stepper::HDNDKSStepper)
    nv = hdnd_ks_nonlinear(vhat, stepper)
    a = stepper.E2 .* vhat .+ stepper.Q .* nv
    na = hdnd_ks_nonlinear(a, stepper)
    b = stepper.E2 .* vhat .+ stepper.Q .* na
    nb = hdnd_ks_nonlinear(b, stepper)
    c = stepper.E2 .* a .+ stepper.Q .* (2 .* nb .- nv)
    nc = hdnd_ks_nonlinear(c, stepper)
    next = stepper.E .* vhat .+ stepper.f1 .* nv .+ 2 .* stepper.f2 .* (na .+ nb) .+ stepper.f3 .* nc
    physical = real.(ifft(next))
    physical .-= mean(physical)
    next = fft(physical)
    next .*= stepper.mask
    next[1] = 0.0im
    return next
end

function sample_hdnd_ks_initial_condition(rng::AbstractRNG, spec::HDNDKSSpec; nx::Integer = spec.nx)
    vhat = zeros(ComplexF64, nx)
    for mode in 1:8
        alpha = (randn(rng) + im * randn(rng)) / sqrt(2)
        coefficient = alpha / (1 + (mode / 4)^4)
        vhat[mode + 1] = nx * coefficient
        vhat[nx - mode + 1] = nx * conj(coefficient)
    end
    field = real.(ifft(vhat))
    field .-= mean(field)
    target_rms = 0.5 + 0.5 * rand(rng)
    field .*= target_rms / sqrt(mean(abs2, field))
    return field
end

function solve_hdnd_ks_trajectory(
    initial::Vector{Float64},
    spec::HDNDKSSpec,
    warm::Real,
    steps::Integer;
    nx::Integer = spec.nx,
    dt::Real = spec.dt,
)
    stepper = hdnd_ks_stepper(spec; nx = nx, dt = dt)
    vhat = fft(initial)
    warm_steps = round(Int, warm / dt)
    stride = round(Int, spec.tau / dt)
    isapprox(warm_steps * dt, warm; atol = 1.0e-12, rtol = 0.0) || error("KS warm-up must be divisible by dt")
    isapprox(stride * dt, spec.tau; atol = 1.0e-12, rtol = 0.0) || error("KS tau must be divisible by dt")
    for _ in 1:warm_steps
        vhat = hdnd_ks_step(vhat, stepper)
    end
    trajectory = Matrix{Float64}(undef, steps + 1, nx)
    trajectory[1, :] .= real.(ifft(vhat))
    trajectory[1, :] .-= mean(@view trajectory[1, :])
    for m in 1:steps
        for _ in 1:stride
            vhat = hdnd_ks_step(vhat, stepper)
        end
        trajectory[m + 1, :] .= real.(ifft(vhat))
        trajectory[m + 1, :] .-= mean(@view trajectory[m + 1, :])
    end
    return trajectory
end

function hdnd_fourier_resize(field::AbstractVector{<:Real}, output_nx::Integer)
    input_nx = length(field)
    input_coefficients = fft(field) ./ input_nx
    output_coefficients = zeros(ComplexF64, output_nx)
    for mode in hdnd_fft_modes(input_nx)
        if abs(mode) < output_nx ÷ 2
            input_index = mode >= 0 ? mode + 1 : input_nx + mode + 1
            output_index = mode >= 0 ? mode + 1 : output_nx + mode + 1
            output_coefficients[output_index] = input_coefficients[input_index]
        end
    end
    result = real.(ifft(output_coefficients .* output_nx))
    result .-= mean(result)
    return result
end

function hdnd_ks_time_space_errors(states::AbstractVector{<:AbstractVector}, spec::HDNDKSSpec)
    time_num = 0.0; time_den = 0.0; space_num = 0.0; space_den = 0.0
    time_samples = Float64[]; space_samples = Float64[]
    for state in states
        initial = collect(Float64, state)
        production = vec(solve_hdnd_ks_trajectory(initial, spec, 0.0, 1)[end, :])
        time_reference = vec(solve_hdnd_ks_trajectory(initial, spec, 0.0, 1; dt = spec.reference_dt)[end, :])
        high_initial = hdnd_fourier_resize(initial, spec.reference_nx)
        high_reference = vec(solve_hdnd_ks_trajectory(high_initial, spec, 0.0, 1; nx = spec.reference_nx, dt = spec.reference_dt)[end, :])
        space_reference = hdnd_fourier_resize(high_reference, spec.nx)
        tdiff = sum(abs2, production .- time_reference); tref = sum(abs2, time_reference)
        sdiff = sum(abs2, production .- space_reference); sref = sum(abs2, space_reference)
        time_num += tdiff; time_den += tref; space_num += sdiff; space_den += sref
        push!(time_samples, sqrt(tdiff / (tref + eps(Float64))))
        push!(space_samples, sqrt(sdiff / (sref + eps(Float64))))
    end
    return Dict(
        "time_one_step_error" => sqrt(time_num / (time_den + eps(Float64))),
        "space_one_step_error" => sqrt(space_num / (space_den + eps(Float64))),
        "time_sample_errors" => time_samples,
        "space_sample_errors" => space_samples,
        "sample_count" => length(states),
        "time_threshold" => 1.0e-6,
    )
end

function hdnd_ks_tangent_nonlinear(vhat::Vector{ComplexF64}, tangent::Matrix{ComplexF64}, stepper::HDNDKSStepper)
    u = real.(ifft(vhat))
    du = real.(ifft(tangent, 1))
    result = (-im .* stepper.kappa) .* fft(u .* du, 1)
    result .*= stepper.mask
    result[1, :] .= 0.0im
    return result
end

function hdnd_ks_step_tangent(vhat, tangent, stepper)
    nv = hdnd_ks_nonlinear(vhat, stepper)
    dnv = hdnd_ks_tangent_nonlinear(vhat, tangent, stepper)
    a = stepper.E2 .* vhat .+ stepper.Q .* nv
    da = stepper.E2 .* tangent .+ stepper.Q .* dnv
    na = hdnd_ks_nonlinear(a, stepper); dna = hdnd_ks_tangent_nonlinear(a, da, stepper)
    b = stepper.E2 .* vhat .+ stepper.Q .* na
    db = stepper.E2 .* tangent .+ stepper.Q .* dna
    nb = hdnd_ks_nonlinear(b, stepper); dnb = hdnd_ks_tangent_nonlinear(b, db, stepper)
    c = stepper.E2 .* a .+ stepper.Q .* (2 .* nb .- nv)
    dc = stepper.E2 .* da .+ stepper.Q .* (2 .* dnb .- dnv)
    nc = hdnd_ks_nonlinear(c, stepper); dnc = hdnd_ks_tangent_nonlinear(c, dc, stepper)
    next = stepper.E .* vhat .+ stepper.f1 .* nv .+ 2 .* stepper.f2 .* (na .+ nb) .+ stepper.f3 .* nc
    dnext = stepper.E .* tangent .+ stepper.f1 .* dnv .+ 2 .* stepper.f2 .* (dna .+ dnb) .+ stepper.f3 .* dnc
    physical = real.(ifft(next))
    physical .-= mean(physical)
    next = fft(physical)
    physical_tangent = real.(ifft(dnext, 1))
    physical_tangent .-= mean(physical_tangent; dims = 1)
    dnext = fft(physical_tangent, 1)
    next .*= stepper.mask; dnext .*= stepper.mask
    next[1] = 0.0im; dnext[1, :] .= 0.0im
    return next, dnext
end

function hdnd_ks_lyapunov(initial::AbstractVector, spec::HDNDKSSpec, duration::Real)
    stepper = hdnd_ks_stepper(spec)
    vhat = fft(initial)
    tangent = fft(Matrix{Float64}(I, spec.nx, spec.nx), 1)
    steps_per_qr = round(Int, spec.tau / spec.dt)
    blocks = max(1, round(Int, duration / spec.tau))
    sums = zeros(Float64, spec.nx)
    for _ in 1:blocks
        for _ in 1:steps_per_qr
            vhat, tangent = hdnd_ks_step_tangent(vhat, tangent, stepper)
        end
        physical_tangent = real.(ifft(tangent, 1))
        factor = qr(physical_tangent)
        q = Matrix(factor.Q)
        sums .+= log.(max.(abs.(diag(factor.R)), eps(Float64)))
        tangent = fft(q, 1)
    end
    result = lyapunov_summary(sums ./ (blocks * spec.tau))
    result["integration_time"] = blocks * spec.tau
    result["qr_interval"] = spec.tau
    result["diagnostic_trajectory_count"] = 1
    return result
end

function hdnd_ks_energy(trajectory::AbstractMatrix)
    return vec(sum(abs2, trajectory; dims = 2) ./ (2 * size(trajectory, 2)))
end

function hdnd_ks_spectrum(trajectory::AbstractMatrix; stride::Integer = 10)
    spectrum = zeros(Float64, size(trajectory, 2))
    count = 0
    for m in 1:stride:size(trajectory, 1)
        spectrum .+= abs2.(fft(@view trajectory[m, :])) ./ size(trajectory, 2)^2
        count += 1
    end
    return spectrum ./ count
end
