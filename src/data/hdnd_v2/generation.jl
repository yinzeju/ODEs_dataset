function hdnd_split_trajectory_ids(profile::HDNDProfile)
    ids = Dict{String,Vector{Int}}()
    start = 1
    for split_name in HDND_SPLIT_NAMES
        count = split_count(profile, split_name)
        ids[split_name] = collect(start:(start + count - 1))
        start += count
    end
    return ids
end

function hdnd_check_state!(states, trajectory, profile)
    length(states) >= profile.check_count && return states
    index = 1 + mod(97 * length(states), size(trajectory, 1))
    push!(states, collect(Float64, @view trajectory[index, :]))
    return states
end

function mean_acf(series_set::AbstractVector{<:AbstractVector}, max_lag::Integer)
    minimum_length = minimum(length, series_set)
    limit = min(max_lag, minimum_length - 1)
    result = zeros(Float64, limit + 1)
    for series in series_set
        result .+= normalized_autocorrelation(series, limit)
    end
    return result ./ length(series_set)
end

function hdnd_l96_shift_error(state::AbstractVector, spec::HDNDL96Spec; shift::Integer = 7)
    shifted = circshift(state, shift)
    propagated_shift = propagate_hdnd_l96_one_step(collect(shifted), spec)
    shifted_propagation = circshift(propagate_hdnd_l96_one_step(collect(state), spec), shift)
    return norm(propagated_shift .- shifted_propagation) / (norm(shifted_propagation) + eps(Float64))
end

function hdnd_ks_shift_error(state::AbstractVector, spec::HDNDKSSpec; shift::Integer = 7)
    shifted = circshift(state, shift)
    propagated_shift = vec(solve_hdnd_ks_trajectory(collect(shifted), spec, 0.0, 1)[end, :])
    propagated = vec(solve_hdnd_ks_trajectory(collect(state), spec, 0.0, 1)[end, :])
    return norm(propagated_shift .- circshift(propagated, shift)) / (norm(propagated) + eps(Float64))
end

function hdnd_fhn_shift_state(state::AbstractVector, nx::Integer, shift::Integer)
    return vcat(circshift(@view(state[1:nx]), shift), circshift(@view(state[(nx + 1):(2nx)]), shift))
end

function hdnd_fhn_shift_error(state::AbstractVector, spec::HDNDFHNSpec; shift::Integer = 7)
    shifted = hdnd_fhn_shift_state(state, spec.nx, shift)
    propagated_shift = vec(solve_hdnd_fhn_trajectory(shifted, spec, 0.0, 1)[end, :])
    propagated = vec(solve_hdnd_fhn_trajectory(collect(state), spec, 0.0, 1)[end, :])
    shifted_propagation = hdnd_fhn_shift_state(propagated, spec.nx, shift)
    return norm(propagated_shift .- shifted_propagation) / (norm(shifted_propagation) + eps(Float64))
end

