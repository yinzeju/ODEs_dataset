using Dates
using FFTW
using HDF5
using JSON
using LinearAlgebra
using OrdinaryDiffEq
import Plots
using Printf
using Random
using SciMLBase
using Statistics
using TOML

const PDEID_TASK_CODE = "pdeid_fhn32_fhn64_ks64"
const PDEID_HORIZONS = [1, 2, 4, 8, 16, 32, 64]

Base.@kwdef struct PdeidProfile
    name::Symbol
    R_train::Int
    R_val::Int
    R_test::Int
    M::Int
    tau::Float64
    fhn_warm::Float64
    ks_warm::Float64
    ks_dt::Float64
    fhn_reltol::Float64
    fhn_abstol::Float64
    fhn_activity_threshold::Float64
    seed::Int
    output_root::String
    report_root::String
    max_attempts_per_trajectory::Int
end

Base.@kwdef struct FhnPdeSpec
    object_id::String
    nx::Int
    L::Float64 = 32.0
    Du::Float64 = 1.0
    Dv::Float64 = 0.0
    epsilon::Float64 = 0.08
    a::Float64 = 0.7
    b::Float64 = 0.8
end

Base.@kwdef struct KsPdeSpec
    object_id::String = "ks64"
    nx::Int = 64
    L::Float64 = 22.0
    dt::Float64 = 0.05
    contour_nodes::Int = 32
end

struct KsStepper
    kappa::Vector{Float64}
    mask::Vector{Float64}
    E::Vector{ComplexF64}
    E2::Vector{ComplexF64}
    Q::Vector{ComplexF64}
    f1::Vector{ComplexF64}
    f2::Vector{ComplexF64}
    f3::Vector{ComplexF64}
end

function pdeid_profile(project_root::AbstractString, name::Symbol)
    if name == :formal
        return PdeidProfile(
            name = :formal,
            R_train = 320,
            R_val = 80,
            R_test = 80,
            M = 1024,
            tau = 0.25,
            fhn_warm = 32.0,
            ks_warm = 200.0,
            ks_dt = 0.05,
            fhn_reltol = 1.0e-8,
            fhn_abstol = 1.0e-10,
            fhn_activity_threshold = 0.35,
            seed = 20260703,
            output_root = joinpath(project_root, "data", "pdeid_fhn32_fhn64_ks64_julia"),
            report_root = joinpath(project_root, "reports", "v1_plus", PDEID_TASK_CODE),
            max_attempts_per_trajectory = 120,
        )
    elseif name == :smoke
        return PdeidProfile(
            name = :smoke,
            R_train = 4,
            R_val = 1,
            R_test = 1,
            M = 16,
            tau = 0.25,
            fhn_warm = 2.0,
            ks_warm = 2.0,
            ks_dt = 0.05,
            fhn_reltol = 1.0e-7,
            fhn_abstol = 1.0e-9,
            fhn_activity_threshold = 0.5,
            seed = 20260703,
            output_root = joinpath(project_root, "runs", "smoke_tests", "pdeid_fhn32_fhn64_ks64_julia"),
            report_root = joinpath(project_root, "runs", "smoke_tests", "pdeid_fhn32_fhn64_ks64_report"),
            max_attempts_per_trajectory = 40,
        )
    else
        throw(ArgumentError("unsupported profile: $name"))
    end
end

total_trajectory_count(profile::PdeidProfile) = profile.R_train + profile.R_val + profile.R_test

function split_indices(profile::PdeidProfile)
    rtrain = collect(1:profile.R_train)
    rval = collect((last(rtrain) + 1):(last(rtrain) + profile.R_val))
    rtest = collect((last(rval) + 1):(last(rval) + profile.R_test))
    return Dict("train" => rtrain, "val" => rval, "test" => rtest)
end

function ensure_dir(path::AbstractString)
    mkpath(path)
    return path
end

function fhn_equilibrium(spec::FhnPdeSpec)
    u = -1.2
    for _ in 1:40
        f = u - u^3 / 3 - (u + spec.a) / spec.b
        df = 1 - u^2 - 1 / spec.b
        u -= f / df
    end
    v = (u + spec.a) / spec.b
    return u, v
end

periodic_distance(x::Real, c::Real, L::Real) = min(abs(x - c), L - abs(x - c))

function unit_rms_low_frequency_field(rng::AbstractRNG, x::AbstractVector{<:Real}, L::Real)
    y = zeros(Float64, length(x))
    for k in 1:3
        amp_cos = randn(rng)
        amp_sin = randn(rng)
        phase = 2π * k / L
        @inbounds for j in eachindex(x)
            y[j] += amp_cos * cos(phase * x[j]) + amp_sin * sin(phase * x[j])
        end
    end
    y .-= mean(y)
    rms = sqrt(mean(abs2, y))
    if rms <= eps(Float64)
        y .= 0.0
    else
        y ./= rms
    end
    return y
end

