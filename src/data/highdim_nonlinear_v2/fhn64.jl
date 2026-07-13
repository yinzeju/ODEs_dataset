Base.@kwdef struct HDNDFHNSpec
    nx::Int = 64
    domain_length::Float64 = 32.0
    diffusion_u::Float64 = 1.0
    diffusion_v::Float64 = 0.0
    epsilon::Float64 = 0.08
    a::Float64 = 0.7
    b::Float64 = 0.8
    tau::Float64 = 0.05
    reltol::Float64 = 1.0e-10
    abstol::Float64 = 1.0e-12
    dtmax::Float64 = 0.02
    reference_reltol::Float64 = 1.0e-12
    reference_abstol::Float64 = 1.0e-14
    reference_nx::Int = 128
end

function hdnd_fhn_equilibrium(spec::HDNDFHNSpec)
    u = -1.2
    for _ in 1:50
        residual = u - u^3 / 3 - (u + spec.a) / spec.b
        derivative = 1 - u^2 - inv(spec.b)
        u -= residual / derivative
    end
    return u, (u + spec.a) / spec.b
end

hdnd_periodic_distance(x::Real, center::Real, length::Real) = min(abs(x - center), length - abs(x - center))

function hdnd_unit_rms_low_frequency_field(rng::AbstractRNG, grid::AbstractVector, domain_length::Real)
    field = zeros(Float64, length(grid))
    for mode in 1:3
        cosine = randn(rng); sine = randn(rng)
        frequency = 2π * mode / domain_length
        @. field += cosine * cos(frequency * grid) + sine * sin(frequency * grid)
    end
    field .-= mean(field)
    field ./= sqrt(mean(abs2, field))
    return field
end

function hdnd_fhn_regime_labels(profile::HDNDProfile, split_name::AbstractString)
    if profile.name === :formal
        counts = split_name == "train" ? (160, 64, 64, 32) : (40, 16, 16, 8)
        return vcat(
            fill("active", counts[1]),
            fill("formation", counts[2]),
            fill("collision", counts[3]),
            fill("recovery", counts[4]),
        )
    end
    return ["active", "formation", "collision", "recovery"]
end

function hdnd_fhn_warmup(regime::AbstractString)
    regime == "active" && return 32.0
    regime == "collision" && return 4.0
    return 0.0
end

function sample_hdnd_fhn_initial_condition(rng::AbstractRNG, spec::HDNDFHNSpec, regime::AbstractString)
    nx = spec.nx
    grid = collect((0:(nx - 1)) .* (spec.domain_length / nx))
    ustar, vstar = hdnd_fhn_equilibrium(spec)
    u = fill(ustar, nx)
    v = fill(vstar, nx)
    pulse_count = if regime == "active" || regime == "formation"
        rand(rng, 1:2)
    elseif regime == "collision"
        rand(rng, 2:4)
    elseif regime == "recovery"
        rand(rng, 0:2)
    else
        throw(ArgumentError("unknown FHN regime: $regime"))
    end
    centers = Float64[]
    minimum_separation = regime == "collision" ? spec.domain_length / (2 * max(pulse_count, 1) + 2) : 0.0
    attempts = 0
    while length(centers) < pulse_count
        attempts += 1
        attempts > 1_000 && error("could not sample separated FHN pulse centers")
        center = rand(rng) * spec.domain_length
        all(hdnd_periodic_distance(center, existing, spec.domain_length) >= minimum_separation for existing in centers) && push!(centers, center)
    end
    amplitude_range = regime == "recovery" ? (0.2, 1.5) : (1.6, 2.6)
    for center in centers
        amplitude = amplitude_range[1] + (amplitude_range[2] - amplitude_range[1]) * rand(rng)
        width = 0.8 + rand(rng)
        @inbounds for j in eachindex(grid)
            distance = hdnd_periodic_distance(grid[j], center, spec.domain_length)
            u[j] += amplitude * exp(-distance^2 / (2 * width^2))
        end
    end
    u .+= 0.03 .* hdnd_unit_rms_low_frequency_field(rng, grid, spec.domain_length)
    v .+= 0.01 .* hdnd_unit_rms_low_frequency_field(rng, grid, spec.domain_length)
    return vcat(u, v)
end