function generate_hdnd_l96(project_root::AbstractString, profile::HDNDProfile)
    spec = HDNDL96Spec()
    path = joinpath(profile.output_root, "l96_nx40_raw_v2.h5")
    rm(path; force = true)
    mkpath(dirname(path))
    samples = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    energies = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    variances = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    means = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    coordinate1 = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    check_states = Vector{Vector{Float64}}()
    representative = Dict{String,Matrix{Float64}}()
    initial_states = Matrix{Float64}(undef, total_trajectory_count(profile), spec.nx)
    seeds = Vector{Int}(undef, total_trajectory_count(profile))
    ids = hdnd_split_trajectory_ids(profile)
    metadata = Dict(
        "system_name" => "L96-40",
        "spatial_dimension" => 40,
        "physical_parameters" => Dict("N_x" => 40, "F_0" => 8.0),
        "solver_name" => "Vern9",
        "solver_order" => 9,
        "reltol" => spec.reltol,
        "abstol" => spec.abstol,
        "max_internal_step" => spec.dtmax,
        "spatial_discretization" => "cyclic_local_coupling",
    )
    h5open(path, "w") do h5
        writers = initialize_system_file!(h5, project_root, profile, metadata, spec.nx, profile.l96_steps, spec.tau)
        for split_name in HDND_SPLIT_NAMES
            labels = fill("attractor", split_count(profile, split_name))
            split_ids = ids[split_name]
            trajectories = Vector{Matrix{Float64}}(undef, length(split_ids))
            Threads.@threads for local_index in eachindex(split_ids)
                trajectory_id = split_ids[local_index]
                seed = trajectory_seed(profile, 1, trajectory_id)
                initial = sample_hdnd_l96_initial_condition(MersenneTwister(seed), spec)
                trajectory = solve_hdnd_l96_trajectory(initial, spec, profile.l96_burn, profile.l96_steps)
                all(isfinite, trajectory) || error("L96 trajectory $trajectory_id is not finite")
                trajectories[local_index] = trajectory
            end
            for (local_index, trajectory_id) in enumerate(split_ids)
                seed = trajectory_seed(profile, 1, trajectory_id)
                trajectory = trajectories[local_index]
                write_trajectory!(writers[split_name], local_index, trajectory, trajectory_id, seed, profile.l96_burn)
                initial_states[trajectory_id, :] .= @view trajectory[1, :]
                seeds[trajectory_id] = seed
                energy = hdnd_l96_energy(trajectory)
                variance = hdnd_l96_spatial_variance(trajectory)
                push!(energies[split_name], energy)
                push!(variances[split_name], variance)
                push!(means[split_name], vec(mean(trajectory; dims = 2)))
                push!(coordinate1[split_name], collect(@view trajectory[:, 1]))
                append_sample_states!(samples[split_name], trajectory, profile.sample_states_per_split)
                hdnd_check_state!(check_states, trajectory, profile)
                get!(representative, split_name, copy(trajectory))
                if local_index % 10 == 0 || local_index == length(split_ids)
                    @printf("[HDND L96] %s trajectory %d/%d written\n", split_name, local_index, length(split_ids))
                end
            end
            empty!(trajectories)
            GC.gc()
            write_regime_labels!(writers[split_name], labels)
        end
        time_convergence = hdnd_l96_time_error(check_states, spec)
        all_energy = reduce(vcat, reduce(vcat, values(energies)))
        all_variance = reduce(vcat, reduce(vcat, values(variances)))
        acf = Dict{String,Any}()
        for observable in ("energy", "spatial_mean", "x1")
            source = observable == "energy" ? energies : observable == "spatial_mean" ? means : coordinate1
            train_series = source["train"][1:min(end, 16)]
            curve = mean_acf(train_series, min(512, profile.l96_steps))
            tau_int = integrated_autocorrelation_time(curve, spec.tau)
            acf[observable] = Dict(
                "values" => curve,
                "integrated_time" => tau_int,
                "effective_sample_size" => sum(length, source["train"]) * spec.tau / (2tau_int + eps(Float64)),
            )
        end
        first_trajectory = representative["train"]
        psd = abs2.(fft(first_trajectory[:, 1] .- mean(first_trajectory[:, 1]))) ./ size(first_trajectory, 1)^2
        lyapunov = hdnd_l96_lyapunov(@view(first_trajectory[1, :]), spec, profile.l96_lyapunov_time)
        split_distribution = pca_distribution_metrics(samples)
        duplicate = duplicate_check(initial_states, seeds)
        stationarity = Dict(
            split_name => Dict(
                "energy" => stationarity_summary(energies[split_name]),
                "spatial_variance" => stationarity_summary(variances[split_name]),
            ) for split_name in HDND_SPLIT_NAMES
        )
        physical = Dict(
            "energy" => scalar_summary(all_energy),
            "spatial_variance" => scalar_summary(all_variance),
            "state" => scalar_summary(initial_states),
            "periodic_boundary_check" => hdnd_l96_boundary_check(spec),
            "shift_equivariance_error" => hdnd_l96_shift_error(check_states[1], spec),
            "duplicate_check" => duplicate,
            "power_spectral_density_x1" => psd,
        )
        diagnostics = Dict(
            "time_convergence" => time_convergence,
            "space_convergence" => Dict("not_applicable" => true),
            "physical_statistics" => physical,
            "autocorrelation" => acf,
            "energy_spectrum" => Dict("temporal_power_spectral_density_x1" => psd),
            "lyapunov_spectrum" => lyapunov,
            "split_distribution" => split_distribution,
            "stationarity" => stationarity,
        )
        write_diagnostics!(h5, diagnostics)
    end
    checks = finite_time_shape_checks(path, profile, profile.l96_steps + 1, spec.nx)
    diagnostics = h5open(path, "r") do h5
        Dict(key => JSON.parse(read(h5[string("diagnostics/", key)], String)) for key in keys(h5["diagnostics"]))
    end
    passed = all(value["shape_passed"] && value["finite_passed"] && value["time_grid_passed"] for value in values(checks)) &&
        diagnostics["time_convergence"]["time_one_step_error"] <= 1.0e-8 &&
        diagnostics["physical_statistics"]["periodic_boundary_check"] &&
        diagnostics["physical_statistics"]["duplicate_check"]["passed"] &&
        (profile.name === :smoke || diagnostics["lyapunov_spectrum"]["largest_lyapunov_exponent"] > 0)
    certificate = merge(Dict(
        "task_code" => HDND_TASK_CODE,
        "system_name" => "L96-40",
        "profile" => String(profile.name),
        "created_at" => string(now()),
        "finite_check" => all(value["finite_passed"] for value in values(checks)),
        "shape_check" => all(value["shape_passed"] for value in values(checks)),
        "time_grid_check" => all(value["time_grid_passed"] for value in values(checks)),
        "passed" => passed,
    ), diagnostics["time_convergence"], diagnostics["physical_statistics"], diagnostics["split_distribution"], diagnostics["lyapunov_spectrum"])
    certificate["early_late_stationarity"] = diagnostics["stationarity"]
    certificate["split_statistics"] = diagnostics["split_distribution"]
    certificate["autocorrelation_time"] = Dict(key => value["integrated_time"] for (key, value) in diagnostics["autocorrelation"])
    certificate["effective_sample_size"] = Dict(key => value["effective_sample_size"] for (key, value) in diagnostics["autocorrelation"])
    certificate_path = save_json(joinpath(profile.output_root, "l96_nx40_data_certificate_v2.json"), certificate)
    return Dict("path" => path, "certificate_path" => certificate_path, "certificate" => certificate, "representative" => representative)
end

