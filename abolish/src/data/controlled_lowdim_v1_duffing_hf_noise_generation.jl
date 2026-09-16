using JLD2
using JSON
using Printf
using Random
using Statistics

struct CLDHFNoise10Spec
    task_id::String
    source_dataset::String
    output_dataset::String
    output_metadata::String
    state_key::String
    target_key::String
    forcing_key::String
    training_role::String
    snr_db::Float64
    noise_seed::Int
    noise_model::String
    channel_power_source::String
    target_mode::String
    forcing_mode::String
end

function cldhf_load_noise10_spec(config_path::AbstractString)
    raw = JSON.parsefile(config_path)
    return CLDHFNoise10Spec(
        String(raw["task_id"]),
        String(raw["source_dataset"]),
        String(raw["output_dataset"]),
        String(raw["output_metadata"]),
        String(raw["state_key"]),
        String(raw["target_key"]),
        String(raw["forcing_key"]),
        String(raw["training_role"]),
        Float64(raw["snr_db"]),
        Int(raw["noise_seed"]),
        String(raw["noise_model"]),
        String(raw["channel_power_source"]),
        String(raw["target_mode"]),
        String(raw["forcing_mode"]),
    )
end

function cldhf_channelwise_training_power(
    clean::AbstractArray{<:Real,3},
    split_id::AbstractVector{<:AbstractString},
    training_role::AbstractString,
)
    training = findall(==(String(training_role)), String.(split_id))
    isempty(training) && throw(ArgumentError(
        "The clean release does not contain training trajectories.",
    ))
    return [
        mean(abs2, @view clean[training, :, channel])
        for channel in axes(clean, 3)
    ], training
end

function cldhf_add_noise10(
    clean::AbstractArray{<:Real,3},
    channel_power::AbstractVector{<:Real},
    snr_db::Real,
    noise_seed::Integer,
)
    length(channel_power) == size(clean, 3) || throw(DimensionMismatch(
        "Channel powers do not match the clean state tensor.",
    ))
    noise_std = sqrt.(Float64.(channel_power) .* 10.0^(-Float64(snr_db) / 10.0))
    rng = MersenneTwister(Int(noise_seed))
    noisy = Array{Float32}(undef, size(clean))
    @inbounds for trajectory in axes(clean, 1)
        for time in axes(clean, 2)
            for channel in axes(clean, 3)
                noisy[trajectory, time, channel] = Float32(
                    Float64(clean[trajectory, time, channel]) +
                    noise_std[channel] * randn(rng),
                )
            end
        end
    end
    return noisy, noise_std
end

function cldhf_empirical_snr_db(
    clean::AbstractArray{<:Real,3},
    noisy::AbstractArray{<:Real,3},
    training::AbstractVector{<:Integer},
)
    size(clean) == size(noisy) || throw(DimensionMismatch(
        "Clean and noisy tensors must have identical shapes.",
    ))
    values = Vector{Float64}(undef, size(clean, 3))
    for channel in axes(clean, 3)
        signal_energy = sum(abs2, @view clean[training, :, channel])
        noise_energy = 0.0
        @inbounds for trajectory in training
            for time in axes(clean, 2)
                residual = Float64(noisy[trajectory, time, channel]) -
                    Float64(clean[trajectory, time, channel])
                noise_energy += residual * residual
            end
        end
        values[channel] = 10log10(signal_energy / max(noise_energy, eps(Float64)))
    end
    return values
end

function cldhf_write_noise10_metadata(
    path::AbstractString,
    metadata::AbstractDict,
)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON.print(io, metadata, 2)
    end
    return path
end