function sample_fhn_initial_condition(rng::AbstractRNG, spec::FhnPdeSpec)
    nx = spec.nx
    x = collect(range(0.0, spec.L; length = nx + 1))[1:nx]
    ustar, vstar = fhn_equilibrium(spec)
    u0 = fill(ustar, nx)
    v0 = fill(vstar, nx)

    pulse_count = rand(rng, 1:2)
    centers = Float64[]
    while length(centers) < pulse_count
        c = rand(rng) * spec.L
        if all(periodic_distance(c, existing, spec.L) >= spec.L / 4 for existing in centers)
            push!(centers, c)
        end
    end

    for c in centers
        amplitude = 1.8 + 0.6 * rand(rng)
        width = 1.0 + 0.6 * rand(rng)
        @inbounds for j in eachindex(x)
            d = periodic_distance(x[j], c, spec.L)
            u0[j] += amplitude * exp(-(d^2) / (2 * width^2))
        end
    end

    u0 .+= 0.03 .* unit_rms_low_frequency_field(rng, x, spec.L)
    v0 .+= 0.01 .* unit_rms_low_frequency_field(rng, x, spec.L)
    return vcat(u0, v0)
end

function fhn_rhs!(du::AbstractVector, z::AbstractVector, spec::FhnPdeSpec, t)
    nx = spec.nx
    dx2 = (spec.L / nx)^2
    @inbounds for j in 1:nx
        jm = j == 1 ? nx : j - 1
        jp = j == nx ? 1 : j + 1
        u = z[j]
        v = z[nx + j]
        lap_u = (z[jp] - 2u + z[jm]) / dx2
        du[j] = spec.Du * lap_u + u - u^3 / 3 - v
        if spec.Dv == 0.0
            du[nx + j] = spec.epsilon * (u + spec.a - spec.b * v)
        else
            lap_v = (z[nx + jp] - 2v + z[nx + jm]) / dx2
            du[nx + j] = spec.Dv * lap_v + spec.epsilon * (u + spec.a - spec.b * v)
        end
    end
    return nothing
end

function solve_fhn_record(
    spec::FhnPdeSpec,
    z0::Vector{Float64},
    profile::PdeidProfile;
    reltol::Float64 = profile.fhn_reltol,
    abstol::Float64 = profile.fhn_abstol,
)
    t0 = 0.0
    t1 = profile.fhn_warm + profile.M * profile.tau
    save_times = profile.fhn_warm .+ (0:profile.M) .* profile.tau
    prob = ODEProblem(fhn_rhs!, z0, (t0, t1), spec)
    sol = solve(prob, Rodas5P(); reltol = reltol, abstol = abstol, saveat = save_times)
    sol.retcode == ReturnCode.Success || error("FHN solve failed with retcode $(sol.retcode)")
    dz = 2 * spec.nx
    out = Array{Float64}(undef, length(save_times), dz)
    @inbounds for m in eachindex(sol.u)
        out[m, :] .= sol.u[m]
    end
    return out
end

function fhn_activity(z::AbstractVector{<:Real}, nx::Integer)
    u = @view z[1:nx]
    return maximum(u) - minimum(u)
end

function generate_fhn_dataset(spec::FhnPdeSpec, profile::PdeidProfile, rng::AbstractRNG)
    R = total_trajectory_count(profile)
    dz = 2 * spec.nx
    state_rtd = Array{Float64}(undef, R, profile.M + 1, dz)
    attempts = zeros(Int, R)
    activities = zeros(Float64, R)

    for r in 1:R
        accepted = false
        for attempt in 1:profile.max_attempts_per_trajectory
            attempts[r] = attempt
            z0 = sample_fhn_initial_condition(rng, spec)
            trajectory = solve_fhn_record(spec, z0, profile)
            activity = fhn_activity(@view(trajectory[1, :]), spec.nx)
            if all(isfinite, trajectory) && activity >= profile.fhn_activity_threshold
                @inbounds state_rtd[r, :, :] .= trajectory
                activities[r] = activity
                accepted = true
                break
            end
        end
        accepted || error("failed to accept $(spec.object_id) trajectory $r after $(profile.max_attempts_per_trajectory) attempts")
        @printf("[%s] accepted trajectory %d/%d after %d attempt(s), warm activity %.4f\n",
            spec.object_id, r, R, attempts[r], activities[r])
    end

    return state_rtd, Dict(
        "attempts" => attempts,
        "warm_activity_min" => minimum(activities),
        "warm_activity_mean" => mean(activities),
        "warm_activity_max" => maximum(activities),
    )
end

function fft_integer_modes(N::Integer)
    return vcat(0:(N ÷ 2), (-(N ÷ 2 - 1)):-1)
end

function dealias_mask(k::AbstractVector{<:Real})
    kmax = maximum(abs.(k))
    return Float64.(abs.(k) .<= (2 / 3) * kmax)
end

function ks_stepper(spec::KsPdeSpec)
    modes = fft_integer_modes(spec.nx)
    kappa = (2π / spec.L) .* Float64.(modes)
    Ldiag = kappa .^ 2 .- kappa .^ 4
    dt = spec.dt
    E = exp.(dt .* Ldiag)
    E2 = exp.(0.5dt .* Ldiag)
    r = exp.(im * π .* (((1:spec.contour_nodes) .- 0.5) ./ spec.contour_nodes))
    Q = similar(E, ComplexF64)
    f1 = similar(E, ComplexF64)
    f2 = similar(E, ComplexF64)
    f3 = similar(E, ComplexF64)
    for j in eachindex(Ldiag)
        LR = dt * Ldiag[j] .+ r
        Q[j] = dt * real(mean((exp.(LR ./ 2) .- 1) ./ LR))
        f1[j] = dt * real(mean((-4 .- LR .+ exp.(LR) .* (4 .- 3 .* LR .+ LR .^ 2)) ./ (LR .^ 3)))
        f2[j] = dt * real(mean((2 .+ LR .+ exp.(LR) .* (-2 .+ LR)) ./ (LR .^ 3)))
        f3[j] = dt * real(mean((-4 .- 3 .* LR .- LR .^ 2 .+ exp.(LR) .* (4 .- LR)) ./ (LR .^ 3)))
    end
    return KsStepper(kappa, dealias_mask(kappa), ComplexF64.(E), ComplexF64.(E2), Q, f1, f2, f3)
