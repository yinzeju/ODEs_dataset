## Purpose and registry boundary

## Register dataset family

function kdsm_registered_release_id()
    return "kdsm_duffing_diagnostic_v1"
end

## Register system objects D0 to D9

function kdsm_validate_object_registry(system_config::AbstractDict)
    objects = system_config["objects"]
    ids = [String(object["object_id"]) for object in objects]
    length(ids) == length(unique(ids)) || throw(ArgumentError("duplicate object_id in KDSM Duffing registry"))
    expected = Set([
        "kdsm_duffing__D0_near_linear_damped",
        "kdsm_duffing__D1_single_well_hardening",
        "kdsm_duffing__D2_amplitude_frequency_drift",
        "kdsm_duffing__D3a_double_well_local_left",
        "kdsm_duffing__D3b_double_well_local_right",
        "kdsm_duffing__D3_double_well_local_mixed",
        "kdsm_duffing__D4_double_well_cross_well",
        "kdsm_duffing__D5_periodic_forced_stable",
        "kdsm_duffing__D6_two_frequency_forced",
        "kdsm_duffing__D7_chaotic_forced",
        "kdsm_duffing__D8_highdim_target_poly9",
        "kdsm_duffing__D9_noise_scan__noise_clean",
        "kdsm_duffing__D9_noise_scan__noise_1em4",
        "kdsm_duffing__D9_noise_scan__noise_1em3",
        "kdsm_duffing__D9_noise_scan__noise_1em2",
        "kdsm_duffing__D9_noise_scan__noise_1em1",
    ])
    Set(ids) == expected || throw(ArgumentError("KDSM Duffing object ids do not match the fixed D0-D9 table"))
    return true
end

## Register forcing ids

function kdsm_registered_forcing_ids()
    return ["force_none", "force_harmonic_1", "force_harmonic_2", "force_lorenz_readout"]
end

## Register observation ids

kdsm_registered_observation_ids() = ["obs_aug_full", "obs_phys_only"]

## Register target ids

kdsm_registered_target_ids() = ["target_phys", "target_aug", "target_poly9", "target_energy5"]

## Register split id

kdsm_registered_split_id() = "split_trajectory_I"

## Registry uniqueness checks

function kdsm_validate_registry_configs(system_config::AbstractDict, observation_config::AbstractDict)
    kdsm_validate_object_registry(system_config)
    Set(String.(observation_config["observation_modes"])) == Set(kdsm_registered_observation_ids()) ||
        throw(ArgumentError("observation registry mismatch"))
    Set(String.(observation_config["target_modes"])) == Set(kdsm_registered_target_ids()) ||
        throw(ArgumentError("target registry mismatch"))
    return true
end