function generate_controlled_lowdim_v1_duffing_hf_addc_noise10(
    project_root::AbstractString;
    config_path::AbstractString = joinpath(
        project_root,
        "configs",
        "releases",
        "controlled_lowdim_v1_duffing_hf_addc_noise10.json",
    ),
)
    spec = cldhf_load_noise10_spec(config_path)
    source_path = normpath(joinpath(project_root, spec.source_dataset))
    output_path = normpath(joinpath(project_root, spec.output_dataset))
    metadata_path = normpath(joinpath(project_root, spec.output_metadata))
    isfile(source_path) || throw(ArgumentError(
        "The DUF-HF-ADD clean release is missing: $(source_path)",
    ))

    payload = JLD2.jldopen(source_path, "r") do file
        file["dataset_id"] == "duffing_hf_addc" || throw(ArgumentError(
            "Noise generation requires the duffing_hf_addc clean release.",
        ))
        file["view_id"] == "clean" || throw(ArgumentError(
            "The source DUF-HF-ADD view must be clean.",
        ))
        (
            dataset_id = String(file["dataset_id"]),
            protocol = String(file["protocol"]),
            array_layout = String(file["array_layout"]),
            clean = Array{Float32}(file[spec.state_key]),
            target = Array{Float32}(file[spec.target_key]),
            forcing = Array{Float32}(file[spec.forcing_key]),
            split_id = String.(file["split_id"]),
            trajectory_id = Int.(file["trajectory_id"]),
            time_state = Array{Float32}(file["time_state"]),
            time_transition = Array{Float32}(file["time_transition"]),
            forcing_exposed_to_learner =
                Bool(file["forcing_exposed_to_learner"]),
            source_state_in_learner_state =
                Bool(file["source_state_in_learner_state"]),
            source_state_exposed_to_encoder =
                Bool(file["source_state_exposed_to_encoder"]),
            normalization_policy = String(file["normalization_policy"]),
            endpoint_policy = String(file["endpoint_policy"]),
            fs_model = Float64(file["fs_model"]),
        )
    end

    size(payload.clean) == size(payload.target) || throw(DimensionMismatch(
        "The DUF-HF-ADD state and target tensors differ.",
    ))
    size(payload.forcing, 1) == size(payload.clean, 1) ||
        throw(DimensionMismatch("State and forcing trajectory counts differ."))
    size(payload.forcing, 2) == size(payload.clean, 2) - 1 ||
        throw(DimensionMismatch("Forcing must align with state transitions."))

    channel_power, training = cldhf_channelwise_training_power(
        payload.clean,
        payload.split_id,
        spec.training_role,
    )
    noisy, noise_std = cldhf_add_noise10(
        payload.clean,
        channel_power,
        spec.snr_db,
        spec.noise_seed,
    )
    empirical_snr = cldhf_empirical_snr_db(
        payload.clean,
        noisy,
        training,
    )
    all_finite = all(isfinite, noisy)
    snr_passed = all(abs.(empirical_snr .- spec.snr_db) .<= 0.2)
    passed = all_finite && snr_passed

    metadata = Dict{String,Any}(
        "task_id" => spec.task_id,
        "dataset_id" => payload.dataset_id,
        "view_id" => "noise10",
        "source_dataset" => source_path,
        "output_dataset" => output_path,
        "array_layout" => payload.array_layout,
        "normalization_policy" => payload.normalization_policy,
        "snr_db" => spec.snr_db,
        "noise_seed" => spec.noise_seed,
        "noise_model" => spec.noise_model,
        "channel_power_source" => spec.channel_power_source,
        "training_channel_power" => channel_power,
        "noise_std" => noise_std,
        "empirical_training_snr_db" => empirical_snr,
        "target_mode" => spec.target_mode,
        "forcing_mode" => spec.forcing_mode,
        "state_shape" => collect(size(noisy)),
        "forcing_shape" => collect(size(payload.forcing)),
        "training_trajectory_count" => length(training),
        "all_finite" => all_finite,
        "snr_within_0dot2_db" => snr_passed,
        "passed" => passed,
    )

    mkpath(dirname(output_path))
    JLD2.jldsave(
        output_path;
        dataset_id = payload.dataset_id,
        view_id = "noise10",
        protocol = payload.protocol,
        array_layout = payload.array_layout,
        state_observation_noise10 = noisy,
        learner_state_noise10 = noisy,
        target_clean = payload.target,
        learner_target_clean = payload.target,
        control_feature_clean = payload.forcing,
        forcing_exposed_to_learner =
            payload.forcing_exposed_to_learner,
        source_state_in_learner_state =
            payload.source_state_in_learner_state,
        source_state_exposed_to_encoder =
            payload.source_state_exposed_to_encoder,
        trajectory_id = payload.trajectory_id,
        split_id = payload.split_id,
        time_state = payload.time_state,
        time_transition = payload.time_transition,
        fs_model = payload.fs_model,
        endpoint_policy = payload.endpoint_policy,
        normalization_policy = payload.normalization_policy,
        noise_metadata = metadata,
    )
    cldhf_write_noise10_metadata(metadata_path, metadata)

    @printf(
        "DUF-HF-ADD noise10: sigma=(%.9g, %.9g), empirical SNR=(%.6f, %.6f) dB\n",
        noise_std[1],
        noise_std[2],
        empirical_snr[1],
        empirical_snr[2],
    )
    println("  dataset: ", output_path)
    println("  metadata: ", metadata_path)
    println("  passed: ", passed)
    return metadata
end
