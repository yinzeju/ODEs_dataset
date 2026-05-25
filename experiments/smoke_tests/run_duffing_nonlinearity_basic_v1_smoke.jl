## Smoke entry point for Duffing nonlinearity basic v1

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "dynamics", "duffing_nonlinearity_matrix_v1_systems.jl"))
include(joinpath(PROJECT_ROOT, "src", "generators", "duffing_nonlinearity_matrix_v1_generator.jl"))
include(joinpath(PROJECT_ROOT, "src", "generators", "duffing_nonlinearity_basic_v1_generator.jl"))

function run_duffing_nonlinearity_basic_v1_smoke()
    return dnlbasic_run_release_generation(PROJECT_ROOT; difficulty = "smoke")
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    result = run_duffing_nonlinearity_basic_v1_smoke()
    dnlbasic_print_release_summary(result)
    result["release_index"]["all_passed"] || error("duffing_nonlinearity_basic_v1 smoke failed diagnostics")
    result["release_index"]["initial_condition_reuse_passed"] ||
        error("duffing_nonlinearity_basic_v1 smoke initial condition reuse check failed")
end
