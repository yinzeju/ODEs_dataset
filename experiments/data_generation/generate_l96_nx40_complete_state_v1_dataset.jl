## Complete-state Lorenz96 Nx=40 v1 dataset generation entry point

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "l96_nx40_complete_state_v1_generation.jl"))

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    result = generate_l96_nx40_complete_state_v1(PROJECT_ROOT)
    print_l96_nx40_summary(result)
    result.diagnostics["all_passed"] || error("l96_nx40_complete_state_v1 failed acceptance checks")
end
