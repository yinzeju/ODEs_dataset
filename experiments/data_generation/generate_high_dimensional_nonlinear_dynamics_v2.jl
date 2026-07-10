const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "high_dimensional_nonlinear_dynamics_v2_generation.jl"))

function run_hdnd_formal()
    summary = run_hdnd_generation(PROJECT_ROOT; profile_name = :formal)
    print_hdnd_summary(summary)
    summary["passed"] || error("HDND v2 formal generation failed")
    return summary
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    run_hdnd_formal()
end