function hdnd_fhn_rhs!(dz::AbstractVector, z::AbstractVector, spec::HDNDFHNSpec, _t)
    nx = spec.nx
    dx2 = (spec.domain_length / nx)^2
    denominator = 12dx2
    @inbounds for j in 1:nx
        jm2 = mod1(j - 2, nx); jm1 = mod1(j - 1, nx)
        jp1 = mod1(j + 1, nx); jp2 = mod1(j + 2, nx)
        u = z[j]; v = z[nx + j]
        lap_u = (-z[jp2] + 16z[jp1] - 30u + 16z[jm1] - z[jm2]) / denominator
        dz[j] = spec.diffusion_u * lap_u + u - u^3 / 3 - v
        if spec.diffusion_v == 0.0
            dz[nx + j] = spec.epsilon * (u + spec.a - spec.b * v)
        else
            lap_v = (-z[nx + jp2] + 16z[nx + jp1] - 30v + 16z[nx + jm1] - z[nx + jm2]) / denominator
            dz[nx + j] = spec.diffusion_v * lap_v + spec.epsilon * (u + spec.a - spec.b * v)
        end
    end
    return nothing
end

function solve_hdnd_fhn_trajectory(
    initial::Vector{Float64},
    spec::HDNDFHNSpec,
    warm::Real,
    steps::Integer;
    reference::Bool = false,
)
    save_times = warm .+ (0:steps) .* spec.tau
    prob = ODEProblem(hdnd_fhn_rhs!, initial, (0.0, warm + steps * spec.tau), spec)
    solution = if reference
        solve(
            prob,
            Rodas5P();
            reltol = spec.reference_reltol,
            abstol = spec.reference_abstol,
            dtmax = spec.dtmax / 2,
            saveat = save_times,
            save_everystep = false,
        )
    else
        solve(
            prob,
            Rodas5P();
            reltol = spec.reltol,
            abstol = spec.abstol,
            dtmax = spec.dtmax,
            saveat = save_times,
            save_everystep = false,
        )
    end
    solution.retcode == ReturnCode.Success || error("FHN integration failed: $(solution.retcode)")
    trajectory = Matrix{Float64}(undef, steps + 1, 2spec.nx)
    for i in eachindex(solution.u)
        trajectory[i, :] .= solution.u[i]
    end
    return trajectory
end

function hdnd_periodic_linear_resize(values::AbstractVector{<:Real}, output_nx::Integer)
    input_nx = length(values)
    output = Vector{Float64}(undef, output_nx)
    scale = input_nx / output_nx
    for j in 1:output_nx
        position = (j - 1) * scale
        left = floor(Int, position) + 1
        right = left == input_nx ? 1 : left + 1
        fraction = position - floor(position)
        output[j] = (1 - fraction) * values[left] + fraction * values[right]
    end
    return output
end

function hdnd_fhn_resize_state(state::AbstractVector{<:Real}, output_nx::Integer)
    input_nx = length(state) ÷ 2
    return vcat(
        hdnd_periodic_linear_resize(@view(state[1:input_nx]), output_nx),
        hdnd_periodic_linear_resize(@view(state[(input_nx + 1):(2input_nx)]), output_nx),
    )
end

function hdnd_fhn_block_error(production, reference, equilibrium)
    numerator = sum(abs2, production .- reference)
    denominator = sum(abs2, reference .- equilibrium)
    return numerator, denominator
end

function hdnd_fhn_time_space_errors(states::AbstractVector{<:AbstractVector}, spec::HDNDFHNSpec)
    ustar, vstar = hdnd_fhn_equilibrium(spec)
    time_num_u = 0.0; time_den_u = 0.0; time_num_v = 0.0; time_den_v = 0.0
    space_num_u = 0.0; space_den_u = 0.0; space_num_v = 0.0; space_den_v = 0.0
    high_spec = HDNDFHNSpec(nx = spec.reference_nx)
    for state in states
        initial = collect(Float64, state)
        production = vec(solve_hdnd_fhn_trajectory(initial, spec, 0.0, 1)[end, :])
        time_reference = vec(solve_hdnd_fhn_trajectory(initial, spec, 0.0, 1; reference = true)[end, :])
        high_initial = hdnd_fhn_resize_state(initial, spec.reference_nx)
        high_reference = vec(solve_hdnd_fhn_trajectory(high_initial, high_spec, 0.0, 1; reference = true)[end, :])
        space_reference = hdnd_fhn_resize_state(high_reference, spec.nx)
        n, d = hdnd_fhn_block_error(@view(production[1:spec.nx]), @view(time_reference[1:spec.nx]), ustar)
        time_num_u += n; time_den_u += d
        n, d = hdnd_fhn_block_error(@view(production[(spec.nx + 1):end]), @view(time_reference[(spec.nx + 1):end]), vstar)
        time_num_v += n; time_den_v += d
        n, d = hdnd_fhn_block_error(@view(production[1:spec.nx]), @view(space_reference[1:spec.nx]), ustar)
        space_num_u += n; space_den_u += d
        n, d = hdnd_fhn_block_error(@view(production[(spec.nx + 1):end]), @view(space_reference[(spec.nx + 1):end]), vstar)
        space_num_v += n; space_den_v += d
    end
    time_u = sqrt(time_num_u / (time_den_u + eps(Float64))); time_v = sqrt(time_num_v / (time_den_v + eps(Float64)))
    space_u = sqrt(space_num_u / (space_den_u + eps(Float64))); space_v = sqrt(space_num_v / (space_den_v + eps(Float64)))
    return Dict(
        "time_one_step_error_u" => time_u,
        "time_one_step_error_v" => time_v,
        "time_one_step_error" => sqrt((time_u^2 + time_v^2) / 2),
        "space_one_step_error_u" => space_u,
        "space_one_step_error_v" => space_v,
        "space_one_step_error" => sqrt((space_u^2 + space_v^2) / 2),
        "sample_count" => length(states),
        "time_threshold" => 1.0e-6,
    )
