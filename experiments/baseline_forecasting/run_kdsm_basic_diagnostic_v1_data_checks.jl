## Purpose and full release scope

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "dynamics", "kdsm_basic_diagnostic_systems.jl"))
include(joinpath(PROJECT_ROOT, "src", "observations", "kdsm_basic_diagnostic_observations.jl"))
include(joinpath(PROJECT_ROOT, "src", "splits", "kdsm_basic_diagnostic_splits.jl"))
include(joinpath(PROJECT_ROOT, "src", "windows", "kdsm_basic_diagnostic_windows.jl"))
include(joinpath(PROJECT_ROOT, "src", "datasets", "kdsm_basic_diagnostic_dataset_objects.jl"))
include(joinpath(PROJECT_ROOT, "src", "io", "kdsm_basic_diagnostic_io.jl"))
include(joinpath(PROJECT_ROOT, "src", "manifests", "kdsm_basic_diagnostic_manifest.jl"))
include(joinpath(PROJECT_ROOT, "src", "registries", "kdsm_basic_diagnostic_registry.jl"))
include(joinpath(PROJECT_ROOT, "src", "diagnostics", "kdsm_basic_diagnostic_data_checks.jl"))
include(joinpath(PROJECT_ROOT, "src", "generators", "kdsm_basic_diagnostic_generator.jl"))

## Generate all basic diagnostic objects

function run_kdsm_basic_diagnostic_v1_data_checks()
    return kbasic_run_release_generation(PROJECT_ROOT; difficulty = "default")
end

## Print full release summary

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    result = run_kdsm_basic_diagnostic_v1_data_checks()
    kbasic_print_release_summary(result)
    result["release_index"]["all_passed"] || error("kdsm_basic_diagnostic_v1 release generation failed diagnostics")
end