end

function ks_nonlinear(vhat::Vector{ComplexF64}, stepper::KsStepper)
    u = real.(ifft(vhat))
    nlh = -0.5im .* stepper.kappa .* fft(u .^ 2)
    nlh .*= stepper.mask
    nlh[1] = 0.0 + 0.0im
    return ComplexF64.(nlh)
end

function ks_step(vhat::Vector{ComplexF64}, stepper::KsStepper)
    Nv = ks_nonlinear(vhat, stepper)
    a = stepper.E2 .* vhat .+ stepper.Q .* Nv
    Na = ks_nonlinear(a, stepper)
    b = stepper.E2 .* vhat .+ stepper.Q .* Na
    Nb = ks_nonlinear(b, stepper)
    c = stepper.E2 .* a .+ stepper.Q .* (2 .* Nb .- Nv)
    Nc = ks_nonlinear(c, stepper)
    next = stepper.E .* vhat .+ stepper.f1 .* Nv .+ 2 .* stepper.f2 .* (Na .+ Nb) .+ stepper.f3 .* Nc
    u = real.(ifft(next))
    u .-= mean(u)
    next = ComplexF64.(fft(u))
    next .*= stepper.mask
    next[1] = 0.0 + 0.0im
    return next
end

function sample_ks_initial_condition(rng::AbstractRNG, spec::KsPdeSpec)
    vhat = zeros(ComplexF64, spec.nx)
    for n in 1:8
        alpha = (randn(rng) + im * randn(rng)) / sqrt(2)
        coeff = alpha / (1 + (n / 4)^4)
        vhat[n + 1] = coeff * spec.nx
        vhat[spec.nx - n + 1] = conj(coeff) * spec.nx
    end
    u = real.(ifft(vhat))
    u .-= mean(u)
    rho = 0.5 + 0.5 * rand(rng)
    u .*= rho / sqrt(mean(abs2, u))
    return u
end

function solve_ks_record(spec::KsPdeSpec, u0::Vector{Float64}, profile::PdeidProfile; dt::Float64 = spec.dt)
    local_spec = KsPdeSpec(object_id = spec.object_id, nx = spec.nx, L = spec.L, dt = dt, contour_nodes = spec.contour_nodes)
    stepper = ks_stepper(local_spec)
    vhat = ComplexF64.(fft(u0))
    total_steps = Int(round((profile.ks_warm + profile.M * profile.tau) / dt))
    warm_steps = Int(round(profile.ks_warm / dt))
    save_stride = Int(round(profile.tau / dt))
    abs(total_steps * dt - (profile.ks_warm + profile.M * profile.tau)) <= 1.0e-10 ||
        throw(ArgumentError("KS total time must be an integer multiple of dt"))
    abs(save_stride * dt - profile.tau) <= 1.0e-10 ||
        throw(ArgumentError("KS tau must be an integer multiple of dt"))

    out = Array{Float64}(undef, profile.M + 1, spec.nx)
    save_index = 1
    if warm_steps == 0
        out[save_index, :] .= u0
        save_index += 1
    end
    for n in 1:total_steps
        vhat = ks_step(vhat, stepper)
        if n >= warm_steps && (n - warm_steps) % save_stride == 0
            u = real.(ifft(vhat))
            u .-= mean(u)
            out[save_index, :] .= u
            save_index += 1
        end
    end
    save_index == profile.M + 2 || error("KS save count mismatch: got $(save_index - 1)")
    return out
end

function generate_ks_dataset(spec::KsPdeSpec, profile::PdeidProfile, rng::AbstractRNG)
    R = total_trajectory_count(profile)
    state_rtd = Array{Float64}(undef, R, profile.M + 1, spec.nx)
    mean_abs_max = zeros(Float64, R)
    energy_mean = zeros(Float64, R)
    for r in 1:R
        u0 = sample_ks_initial_condition(rng, spec)
        trajectory = solve_ks_record(spec, u0, profile)
        all(isfinite, trajectory) || error("KS trajectory $r contains NaN or Inf")
        @inbounds state_rtd[r, :, :] .= trajectory
        mean_abs_max[r] = maximum(abs.(mean(trajectory; dims = 2)))
        energy_mean[r] = mean(sum(abs2, trajectory; dims = 2) ./ (2 * spec.nx))
        @printf("[%s] accepted trajectory %d/%d, max |mean(u)| %.3e, mean energy %.4e\n",
            spec.object_id, r, R, mean_abs_max[r], energy_mean[r])
    end
    return state_rtd, Dict(
        "mean_abs_max" => maximum(mean_abs_max),
        "energy_mean_min" => minimum(energy_mean),
        "energy_mean_mean" => mean(energy_mean),
        "energy_mean_max" => maximum(energy_mean),
    )
