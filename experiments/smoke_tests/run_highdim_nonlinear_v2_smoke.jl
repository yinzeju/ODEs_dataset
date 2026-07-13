const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "highdim_nonlinear_v2_generation.jl"))

function run_highdim_nonlinear_v2_smoke()
    summary = run_hdnd_generation(PROJECT_ROOT; profile_name = :smoke)
    print_hdnd_summary(summary)
    summary["passed"] || error("highdim_nonlinear_v2 smoke generation failed")
    return summary
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    run_highdim_nonlinear_v2_smoke()
end
