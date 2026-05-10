## Purpose and full release scope

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "dynamics", "kdsm_duffing_diagnostic_v1_forcing.jl"))
include(joinpath(PROJECT_ROOT, "src", "dynamics", "kdsm_duffing_diagnostic_v1_dynamics.jl"))
include(joinpath(PROJECT_ROOT, "src", "observations", "kdsm_duffing_diagnostic_v1_observations.jl"))
include(joinpath(PROJECT_ROOT, "src", "observations", "kdsm_duffing_diagnostic_v1_noise.jl"))
include(joinpath(PROJECT_ROOT, "src", "splits", "kdsm_duffing_diagnostic_v1_splits.jl"))
include(joinpath(PROJECT_ROOT, "src", "datasets", "kdsm_duffing_diagnostic_v1_dataset_objects.jl"))
include(joinpath(PROJECT_ROOT, "src", "io", "kdsm_duffing_diagnostic_v1_io.jl"))
include(joinpath(PROJECT_ROOT, "src", "manifests", "kdsm_duffing_diagnostic_v1_manifests.jl"))
include(joinpath(PROJECT_ROOT, "src", "registries", "kdsm_duffing_diagnostic_v1_registry.jl"))
include(joinpath(PROJECT_ROOT, "src", "diagnostics", "kdsm_duffing_diagnostic_v1_data_checks.jl"))
include(joinpath(PROJECT_ROOT, "src", "generators", "kdsm_duffing_diagnostic_v1_generator.jl"))

## Generate all D0 to D9 objects

function run_kdsm_duffing_diagnostic_v1_release_generation()
    return kdsm_run_release_generation(PROJECT_ROOT; difficulty = "default")
end

## Print full release summary

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    result = run_kdsm_duffing_diagnostic_v1_release_generation()
    kdsm_print_release_summary(result)
    result["release_index"]["all_passed"] || error("kdsm_duffing_diagnostic_v1 release generation failed diagnostics")
end