end

function build_time_vector(profile::PdeidProfile)
    return collect((0:profile.M) .* profile.tau)
end

function write_toml_file(path::AbstractString, data::AbstractDict)
    ensure_dir(dirname(path))
    open(path, "w") do io
        TOML.print(io, data)
    end
    return path
end

function base_object_config(profile::PdeidProfile, object_id::AbstractString, nx::Integer, dz::Integer)
    return Dict{String,Any}(
        "task_code" => PDEID_TASK_CODE,
        "object_id" => object_id,
        "profile" => String(profile.name),
        "R_train" => profile.R_train,
        "R_val" => profile.R_val,
        "R_test" => profile.R_test,
        "R_total" => total_trajectory_count(profile),
        "M" => profile.M,
        "tau" => profile.tau,
        "t_record" => profile.M * profile.tau,
        "rollout_horizons" => PDEID_HORIZONS,
        "h_max" => maximum(PDEID_HORIZONS),
        "nx" => nx,
        "state_dim" => dz,
        "target_dim" => dz,
        "observation" => "complete_state_clean",
        "split" => "Split-I trajectory split",
        "master_seed" => profile.seed,
    )
end

function fhn_config_dict(profile::PdeidProfile, spec::FhnPdeSpec)
    data = base_object_config(profile, spec.object_id, spec.nx, 2 * spec.nx)
    data["family"] = "FitzHugh-Nagumo reaction-diffusion"
    data["spatial_domain"] = "[0,32)"
    data["state_layout"] = "[u_0,...,u_{N_x-1},v_0,...,v_{N_x-1}]"
    data["field_names"] = ["u", "v"]
    data["D_u"] = spec.Du
    data["D_v"] = spec.Dv
    data["epsilon"] = spec.epsilon
    data["a"] = spec.a
    data["b"] = spec.b
    data["t_warm"] = profile.fhn_warm
    data["expected_activity_threshold"] = 0.5
    data["used_activity_threshold"] = profile.fhn_activity_threshold
    data["solver"] = "Rodas5P"
    data["reltol"] = profile.fhn_reltol
    data["abstol"] = profile.fhn_abstol
    data["initial_condition_protocol"] = "one or two periodic Gaussian u-pulses plus low-frequency smooth noise around the resting equilibrium"
    return data
end

function ks_config_dict(profile::PdeidProfile, spec::KsPdeSpec)
    data = base_object_config(profile, spec.object_id, spec.nx, spec.nx)
    data["family"] = "Kuramoto-Sivashinsky"
    data["spatial_domain"] = "[0,22)"
    data["state_layout"] = "[u_0,...,u_{N_x-1}]"
    data["field_names"] = ["u"]
    data["t_warm"] = profile.ks_warm
    data["internal_dt"] = spec.dt
    data["integrator"] = "Fourier pseudospectral ETDRK4"
    data["contour_nodes"] = spec.contour_nodes
    data["dealiasing"] = "2/3 mask"
    data["initial_condition_protocol"] = "random Hermitian Fourier modes n=1:8 with RMS scaled uniformly to [0.5,1.0]"
    return data
end

function write_hdf5_string(group, name::AbstractString, value)
    group[name] = string(value)
    return nothing
end

function write_common_hdf5!(
    path::AbstractString,
    state_rtd::Array{Float64,3},
    time::Vector{Float64},
    split::AbstractDict,
    meta::AbstractDict,
    certificate::AbstractDict,
)
    ensure_dir(dirname(path))
    h5open(path, "w") do h5
        h5["state_rtd"] = state_rtd
        h5["time"] = time
        gsplit = create_group(h5, "split")
        gsplit["train_idx"] = Int64.(split["train"])
        gsplit["val_idx"] = Int64.(split["val"])
        gsplit["test_idx"] = Int64.(split["test"])

        gmeta = create_group(h5, "meta")
        for key in [
            "system_name",
            "task_code",
            "state_layout",
            "spatial_domain",
            "numerics",
            "initial_condition_protocol",
        ]
            write_hdf5_string(gmeta, key, meta[key])
        end
        gmeta["field_names"] = JSON.json(meta["field_names"])
        gmeta["nx"] = Int64(meta["nx"])
        gmeta["tau"] = Float64(meta["tau"])
        gmeta["t_warm"] = Float64(meta["t_warm"])
        gmeta["t_record"] = Float64(meta["t_record"])
        gmeta["master_seed"] = Int64(meta["master_seed"])

        gcert = create_group(h5, "certificate")
        for key in ["time_discretization", "spatial_resolution", "invariants"]
            write_hdf5_string(gcert, key, JSON.json(certificate[key]))
        end
    end
    return path
end

function hdf5_meta_from_config(config::AbstractDict)
    return Dict{String,Any}(
        "system_name" => config["object_id"],
        "task_code" => config["task_code"],
        "state_layout" => config["state_layout"],
        "field_names" => config["field_names"],
        "spatial_domain" => config["spatial_domain"],
        "nx" => config["nx"],
        "tau" => config["tau"],
        "t_warm" => config["t_warm"],
        "t_record" => config["t_record"],
        "numerics" => get(config, "solver", get(config, "integrator", "")),
        "initial_condition_protocol" => config["initial_condition_protocol"],
        "master_seed" => config["master_seed"],
    )