function generate_hdnd_ks64(project_root::AbstractString, profile::HDNDProfile)
    spec = HDNDKSSpec()
    path = joinpath(profile.output_root, "ks64_raw_v2.h5")
    rm(path; force = true)
    mkpath(dirname(path))
    ids = hdnd_split_trajectory_ids(profile)
    samples = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    energies = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    mode1 = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    mode2 = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    check_states = Vector{Vector{Float64}}()
    representative = Dict{String,Matrix{Float64}}()
    initial_states = Matrix{Float64}(undef, total_trajectory_count(profile), spec.nx)
    seeds = Vector{Int}(undef, total_trajectory_count(profile))
    spectrum_by_split = Dict(name => zeros(Float64, spec.nx) for name in HDND_SPLIT_NAMES)
    metadata = Dict(
        "system_name" => "KS64",
        "spatial_dimension" => 64,
        "physical_parameters" => Dict("N_x" => 64, "L_KS" => 22.0),
        "solver_name" => "Fourier pseudospectral ETDRK4",
        "solver_order" => 4,
        "reltol" => "not_applicable_fixed_step",
        "abstol" => "not_applicable_fixed_step",
        "max_internal_step" => spec.dt,
        "spatial_discretization" => "Fourier_pseudospectral_two_thirds_dealiasing",
    )
    h5open(path, "w") do h5
        writers = initialize_system_file!(h5, project_root, profile, metadata, spec.nx, profile.pde_steps, spec.tau)
        for split_name in HDND_SPLIT_NAMES
            labels = fill("attractor", split_count(profile, split_name))
            split_ids = ids[split_name]
            trajectories = Vector{Matrix{Float64}}(undef, length(split_ids))
            Threads.@threads for local_index in eachindex(split_ids)
                trajectory_id = split_ids[local_index]
                seed = trajectory_seed(profile, 2, trajectory_id)
                initial = sample_hdnd_ks_initial_condition(MersenneTwister(seed), spec)
                trajectory = solve_hdnd_ks_trajectory(initial, spec, profile.ks_warm, profile.pde_steps)
                all(isfinite, trajectory) || error("KS trajectory $trajectory_id is not finite")
                trajectories[local_index] = trajectory
            end
            for (local_index, trajectory_id) in enumerate(split_ids)
                seed = trajectory_seed(profile, 2, trajectory_id)
                trajectory = trajectories[local_index]
                write_trajectory!(writers[split_name], local_index, trajectory, trajectory_id, seed, profile.ks_warm)
                initial_states[trajectory_id, :] .= @view trajectory[1, :]
                seeds[trajectory_id] = seed
                energy = hdnd_ks_energy(trajectory)
                coefficients = fft(trajectory, 2) ./ spec.nx
                push!(energies[split_name], energy)
                push!(mode1[split_name], vec(abs2.(@view coefficients[:, 2])))
                push!(mode2[split_name], vec(abs2.(@view coefficients[:, 3])))
                spectrum_by_split[split_name] .+= hdnd_ks_spectrum(trajectory)
                append_sample_states!(samples[split_name], trajectory, profile.sample_states_per_split)
                hdnd_check_state!(check_states, trajectory, profile)
                get!(representative, split_name, copy(trajectory))
                if local_index % 10 == 0 || local_index == length(split_ids)
                    @printf("[HDND KS64] %s trajectory %d/%d written\n", split_name, local_index, length(split_ids))
                end
            end
            empty!(trajectories)
            GC.gc()
            spectrum_by_split[split_name] ./= split_count(profile, split_name)
            write_regime_labels!(writers[split_name], labels)
        end
        convergence = hdnd_ks_time_space_errors(check_states, spec)
        spectrum = (spectrum_by_split["train"] .+ spectrum_by_split["val"] .+ spectrum_by_split["test"]) ./ 3
        modes = hdnd_fft_modes(spec.nx)
        tail_ratio = sum(spectrum[abs.(modes) .> spec.nx / 4]) / (sum(spectrum) + eps(Float64))
        alias_ratio = sum(spectrum[abs.(modes) .> spec.nx / 3]) / (sum(spectrum) + eps(Float64))
        acf = Dict{String,Any}()
        for (observable, source) in (("energy", energies), ("mode1_energy", mode1), ("mode2_energy", mode2))
            curve = mean_acf(source["train"][1:min(end, 16)], min(512, profile.pde_steps))
            tau_int = integrated_autocorrelation_time(curve, spec.tau)
            acf[observable] = Dict(
                "values" => curve,
                "integrated_time" => tau_int,
                "effective_sample_size" => sum(length, source["train"]) * spec.tau / (2tau_int + eps(Float64)),
            )
        end
        zero_mode_error = maximum(abs(mean(state)) for split in values(samples) for state in split)
        physical = Dict(
            "state" => scalar_summary(initial_states),
            "mean_energy" => mean(reduce(vcat, reduce(vcat, values(energies)))),
            "zero_mode_error" => zero_mode_error,
            "high_frequency_tail_ratio" => tail_ratio,
            "alias_band_energy_ratio" => alias_ratio,
            "shift_equivariance_error" => hdnd_ks_shift_error(check_states[1], spec),
            "duplicate_check" => duplicate_check(initial_states, seeds),
        )
        lyapunov = hdnd_ks_lyapunov(@view(representative["train"][1, :]), spec, profile.ks_lyapunov_time)
        split_distribution = pca_distribution_metrics(samples)
        stationarity = Dict(split_name => Dict("energy" => stationarity_summary(energies[split_name])) for split_name in HDND_SPLIT_NAMES)
        diagnostics = Dict(
            "time_convergence" => Dict(key => value for (key, value) in convergence if startswith(key, "time") || key == "sample_count"),
            "space_convergence" => Dict(key => value for (key, value) in convergence if startswith(key, "space") || key == "sample_count"),
            "physical_statistics" => physical,
            "autocorrelation" => acf,
            "energy_spectrum" => Dict("values" => spectrum, "modes" => modes, "split_values" => spectrum_by_split),
            "lyapunov_spectrum" => lyapunov,
            "split_distribution" => split_distribution,
            "stationarity" => stationarity,
        )
        write_diagnostics!(h5, diagnostics)
    end
    checks = finite_time_shape_checks(path, profile, profile.pde_steps + 1, spec.nx)
    diagnostics = h5open(path, "r") do h5
        Dict(key => JSON.parse(read(h5[string("diagnostics/", key)], String)) for key in keys(h5["diagnostics"]))
    end
    passed = all(value["shape_passed"] && value["finite_passed"] && value["time_grid_passed"] for value in values(checks)) &&
        diagnostics["time_convergence"]["time_one_step_error"] <= 1.0e-6 &&
        diagnostics["physical_statistics"]["zero_mode_error"] <= 1.0e-12 &&
        diagnostics["physical_statistics"]["duplicate_check"]["passed"] &&
        (profile.name === :smoke || diagnostics["lyapunov_spectrum"]["largest_lyapunov_exponent"] > 0)
    certificate = merge(Dict(
        "task_code" => HDND_TASK_CODE,
        "system_name" => "KS64",
        "profile" => String(profile.name),
        "created_at" => string(now()),
        "finite_check" => all(value["finite_passed"] for value in values(checks)),
        "shape_check" => all(value["shape_passed"] for value in values(checks)),
        "time_grid_check" => all(value["time_grid_passed"] for value in values(checks)),
        "passed" => passed,
    ), diagnostics["time_convergence"], diagnostics["space_convergence"], diagnostics["physical_statistics"], diagnostics["split_distribution"], diagnostics["lyapunov_spectrum"])
    certificate["early_late_stationarity"] = diagnostics["stationarity"]
    certificate["split_statistics"] = diagnostics["split_distribution"]
    certificate["autocorrelation_time"] = Dict(key => value["integrated_time"] for (key, value) in diagnostics["autocorrelation"])
    certificate["effective_sample_size"] = Dict(key => value["effective_sample_size"] for (key, value) in diagnostics["autocorrelation"])
    certificate["energy_spectrum"] = diagnostics["energy_spectrum"]
    certificate_path = save_json(joinpath(profile.output_root, "ks64_data_certificate_v2.json"), certificate)
    return Dict("path" => path, "certificate_path" => certificate_path, "certificate" => certificate, "representative" => representative)