end

function hdnd_fhn_activity(trajectory::AbstractMatrix, nx::Integer)
    return vec(maximum(@view(trajectory[:, 1:nx]); dims = 2) .- minimum(@view(trajectory[:, 1:nx]); dims = 2))
end

function hdnd_fhn_spectrum(trajectory::AbstractMatrix, field_range; stride::Integer = 10)
    spectrum = zeros(Float64, length(field_range)); count = 0
    for m in 1:stride:size(trajectory, 1)
        spectrum .+= abs2.(fft(@view trajectory[m, field_range])) ./ length(field_range)^2
        count += 1
    end
    return spectrum ./ count
end

function hdnd_circular_peak_indices(values::AbstractVector, threshold::Real)
    peaks = Int[]
    for j in eachindex(values)
        left = values[mod1(j - 1, length(values))]
        right = values[mod1(j + 1, length(values))]
        values[j] >= threshold && values[j] > left && values[j] >= right && push!(peaks, j)
    end
    return peaks
end

function hdnd_fhn_pulse_statistics(trajectory::AbstractMatrix, spec::HDNDFHNSpec)
    ustar, _ = hdnd_fhn_equilibrium(spec)
    dx = spec.domain_length / spec.nx
    pulse_counts = Float64[]; widths = Float64[]; dominant_positions = Float64[]
    for m in axes(trajectory, 1)
        u = @view trajectory[m, 1:spec.nx]
        peaks = hdnd_circular_peak_indices(u, ustar + 0.5)
        push!(pulse_counts, length(peaks))
        if !isempty(peaks)
            dominant = peaks[argmax(u[peaks])]
            push!(dominant_positions, (dominant - 1) * dx)
            for peak in peaks
                half_level = ustar + (u[peak] - ustar) / 2
                width_cells = 1
                while width_cells < spec.nx && u[mod1(peak - width_cells, spec.nx)] >= half_level
                    width_cells += 1
                end
                right_cells = 1
                while width_cells + right_cells < spec.nx && u[mod1(peak + right_cells, spec.nx)] >= half_level
                    right_cells += 1
                end
                push!(widths, (width_cells + right_cells - 1) * dx)
            end
        else
            push!(dominant_positions, NaN)
        end
    end
    speeds = Float64[]
    for m in 2:length(dominant_positions)
        if isfinite(dominant_positions[m - 1]) && isfinite(dominant_positions[m])
            displacement = dominant_positions[m] - dominant_positions[m - 1]
            displacement -= round(displacement / spec.domain_length) * spec.domain_length
            push!(speeds, displacement / spec.tau)
        end
    end
    return Dict(
        "pulse_count_statistics" => scalar_summary(pulse_counts),
        "wave_speed_statistics" => isempty(speeds) ? Dict("count" => 0) : merge(scalar_summary(speeds), Dict("count" => length(speeds))),
        "pulse_width_statistics" => isempty(widths) ? Dict("count" => 0) : merge(scalar_summary(widths), Dict("count" => length(widths))),
    )
end

function hdnd_fhn_uv_phase_lag(trajectory::AbstractMatrix, spec::HDNDFHNSpec)
    u = vec(mean(@view(trajectory[:, 1:spec.nx]); dims = 2))
    v = vec(mean(@view(trajectory[:, (spec.nx + 1):(2spec.nx)]); dims = 2))
    u .-= mean(u); v .-= mean(v)
    max_lag = min(200, length(u) - 1)
    correlations = [dot(@view(u[1:(end - lag)]), @view(v[(lag + 1):end])) for lag in 0:max_lag]
    lag = argmax(correlations) - 1
    return Dict("lag_steps" => lag, "lag_time" => lag * spec.tau)
end