end

function relative_squared_error(prod::AbstractVector, ref::AbstractVector)
    return sum(abs2, prod .- ref) / (sum(abs2, ref) + eps(Float64))
end

function propagate_fhn_one_step(spec::FhnPdeSpec, z::Vector{Float64}, tau::Float64, reltol::Float64, abstol::Float64)
    local_profile = PdeidProfile(
        name = :certificate,
        R_train = 1,
        R_val = 0,
        R_test = 0,
        M = 1,
        tau = tau,
        fhn_warm = 0.0,
        ks_warm = 0.0,
        ks_dt = 0.05,
        fhn_reltol = reltol,
        fhn_abstol = abstol,
        fhn_activity_threshold = 0.0,
        seed = 0,
        output_root = "",
        report_root = "",
        max_attempts_per_trajectory = 1,
    )
    return vec(solve_fhn_record(spec, z, local_profile; reltol = reltol, abstol = abstol)[end, :])
end

function propagate_ks_one_step(spec::KsPdeSpec, u::Vector{Float64}, tau::Float64, dt::Float64)
    local_profile = PdeidProfile(
        name = :certificate,
        R_train = 1,
        R_val = 0,
        R_test = 0,
        M = 1,
        tau = tau,
        fhn_warm = 0.0,
        ks_warm = 0.0,
        ks_dt = dt,
        fhn_reltol = 1.0e-8,
        fhn_abstol = 1.0e-10,
        fhn_activity_threshold = 0.0,
        seed = 0,
        output_root = "",
        report_root = "",
        max_attempts_per_trajectory = 1,
    )
    local_spec = KsPdeSpec(object_id = spec.object_id, nx = spec.nx, L = spec.L, dt = dt, contour_nodes = spec.contour_nodes)
    return vec(solve_ks_record(local_spec, u, local_profile; dt = dt)[end, :])
end

function resize_periodic_linear(values::AbstractVector{<:Real}, nout::Integer)
    nin = length(values)
    out = Vector{Float64}(undef, nout)
    scale = nin / nout
    @inbounds for j in 1:nout
        x = (j - 1) * scale
        i0 = floor(Int, x) + 1
        frac = x - floor(x)
        i1 = i0 == nin ? 1 : i0 + 1
        out[j] = (1 - frac) * values[i0] + frac * values[i1]
    end
    return out
end

function resize_fhn_state_linear(z::AbstractVector{<:Real}, nxout::Integer)
    nxin = div(length(z), 2)
    u = resize_periodic_linear(@view(z[1:nxin]), nxout)
    v = resize_periodic_linear(@view(z[(nxin + 1):(2nxin)]), nxout)
    return vcat(u, v)
end

function mode_index(N::Integer, k::Integer)
    return k >= 0 ? k + 1 : N + k + 1
end

function resize_fourier_physical(values::AbstractVector{<:Real}, nout::Integer)
    nin = length(values)
    cin = fft(values) ./ nin
    cout = zeros(ComplexF64, nout)
    kin = fft_integer_modes(nin)
    kmax_out = nout ÷ 2
    for k in kin
        if abs(k) <= kmax_out && !(iseven(nout) && abs(k) == kmax_out)
            cout[mode_index(nout, k)] = cin[mode_index(nin, k)]
        end
    end
    out = real.(ifft(cout .* nout))
    out .-= mean(out)
    return out
end

function fhn_time_certificate(
    spec::FhnPdeSpec,
    state_rtd::Array{Float64,3},
    profile::PdeidProfile,
)
    ncheck = min(8, size(state_rtd, 1))
    accum = 0.0
    for r in 1:ncheck
        z = vec(state_rtd[r, 1, :])
        prod = propagate_fhn_one_step(spec, z, profile.tau, profile.fhn_reltol, profile.fhn_abstol)
        ref = propagate_fhn_one_step(spec, z, profile.tau, 1.0e-10, 1.0e-12)
        accum += relative_squared_error(prod, ref)
    end
    return sqrt(accum / ncheck)
end

function ks_time_certificate(
    spec::KsPdeSpec,
    state_rtd::Array{Float64,3},
    profile::PdeidProfile,
)
    ncheck = min(8, size(state_rtd, 1))
    accum = 0.0
    for r in 1:ncheck
        u = vec(state_rtd[r, 1, :])
        prod = propagate_ks_one_step(spec, u, profile.tau, spec.dt)
        ref = propagate_ks_one_step(spec, u, profile.tau, spec.dt / 2)
        accum += relative_squared_error(prod, ref)
    end
    return sqrt(accum / ncheck)
end

function fhn_space_certificate(
    spec::FhnPdeSpec,
    state_rtd::Array{Float64,3},
    profile::PdeidProfile,
    nxref::Integer,
)
    refspec = FhnPdeSpec(object_id = string(spec.object_id, "_nx", nxref, "_space_ref"), nx = nxref)
    ncheck = min(8, size(state_rtd, 1))
    accum = 0.0
    for r in 1:ncheck
        z = vec(state_rtd[r, 1, :])
        prod = propagate_fhn_one_step(spec, z, profile.tau, profile.fhn_reltol, profile.fhn_abstol)
        zref0 = resize_fhn_state_linear(z, nxref)
        ref_high = propagate_fhn_one_step(refspec, zref0, profile.tau, 1.0e-10, 1.0e-12)
        ref = resize_fhn_state_linear(ref_high, spec.nx)
        accum += relative_squared_error(prod, ref)
    end
    return sqrt(accum / ncheck)