end

function generate_hdnd_fhn64(project_root::AbstractString, profile::HDNDProfile)
    spec = HDNDFHNSpec()
    path = joinpath(profile.output_root, "fhn64_raw_v2.h5")
    rm(path; force = true)
    mkpath(dirname(path))
    ids = hdnd_split_trajectory_ids(profile)
    samples = Dict(name => Vector{Vector{Float64}}() for name in HDND_SPLIT_NAMES)
    activities = Dict(name => Dict(regime => Vector{Vector{Float64}}() for regime in ("active", "formation", "collision", "recovery")) for name in HDND_SPLIT_NAMES)
    check_states = Vector{Vector{Float64}}()
    representative = Dict{String,Matrix{Float64}}()
    initial_states = Matrix{Float64}(undef, total_trajectory_count(profile), 2spec.nx)
    seeds = Vector{Int}(undef, total_trajectory_count(profile))
    spectrum_u = zeros(Float64, spec.nx); spectrum_v = zeros(Float64, spec.nx)
    metadata = Dict(
        "system_name" => "FHN64",
        "spatial_dimension" => 64,
        "physical_parameters" => Dict("N_x" => 64, "L_FHN" => 32.0, "D_u" => 1.0, "D_v" => 0.0, "epsilon" => 0.08, "a" => 0.7, "b" => 0.8, "I_ext" => 0.0),
        "solver_name" => "Rodas5P",
        "solver_order" => 5,
        "reltol" => spec.reltol,
        "abstol" => spec.abstol,
        "max_internal_step" => spec.dtmax,
        "spatial_discretization" => "periodic_fourth_order_centered_difference",
    )
    h5open(path, "w") do h5
        writers = initialize_system_file!(h5, project_root, profile, metadata, 2spec.nx, profile.pde_steps, spec.tau)
        for split_name in HDND_SPLIT_NAMES
            labels = hdnd_fhn_regime_labels(profile, split_name)
            split_ids = ids[split_name]
            trajectories = Vector{Matrix{Float64}}(undef, length(split_ids))
            warmups = Vector{Float64}(undef, length(split_ids))
            Threads.@threads for local_index in eachindex(split_ids)
                trajectory_id = split_ids[local_index]
                regime = labels[local_index]
                seed = trajectory_seed(profile, 3, trajectory_id)
                initial = sample_hdnd_fhn_initial_condition(MersenneTwister(seed), spec, regime)
                warm = hdnd_fhn_warmup(regime)
                trajectory = solve_hdnd_fhn_trajectory(initial, spec, warm, profile.pde_steps)
                all(isfinite, trajectory) || error("FHN trajectory $trajectory_id is not finite")
                maximum(abs, trajectory) <= 20 || error("FHN trajectory $trajectory_id violates amplitude bound")
                trajectories[local_index] = trajectory
                warmups[local_index] = warm
            end
            for (local_index, trajectory_id) in enumerate(split_ids)
                regime = labels[local_index]
                seed = trajectory_seed(profile, 3, trajectory_id)
                trajectory = trajectories[local_index]
                warm = warmups[local_index]
                write_trajectory!(writers[split_name], local_index, trajectory, trajectory_id, seed, warm)
                initial_states[trajectory_id, :] .= @view trajectory[1, :]
                seeds[trajectory_id] = seed
                push!(activities[split_name][regime], hdnd_fhn_activity(trajectory, spec.nx))
                spectrum_u .+= hdnd_fhn_spectrum(trajectory, 1:spec.nx)
                spectrum_v .+= hdnd_fhn_spectrum(trajectory, (spec.nx + 1):(2spec.nx))
                append_sample_states!(samples[split_name], trajectory, profile.sample_states_per_split)
                hdnd_check_state!(check_states, trajectory, profile)
                get!(representative, regime, copy(trajectory))
                if local_index % 10 == 0 || local_index == length(split_ids)
                    @printf("[HDND FHN64] %s trajectory %d/%d written (latest regime=%s)\n", split_name, local_index, length(split_ids), regime)
                end
            end
            empty!(trajectories)
            GC.gc()
            write_regime_labels!(writers[split_name], labels)
        end
        spectrum_u ./= total_trajectory_count(profile); spectrum_v ./= total_trajectory_count(profile)
        convergence = hdnd_fhn_time_space_errors(check_states, spec)
        activity_statistics = Dict{String,Any}()
        for split_name in HDND_SPLIT_NAMES
            activity_statistics[split_name] = Dict(
                regime => scalar_summary(reduce(vcat, values)) for (regime, values) in activities[split_name]
            )
        end
        pulse_statistics = Dict(regime => hdnd_fhn_pulse_statistics(trajectory, spec) for (regime, trajectory) in representative)
        uv_lags = Dict(regime => hdnd_fhn_uv_phase_lag(trajectory, spec) for (regime, trajectory) in representative)
        acf = Dict{String,Any}()
        for field in ("u", "v")
            range = field == "u" ? (1:spec.nx) : ((spec.nx + 1):(2spec.nx))
            series = [vec(mean(@view(trajectory[:, range]); dims = 2)) for trajectory in values(representative)]
            curve = mean_acf(series, min(512, profile.pde_steps))
            acf[field] = Dict("values" => curve, "integrated_time" => integrated_autocorrelation_time(curve, spec.tau))
        end
        regime_counts = Dict(
            split_name => Dict(regime => count(==(regime), hdnd_fhn_regime_labels(profile, split_name)) for regime in ("active", "formation", "collision", "recovery"))
            for split_name in HDND_SPLIT_NAMES
        )
        physical = Dict(
            "state" => scalar_summary(initial_states),
            "regime_counts" => regime_counts,
            "activity_statistics" => activity_statistics,
            "pulse_statistics" => pulse_statistics,
            "uv_phase_lag_statistics" => uv_lags,
            "shift_equivariance_error" => hdnd_fhn_shift_error(check_states[1], spec),
            "duplicate_check" => duplicate_check(initial_states, seeds),
        )
        stationarity = Dict(
            split_name => Dict(regime => stationarity_summary(values) for (regime, values) in activities[split_name]) for split_name in HDND_SPLIT_NAMES
        )
        diagnostics = Dict(
            "time_convergence" => Dict(key => value for (key, value) in convergence if startswith(key, "time") || key == "sample_count"),
            "space_convergence" => Dict(key => value for (key, value) in convergence if startswith(key, "space") || key == "sample_count"),
            "physical_statistics" => physical,
            "autocorrelation" => acf,
            "energy_spectrum" => Dict("u" => spectrum_u, "v" => spectrum_v, "modes" => hdnd_fft_modes(spec.nx)),
            "lyapunov_spectrum" => Dict("not_required_nonchaotic_default" => true),
            "split_distribution" => Dict("regime_counts" => regime_counts),
            "stationarity" => stationarity,
        )
        write_diagnostics!(h5, diagnostics)
    end
    checks = finite_time_shape_checks(path, profile, profile.pde_steps + 1, 2spec.nx)
    diagnostics = h5open(path, "r") do h5
        Dict(key => JSON.parse(read(h5[string("diagnostics/", key)], String)) for key in keys(h5["diagnostics"]))
    end
    passed = all(value["shape_passed"] && value["finite_passed"] && value["time_grid_passed"] for value in values(checks)) &&
        diagnostics["time_convergence"]["time_one_step_error"] <= 1.0e-6 &&
        diagnostics["physical_statistics"]["duplicate_check"]["passed"]
    pulse_count_statistics = Dict(regime => data["pulse_count_statistics"] for (regime, data) in diagnostics["physical_statistics"]["pulse_statistics"])
    wave_speed_statistics = Dict(regime => data["wave_speed_statistics"] for (regime, data) in diagnostics["physical_statistics"]["pulse_statistics"])
    pulse_width_statistics = Dict(regime => data["pulse_width_statistics"] for (regime, data) in diagnostics["physical_statistics"]["pulse_statistics"])
    certificate = merge(Dict(
        "task_code" => HDND_TASK_CODE,
        "system_name" => "FHN64",
        "profile" => String(profile.name),
        "created_at" => string(now()),
        "finite_check" => all(value["finite_passed"] for value in values(checks)),
        "shape_check" => all(value["shape_passed"] for value in values(checks)),
        "time_grid_check" => all(value["time_grid_passed"] for value in values(checks)),
        "passed" => passed,
    ), diagnostics["time_convergence"], diagnostics["space_convergence"], diagnostics["physical_statistics"])
    certificate["early_late_stationarity"] = diagnostics["stationarity"]
    certificate["split_statistics"] = diagnostics["split_distribution"]
    certificate["autocorrelation_time"] = Dict(key => value["integrated_time"] for (key, value) in diagnostics["autocorrelation"])
    certificate["effective_sample_size"] = Dict("not_reported" => "regime-dependent nonstationary trajectories")
    certificate["pulse_count_statistics"] = pulse_count_statistics
    certificate["wave_speed_statistics"] = wave_speed_statistics
    certificate["pulse_width_statistics"] = pulse_width_statistics
    certificate["u_energy_spectrum"] = diagnostics["energy_spectrum"]["u"]
    certificate["v_energy_spectrum"] = diagnostics["energy_spectrum"]["v"]
    certificate_path = save_json(joinpath(profile.output_root, "fhn64_data_certificate_v2.json"), certificate)
    return Dict("path" => path, "certificate_path" => certificate_path, "certificate" => certificate, "representative" => representative)
