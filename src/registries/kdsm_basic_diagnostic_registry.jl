## Register object ids, config ids, task ids, release id

function kbasic_registered_release_id()
    return kbasic_release_id()
end

function kbasic_registered_observation_ids()
    return ["obs_phys", "obs_aug_full"]
end

function kbasic_registered_target_ids()
    return ["target_phys"]
end

function kbasic_registered_split_id()
    return "kdsm_basic_split_trajectory_I"
end

function kbasic_validate_object_registry(system_config::AbstractDict)
    objects = system_config["objects"]
    ids = [String(object["object_id"]) for object in objects]
    length(ids) == length(unique(ids)) || throw(ArgumentError("duplicate kdsm_basic object_id"))
    ids == kbasic_expected_object_ids() ||
        throw(ArgumentError("kdsm_basic object ids must match the fixed diagnostic ladder"))
    betas = [Float64(get(object, "beta", 0.0)) for object in objects if String(object["system_kind"]) == "weak_duffing"]
    betas == sort(betas) || throw(ArgumentError("weak Duffing beta ladder must be monotone"))
    return true
end

function kbasic_validate_registry_configs(system_config::AbstractDict, observation_config::AbstractDict)
    kbasic_validate_object_registry(system_config)
    Set(String.(observation_config["observation_modes"])) == Set(kbasic_registered_observation_ids()) ||
        throw(ArgumentError("observation registry mismatch"))
    Set(String.(observation_config["target_modes"])) == Set(kbasic_registered_target_ids()) ||
        throw(ArgumentError("target registry mismatch"))
    return true
end