end

function ks_space_certificate(
    spec::KsPdeSpec,
    state_rtd::Array{Float64,3},
    profile::PdeidProfile,
    nxref::Integer,
)
    refspec = KsPdeSpec(object_id = "ks128_space_ref", nx = nxref, L = spec.L, dt = spec.dt / 2, contour_nodes = spec.contour_nodes)
    ncheck = min(8, size(state_rtd, 1))
    accum = 0.0
    for r in 1:ncheck
        u = vec(state_rtd[r, 1, :])
        prod = propagate_ks_one_step(spec, u, profile.tau, spec.dt)
        uref0 = resize_fourier_physical(u, nxref)
        ref_high = propagate_ks_one_step(refspec, uref0, profile.tau, spec.dt / 2)
        ref = resize_fourier_physical(ref_high, spec.nx)
        accum += relative_squared_error(prod, ref)
    end
    return sqrt(accum / ncheck)
end

function fhn_cross_resolution_certificate(
    fhn32::Array{Float64,3},
    profile::PdeidProfile,
)
    spec32 = FhnPdeSpec(object_id = "fhn32", nx = 32)
    spec64 = FhnPdeSpec(object_id = "fhn64_cross_ref", nx = 64)
    ncheck = min(8, size(fhn32, 1))
    accum = 0.0
    for r in 1:ncheck
        z = vec(fhn32[r, 1, :])
        prod = propagate_fhn_one_step(spec32, z, profile.tau, profile.fhn_reltol, profile.fhn_abstol)
        z64 = resize_fhn_state_linear(z, 64)
        ref64 = propagate_fhn_one_step(spec64, z64, profile.tau, profile.fhn_reltol, profile.fhn_abstol)
        ref = resize_fhn_state_linear(ref64, 32)
        accum += relative_squared_error(prod, ref)
    end
    return sqrt(accum / ncheck)
end

function object_summary(
    object_id::AbstractString,
    state_rtd::Array{Float64,3},
    split::AbstractDict,
)
    return Dict{String,Any}(
        "object_id" => object_id,
        "shape" => collect(size(state_rtd)),
        "finite" => all(isfinite, state_rtd),
        "state_min" => minimum(state_rtd),
        "state_max" => maximum(state_rtd),
        "split_counts" => Dict(k => length(v) for (k, v) in split),
    )
end

function fhn_invariants(state_rtd::Array{Float64,3}, nx::Integer)
    activities = [fhn_activity(vec(state_rtd[r, m, :]), nx) for r in axes(state_rtd, 1), m in axes(state_rtd, 2)]
    return Dict(
        "activity_min" => minimum(activities),
        "activity_mean" => mean(activities),
        "activity_max" => maximum(activities),
        "u_min" => minimum(@view state_rtd[:, :, 1:nx]),
        "u_max" => maximum(@view state_rtd[:, :, 1:nx]),
        "state_l2_max" => maximum(sqrt.(sum(abs2, state_rtd; dims = 3))),
    )
end

function ks_invariants(state_rtd::Array{Float64,3})
    means = mean(state_rtd; dims = 3)
    energy = sum(abs2, state_rtd; dims = 3) ./ (2 * size(state_rtd, 3))
    return Dict(
        "mean_abs_max" => maximum(abs.(means)),
        "energy_min" => minimum(energy),
        "energy_mean" => mean(energy),
        "energy_max" => maximum(energy),
    )
end

function save_report_tables(report_root::AbstractString, summaries::AbstractDict, certificate::AbstractDict)
    table_dir = ensure_dir(joinpath(report_root, "tables"))
    split_path = joinpath(table_dir, "split_state_summary.csv")
    open(split_path, "w") do io
        println(io, "object_id,split,count,M,state_dim,state_min,state_max")
        for object_id in sort(collect(keys(summaries)))
            summary = summaries[object_id]
            for split_name in ["train", "val", "test"]
                println(io, join([
                    object_id,
                    split_name,
                    summary["split_counts"][split_name],
                    summary["shape"][2] - 1,
                    summary["shape"][3],
                    summary["state_min"],
                    summary["state_max"],
                ], ","))
            end
        end
    end

    cert_path = joinpath(table_dir, "numeric_certificate_summary.csv")
    open(cert_path, "w") do io
        println(io, "object_id,epsilon_time_one_step,epsilon_space_one_step,passed_time_threshold")
        for object_id in ["fhn32", "fhn64", "ks64"]
            time_err = certificate["objects"][object_id]["time_discretization"]["epsilon_time_one_step"]
            space_err = get(certificate["objects"][object_id]["spatial_resolution"], "epsilon_space_one_step", "")
            passed = time_err <= 1.0e-4
            println(io, join([object_id, time_err, space_err, passed], ","))
        end
    end
    return Dict("split_state_summary" => split_path, "numeric_certificate_summary" => cert_path)
end