end

function save_hdnd_plots(profile::HDNDProfile, runs::AbstractDict)
    plot_dir = joinpath(profile.report_root, "plots")
    mkpath(plot_dir)
    files = String[]
    try
        l96 = runs["l96"]["representative"]["train"]
        push!(files, joinpath(plot_dir, "l96_state_heatmap.png")); Plots.savefig(Plots.heatmap(permutedims(l96); xlabel = "time index", ylabel = "state index", title = "L96-40 representative trajectory"), files[end])
        push!(files, joinpath(plot_dir, "l96_energy.png")); Plots.savefig(Plots.plot(hdnd_l96_energy(l96); xlabel = "time index", ylabel = "energy", title = "L96-40 spatial energy", label = false), files[end])
        l96_cert = runs["l96"]["certificate"]
        push!(files, joinpath(plot_dir, "l96_lyapunov_spectrum.png")); Plots.savefig(Plots.plot(l96_cert["exponents"]; marker = :circle, xlabel = "index", ylabel = "exponent", title = "L96-40 Lyapunov spectrum", label = false), files[end])
        push!(files, joinpath(plot_dir, "l96_time_error_distribution.png")); Plots.savefig(Plots.histogram(l96_cert["sample_errors"]; xlabel = "relative error", title = "L96-40 one-step time error", label = false), files[end])

        ks = runs["ks64"]["representative"]["train"]
        push!(files, joinpath(plot_dir, "ks64_state_heatmap.png")); Plots.savefig(Plots.heatmap(permutedims(ks); xlabel = "time index", ylabel = "x index", title = "KS64 representative trajectory"), files[end])
        push!(files, joinpath(plot_dir, "ks64_energy.png")); Plots.savefig(Plots.plot(hdnd_ks_energy(ks); xlabel = "time index", ylabel = "energy", title = "KS64 total energy", label = false), files[end])
        ks_cert = runs["ks64"]["certificate"]
        push!(files, joinpath(plot_dir, "ks64_energy_spectrum.png")); Plots.savefig(Plots.plot(ks_cert["energy_spectrum"]["values"]; yscale = :log10, xlabel = "FFT index", ylabel = "energy", title = "KS64 Fourier energy spectrum", label = false), files[end])
        push!(files, joinpath(plot_dir, "ks64_lyapunov_spectrum.png")); Plots.savefig(Plots.plot(ks_cert["exponents"]; marker = :circle, xlabel = "index", ylabel = "exponent", title = "KS64 Lyapunov spectrum", label = false), files[end])

        for regime in ("active", "formation", "collision", "recovery")
            trajectory = runs["fhn64"]["representative"][regime]
            push!(files, joinpath(plot_dir, string("fhn64_", regime, "_u_heatmap.png")))
            Plots.savefig(Plots.heatmap(permutedims(@view trajectory[:, 1:64]); xlabel = "time index", ylabel = "x index", title = string("FHN64 ", regime, " u field")), files[end])
        end
        fhn = runs["fhn64"]["representative"]["active"]
        push!(files, joinpath(plot_dir, "fhn64_active_v_heatmap.png")); Plots.savefig(Plots.heatmap(permutedims(@view fhn[:, 65:128]); xlabel = "time index", ylabel = "x index", title = "FHN64 active v field"), files[end])
        push!(files, joinpath(plot_dir, "fhn64_activity.png")); Plots.savefig(Plots.plot(hdnd_fhn_activity(fhn, 64); xlabel = "time index", ylabel = "activity", title = "FHN64 activity", label = false), files[end])
        fhn_cert = runs["fhn64"]["certificate"]
        push!(files, joinpath(plot_dir, "fhn64_uv_energy_spectrum.png")); Plots.savefig(Plots.plot(fhn_cert["u_energy_spectrum"]; yscale = :log10, label = "u", xlabel = "FFT index", ylabel = "energy", title = "FHN64 field spectra"), files[end]); Plots.plot!(fhn_cert["v_energy_spectrum"]; label = "v"); Plots.savefig(Plots.current(), files[end])
    catch error
        @warn "HDND plot generation failed" exception = (error, catch_backtrace())
    end
    return files
