const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "highdim_nonlinear_v2_generation.jl"))

function run_highdim_nonlinear_v2_formal()
    summary = run_hdnd_generation(PROJECT_ROOT; profile_name = :formal)
    print_hdnd_summary(summary)
    summary["passed"] || error("highdim_nonlinear_v2 formal generation failed")
    return summary
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    run_highdim_nonlinear_v2_formal()
end