function maybe_save_plots(report_root::AbstractString, datasets::AbstractDict, certificate::AbstractDict)
    plot_dir = ensure_dir(joinpath(report_root, "plots"))
    plot_files = String[]
    try
        for object_id in ["fhn32", "fhn64"]
            state = datasets[object_id]["state_rtd"]
            nx = datasets[object_id]["config"]["nx"]
            u = permutedims(state[1, :, 1:nx])
            v = permutedims(state[1, :, (nx + 1):(2nx)])
            pu = Plots.heatmap(u; xlabel = "time index", ylabel = "x index", title = string(object_id, " u field"))
            path_u = joinpath(plot_dir, string(object_id, "_u_heatmap.png"))
            Plots.savefig(pu, path_u)
            push!(plot_files, path_u)
            pv = Plots.heatmap(v; xlabel = "time index", ylabel = "x index", title = string(object_id, " v field"))
            path_v = joinpath(plot_dir, string(object_id, "_v_heatmap.png"))
            Plots.savefig(pv, path_v)
            push!(plot_files, path_v)
        end

        ks_state = datasets["ks64"]["state_rtd"]
        pks = Plots.heatmap(permutedims(ks_state[1, :, :]); xlabel = "time index", ylabel = "x index", title = "ks64 u field")
        ks_path = joinpath(plot_dir, "ks64_u_heatmap.png")
        Plots.savefig(pks, ks_path)
        push!(plot_files, ks_path)

        spectrum = mean([abs2.(fft(vec(ks_state[r, m, :]))) ./ size(ks_state, 3)^2 for r in axes(ks_state, 1), m in axes(ks_state, 2)])
        ps = Plots.plot(0:(length(spectrum) - 1), spectrum; yscale = :log10, xlabel = "FFT index", ylabel = "mean energy", title = "ks64 time-averaged Fourier spectrum", label = false)
        spectrum_path = joinpath(plot_dir, "ks64_fourier_energy_spectrum.png")
        Plots.savefig(ps, spectrum_path)
        push!(plot_files, spectrum_path)

        eps_time = [certificate["objects"][id]["time_discretization"]["epsilon_time_one_step"] for id in ["fhn32", "fhn64", "ks64"]]
        pe = Plots.bar(["fhn32", "fhn64", "ks64"], eps_time; yscale = :log10, ylabel = "epsilon_time", title = "one-step time discretization error", label = false)
        eps_path = joinpath(plot_dir, "epsilon_time_one_step.png")
        Plots.savefig(pe, eps_path)
        push!(plot_files, eps_path)

        eps_space = [
            get(certificate["objects"]["fhn64"]["spatial_resolution"], "epsilon_space_one_step", NaN),
            get(certificate["objects"]["ks64"]["spatial_resolution"], "epsilon_space_one_step", NaN),
        ]
        psr = Plots.bar(["fhn64", "ks64"], eps_space; yscale = :log10, ylabel = "epsilon_space", title = "space resolution certificate", label = false)
        space_path = joinpath(plot_dir, "epsilon_space_one_step.png")
        Plots.savefig(psr, space_path)
        push!(plot_files, space_path)
    catch err
        @warn "Skipping PDEID plots because plot generation failed" exception = err
    end
    return plot_files
end

function copy_environment_files(project_root::AbstractString, output_root::AbstractString)
    for file in ["Project.toml", "Manifest.toml"]
        src = joinpath(project_root, file)
        dst = joinpath(output_root, file)
        isfile(src) && cp(src, dst; force = true)
    end
end