end

function save_hdnd_summary_table(profile::HDNDProfile, runs::AbstractDict)
    path = joinpath(profile.report_root, "tables", "generation_summary.csv")
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "system,train_trajectories,val_trajectories,test_trajectories,snapshots,state_dimension,time_one_step_error,space_one_step_error,passed")
        for (key, dim, steps) in (("l96", 40, profile.l96_steps), ("ks64", 64, profile.pde_steps), ("fhn64", 128, profile.pde_steps))
            cert = runs[key]["certificate"]
            println(io, join((
                cert["system_name"], profile.split_counts.train, profile.split_counts.val, profile.split_counts.test,
                steps + 1, dim, cert["time_one_step_error"], get(cert, "space_one_step_error", ""), cert["passed"],
            ), ','))
        end
    end
    return path
end

function read_hdnd_diagnostic(path::AbstractString, name::AbstractString)
    return h5open(path, "r") do h5
        JSON.parse(read(h5[string("diagnostics/", name)], String))
    end
end

function read_hdnd_representative(path::AbstractString; split_name::AbstractString = "train", trajectory_index::Integer = 1)
    return h5open(path, "r") do h5
        Matrix{Float64}(h5[string(split_name, "/state")][trajectory_index, :, :])
    end
end

function hdnd_release_pca_projection(path::AbstractString; trajectories_per_split::Integer = 16, times_per_trajectory::Integer = 32)
    samples = Dict{String,Matrix{Float64}}()
    h5open(path, "r") do h5
        for split_name in HDND_SPLIT_NAMES
            state = h5[string(split_name, "/state")]
            trajectory_indices = evenly_spaced_indices(size(state, 1), trajectories_per_split)
            time_indices = evenly_spaced_indices(size(state, 2), times_per_trajectory)
            matrix = Matrix{Float64}(undef, length(trajectory_indices) * length(time_indices), size(state, 3))
            row = 1
            for trajectory_index in trajectory_indices
                trajectory = state[trajectory_index, :, :]
                for time_index in time_indices
                    matrix[row, :] .= @view trajectory[time_index, :]
                    row += 1
                end
            end
            samples[split_name] = matrix
        end
    end
    center = vec(mean(samples["train"]; dims = 1))
    _, _, vectors = svd(samples["train"] .- center'; full = false)
    projection = vectors[:, 1:2]
    return Dict(split_name => (matrix .- center') * projection for (split_name, matrix) in samples)
end

function hdnd_spatial_autocorrelation(trajectory::AbstractMatrix; max_lag::Integer = size(trajectory, 2) ÷ 2, time_stride::Integer = 10)
    result = zeros(Float64, max_lag + 1)
    count = 0
    for time_index in 1:time_stride:size(trajectory, 1)
        field = collect(Float64, @view trajectory[time_index, :])
        field .-= mean(field)
        variance = mean(abs2, field)
        variance <= eps(Float64) && continue
        for lag in 0:max_lag
            result[lag + 1] += dot(field, circshift(field, lag)) / (length(field) * variance)
        end
        count += 1
    end
    return result ./ max(count, 1)
end

function save_hdnd_required_release_plots(project_root::AbstractString; profile_name::Symbol = :formal)
    profile = hdnd_profile(project_root, profile_name)
    plot_dir = joinpath(profile.report_root, "plots")
    mkpath(plot_dir)
    files = String[]
    paths = Dict(
        "l96" => joinpath(profile.output_root, "l96_nx40_raw_v2.h5"),
        "ks64" => joinpath(profile.output_root, "ks64_raw_v2.h5"),
        "fhn64" => joinpath(profile.output_root, "fhn64_raw_v2.h5"),
    )

    l96_autocorrelation = read_hdnd_diagnostic(paths["l96"], "autocorrelation")
    l96_acf_plot = Plots.plot(; xlabel = "lag index", ylabel = "autocorrelation", title = "L96-40 temporal autocorrelation")
    for observable in ("energy", "spatial_mean", "x1")
        Plots.plot!(l96_acf_plot, l96_autocorrelation[observable]["values"]; label = observable)
    end
    push!(files, joinpath(plot_dir, "l96_temporal_autocorrelation.png")); Plots.savefig(l96_acf_plot, files[end])
    l96_spectrum = read_hdnd_diagnostic(paths["l96"], "energy_spectrum")["temporal_power_spectral_density_x1"]
    push!(files, joinpath(plot_dir, "l96_power_spectral_density.png")); Plots.savefig(Plots.plot(l96_spectrum[1:(length(l96_spectrum) ÷ 2)]; yscale = :log10, xlabel = "frequency index", ylabel = "power", title = "L96-40 x1 power spectral density", label = false), files[end])
    l96_projection = hdnd_release_pca_projection(paths["l96"])
    l96_projection_plot = Plots.scatter(; xlabel = "train PCA coordinate 1", ylabel = "train PCA coordinate 2", title = "L96-40 split statistical projection", markersize = 2)
    for split_name in HDND_SPLIT_NAMES
        Plots.scatter!(l96_projection_plot, l96_projection[split_name][:, 1], l96_projection[split_name][:, 2]; label = split_name, markersize = 2, alpha = 0.55)
    end
    push!(files, joinpath(plot_dir, "l96_split_statistical_projection.png")); Plots.savefig(l96_projection_plot, files[end])

    ks_trajectory = read_hdnd_representative(paths["ks64"])
    ks_autocorrelation = read_hdnd_diagnostic(paths["ks64"], "autocorrelation")
    ks_spatial_acf = hdnd_spatial_autocorrelation(ks_trajectory)
    ks_acf_plot = Plots.plot(ks_autocorrelation["energy"]["values"]; label = "temporal energy", xlabel = "lag index", ylabel = "autocorrelation", title = "KS64 temporal and spatial autocorrelation")
    Plots.plot!(ks_acf_plot, ks_spatial_acf; label = "spatial field")
    push!(files, joinpath(plot_dir, "ks64_temporal_spatial_autocorrelation.png")); Plots.savefig(ks_acf_plot, files[end])
    ks_spectrum = read_hdnd_diagnostic(paths["ks64"], "energy_spectrum")
    modes = Int.(ks_spectrum["modes"])
    spectrum_values = Float64.(ks_spectrum["values"])
    tail_mask = abs.(modes) .> 16
    push!(files, joinpath(plot_dir, "ks64_high_frequency_tail.png")); Plots.savefig(Plots.scatter(abs.(modes[tail_mask]), spectrum_values[tail_mask]; yscale = :log10, xlabel = "absolute Fourier mode", ylabel = "energy", title = "KS64 high-frequency energy tail", label = false), files[end])
    ks_projection = hdnd_release_pca_projection(paths["ks64"])
    ks_projection_plot = Plots.scatter(; xlabel = "train PCA coordinate 1", ylabel = "train PCA coordinate 2", title = "KS64 split statistical projection", markersize = 2)
    for split_name in HDND_SPLIT_NAMES
        Plots.scatter!(ks_projection_plot, ks_projection[split_name][:, 1], ks_projection[split_name][:, 2]; label = split_name, markersize = 2, alpha = 0.55)
    end
    push!(files, joinpath(plot_dir, "ks64_split_statistical_projection.png")); Plots.savefig(ks_projection_plot, files[end])
    ks_certificate = JSON.parsefile(joinpath(profile.output_root, "ks64_data_certificate_v2.json"))
    push!(files, joinpath(plot_dir, "ks64_space_convergence.png")); Plots.savefig(Plots.histogram(ks_certificate["space_sample_errors"]; xlabel = "relative one-step error", ylabel = "count", title = "KS64 Nx=64 vs Nx=128 convergence", label = false), files[end])

    fhn_autocorrelation = read_hdnd_diagnostic(paths["fhn64"], "autocorrelation")
    fhn_acf_plot = Plots.plot(fhn_autocorrelation["u"]["values"]; label = "u", xlabel = "lag index", ylabel = "autocorrelation", title = "FHN64 temporal autocorrelation")
    Plots.plot!(fhn_acf_plot, fhn_autocorrelation["v"]["values"]; label = "v")
    push!(files, joinpath(plot_dir, "fhn64_uv_temporal_autocorrelation.png")); Plots.savefig(fhn_acf_plot, files[end])
    fhn_certificate = JSON.parsefile(joinpath(profile.output_root, "fhn64_data_certificate_v2.json"))
    regimes = ["active", "formation", "collision", "recovery"]
    speed_means = [get(fhn_certificate["wave_speed_statistics"][regime], "mean", 0.0) for regime in regimes]
    width_means = [get(fhn_certificate["pulse_width_statistics"][regime], "mean", 0.0) for regime in regimes]
    pulse_plot = Plots.bar(regimes, [speed_means width_means]; label = ["wave speed" "pulse width"], xlabel = "regime", ylabel = "mean diagnostic value", title = "FHN64 wave-speed and pulse-width summaries", rotation = 20)
    push!(files, joinpath(plot_dir, "fhn64_wave_speed_pulse_width.png")); Plots.savefig(pulse_plot, files[end])
    convergence_values = [
        fhn_certificate["space_one_step_error_u"],
        fhn_certificate["space_one_step_error_v"],
        fhn_certificate["space_one_step_error"],
    ]
    push!(files, joinpath(plot_dir, "fhn64_space_convergence.png")); Plots.savefig(Plots.bar(["u", "v", "combined"], convergence_values; yscale = :log10, ylabel = "relative one-step error", title = "FHN64 Nx=64 vs Nx=128 convergence", label = false), files[end])
    return files
end

function refresh_hdnd_release_certificates(project_root::AbstractString; profile_name::Symbol = :formal)
    profile = hdnd_profile(project_root, profile_name)
    definitions = (
        (key = "l96", filename = "l96_nx40_raw_v2.h5", certificate = "l96_nx40_data_certificate_v2.json", nt = profile.l96_steps + 1, dim = 40),
        (key = "ks64", filename = "ks64_raw_v2.h5", certificate = "ks64_data_certificate_v2.json", nt = profile.pde_steps + 1, dim = 64),
        (key = "fhn64", filename = "fhn64_raw_v2.h5", certificate = "fhn64_data_certificate_v2.json", nt = profile.pde_steps + 1, dim = 128),
    )
    runs = Dict{String,Any}()
    for definition in definitions
        data_path = joinpath(profile.output_root, definition.filename)
        certificate_path = joinpath(profile.output_root, definition.certificate)
        checks = finite_time_shape_checks(data_path, profile, definition.nt, definition.dim)
        certificate = JSON.parsefile(certificate_path)
        certificate["finite_check"] = all(value["finite_passed"] for value in values(checks))
        certificate["shape_check"] = all(value["shape_passed"] for value in values(checks))
        certificate["time_grid_check"] = all(value["time_grid_passed"] for value in values(checks))
        common_passed = certificate["finite_check"] && certificate["shape_check"] && certificate["time_grid_check"] && certificate["duplicate_check"]["passed"]
        system_passed = if definition.key == "l96"
            certificate["time_one_step_error"] <= 1.0e-8 && certificate["largest_lyapunov_exponent"] > 0
        elseif definition.key == "ks64"
            certificate["time_one_step_error"] <= 1.0e-6 && certificate["zero_mode_error"] <= 1.0e-12 && certificate["largest_lyapunov_exponent"] > 0
        else
            certificate["time_one_step_error"] <= 1.0e-6
        end
        certificate["passed"] = common_passed && system_passed
        save_json(certificate_path, certificate)
        runs[definition.key] = Dict("path" => data_path, "certificate_path" => certificate_path, "certificate" => certificate)
    end
    table_path = save_hdnd_summary_table(profile, runs)
    summary = Dict(
        "task_code" => HDND_TASK_CODE,
        "profile" => String(profile.name),
        "created_at" => string(now()),
        "source_policy" => "fresh_numerical_integration_only",
        "normalization_policy" => "none",
        "output_root" => profile.output_root,
        "report_root" => profile.report_root,
        "table_path" => table_path,
        "passed" => all(run["certificate"]["passed"] for run in values(runs)),
        "systems" => Dict(key => Dict("path" => run["path"], "certificate_path" => run["certificate_path"], "passed" => run["certificate"]["passed"]) for (key, run) in runs),
    )
    summary_path = save_json(joinpath(profile.report_root, "logs", string("run_summary_", profile.name, ".json")), summary)
    summary["summary_path"] = summary_path
    return summary
end

function run_hdnd_generation(project_root::AbstractString; profile_name::Symbol = :formal)
    profile = hdnd_profile(project_root, profile_name)
    mkpath(profile.output_root)
    mkpath(profile.report_root)
    runs = Dict{String,Any}()
    runs["l96"] = generate_hdnd_l96(project_root, profile)
    GC.gc()
    runs["ks64"] = generate_hdnd_ks64(project_root, profile)
    GC.gc()
    runs["fhn64"] = generate_hdnd_fhn64(project_root, profile)
    GC.gc()
    table_path = save_hdnd_summary_table(profile, runs)
    plot_files = unique(vcat(save_hdnd_plots(profile, runs), save_hdnd_required_release_plots(project_root; profile_name = profile_name)))
    passed = all(run["certificate"]["passed"] for run in values(runs))
    summary = Dict(
        "task_code" => HDND_TASK_CODE,
        "profile" => String(profile.name),
        "created_at" => string(now()),
        "source_policy" => "fresh_numerical_integration_only",
        "normalization_policy" => "none",
        "output_root" => profile.output_root,
        "report_root" => profile.report_root,
        "table_path" => table_path,
        "plot_files" => plot_files,
        "passed" => passed,
        "systems" => Dict(key => Dict("path" => run["path"], "certificate_path" => run["certificate_path"], "passed" => run["certificate"]["passed"]) for (key, run) in runs),
    )
    summary_path = save_json(joinpath(profile.report_root, "logs", string("run_summary_", profile.name, ".json")), summary)
    summary["summary_path"] = summary_path
    return summary
end

function print_hdnd_summary(summary::AbstractDict)
    @printf("task_code: %s\n", summary["task_code"])
    @printf("profile: %s\n", summary["profile"])
    @printf("source_policy: %s\n", summary["source_policy"])
    @printf("passed: %s\n", summary["passed"])
    for system in ("l96", "ks64", "fhn64")
        @printf("%s: %s (passed=%s)\n", system, summary["systems"][system]["path"], summary["systems"][system]["passed"])
    end
    @printf("summary_path: %s\n", summary["summary_path"])
end