function run_pdeid_fhn32_fhn64_ks64_generation(project_root::AbstractString; profile_name::Symbol = :formal)
    profile = pdeid_profile(project_root, profile_name)
    ensure_dir(profile.output_root)
    ensure_dir(profile.report_root)

    rng = MersenneTwister(profile.seed)
    split = split_indices(profile)
    time = build_time_vector(profile)

    fhn32_spec = FhnPdeSpec(object_id = "fhn32", nx = 32)
    fhn64_spec = FhnPdeSpec(object_id = "fhn64", nx = 64)
    ks64_spec = KsPdeSpec(dt = profile.ks_dt)

    fhn32, fhn32_generation = generate_fhn_dataset(fhn32_spec, profile, rng)
    fhn64, fhn64_generation = generate_fhn_dataset(fhn64_spec, profile, rng)
    ks64, ks64_generation = generate_ks_dataset(ks64_spec, profile, rng)

    configs = Dict(
        "fhn32" => fhn_config_dict(profile, fhn32_spec),
        "fhn64" => fhn_config_dict(profile, fhn64_spec),
        "ks64" => ks_config_dict(profile, ks64_spec),
    )
    for object_id in keys(configs)
        write_toml_file(joinpath(profile.output_root, string(object_id, ".toml")), configs[object_id])
    end

    certificate = Dict{String,Any}(
        "task_code" => PDEID_TASK_CODE,
        "profile" => String(profile.name),
        "created_at" => string(now()),
        "thresholds" => Dict("epsilon_time_one_step_max" => 1.0e-4, "ks_mean_abs_max" => 1.0e-12),
        "adjustments" => profile.name == :formal ? [
            Dict(
                "object_family" => "FHN32/FHN64",
                "original_expectation" => "Accept only trajectories with A_FHN(T_warm) >= 0.5 after T_warm=32.",
                "observed_mismatch" => "A pre-formal probe found warm-end activity below 0.5 across sampled initial conditions, with observed values concentrated below about 0.39.",
                "adjustment" => "Use A_FHN(T_warm) >= 0.35 for formal acceptance while keeping the PDE parameters, initial-condition distribution, warm-up duration, solver, tolerance, tau, and record length unchanged.",
                "rationale" => "This preserves the strongest nontrivial post-warm spatial activity available from the specified autonomous no-drive FHN setting instead of silently producing no FHN dataset.",
            ),
        ] : Any[],
        "objects" => Dict{String,Any}(),
    )

    certificate["objects"]["fhn32"] = Dict(
        "time_discretization" => Dict("epsilon_time_one_step" => fhn_time_certificate(fhn32_spec, fhn32, profile)),
        "spatial_resolution" => Dict("epsilon_fhn32_from_fhn64_one_step" => fhn_cross_resolution_certificate(fhn32, profile)),
        "invariants" => merge(fhn_invariants(fhn32, 32), fhn32_generation),
    )
    certificate["objects"]["fhn64"] = Dict(
        "time_discretization" => Dict("epsilon_time_one_step" => fhn_time_certificate(fhn64_spec, fhn64, profile)),
        "spatial_resolution" => Dict("epsilon_space_one_step" => fhn_space_certificate(fhn64_spec, fhn64, profile, 128)),
        "invariants" => merge(fhn_invariants(fhn64, 64), fhn64_generation),
    )
    certificate["objects"]["ks64"] = Dict(
        "time_discretization" => Dict("epsilon_time_one_step" => ks_time_certificate(ks64_spec, ks64, profile)),
        "spatial_resolution" => Dict("epsilon_space_one_step" => ks_space_certificate(ks64_spec, ks64, profile, 128)),
        "invariants" => merge(ks_invariants(ks64), ks64_generation),
    )

    datasets = Dict(
        "fhn32" => Dict("state_rtd" => fhn32, "config" => configs["fhn32"]),
        "fhn64" => Dict("state_rtd" => fhn64, "config" => configs["fhn64"]),
        "ks64" => Dict("state_rtd" => ks64, "config" => configs["ks64"]),
    )
    for object_id in ["fhn32", "fhn64", "ks64"]
        object_cert = certificate["objects"][object_id]
        write_common_hdf5!(
            joinpath(profile.output_root, string(object_id, ".h5")),
            datasets[object_id]["state_rtd"],
            time,
            split,
            hdf5_meta_from_config(configs[object_id]),
            object_cert,
        )
    end

    certificate_path = joinpath(profile.output_root, "numeric_certificate.json")
    open(certificate_path, "w") do io
        JSON.print(io, certificate, 4)
    end
    copy_environment_files(project_root, profile.output_root)

    summaries = Dict(
        "fhn32" => object_summary("fhn32", fhn32, split),
        "fhn64" => object_summary("fhn64", fhn64, split),
        "ks64" => object_summary("ks64", ks64, split),
    )
    table_files = save_report_tables(profile.report_root, summaries, certificate)
    plot_files = maybe_save_plots(profile.report_root, datasets, certificate)

    passed = all(certificate["objects"][id]["time_discretization"]["epsilon_time_one_step"] <= 1.0e-4 for id in ["fhn32", "fhn64", "ks64"]) &&
        certificate["objects"]["ks64"]["invariants"]["mean_abs_max"] <= 1.0e-12 &&
        all(summary["finite"] for summary in values(summaries))

    run_summary = Dict(
        "task_code" => PDEID_TASK_CODE,
        "profile" => String(profile.name),
        "passed" => passed,
        "output_root" => profile.output_root,
        "report_root" => profile.report_root,
        "certificate_path" => certificate_path,
        "table_files" => table_files,
        "plot_files" => plot_files,
        "summaries" => summaries,
        "certificate" => certificate,
    )

    summary_path = joinpath(profile.report_root, "logs", string("run_summary_", profile.name, ".json"))
    ensure_dir(dirname(summary_path))
    open(summary_path, "w") do io
        JSON.print(io, run_summary, 4)
    end
    run_summary["summary_path"] = summary_path
    return run_summary
end

function print_pdeid_summary(summary::AbstractDict)
    @printf("task_code: %s\n", summary["task_code"])
    @printf("profile: %s\n", summary["profile"])
    @printf("passed: %s\n", string(summary["passed"]))
    @printf("output_root: %s\n", summary["output_root"])
    @printf("report_root: %s\n", summary["report_root"])
    for object_id in ["fhn32", "fhn64", "ks64"]
        obj = summary["summaries"][object_id]
        cert = summary["certificate"]["objects"][object_id]
        @printf("%s shape: %s\n", object_id, string(obj["shape"]))
        @printf("%s state range: [%.6g, %.6g]\n", object_id, obj["state_min"], obj["state_max"])
        @printf("%s epsilon_time_one_step: %.6e\n", object_id, cert["time_discretization"]["epsilon_time_one_step"])
        @printf("%s spatial certificate: %s\n", object_id, JSON.json(cert["spatial_resolution"]))
    end
    @printf("numeric_certificate: %s\n", summary["certificate_path"])
    @printf("summary_path: %s\n", summary["summary_path"])
end
