## Formal HSKL baseline ODE v1 release generation entry point

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "hskl_baseline_ode_v1_generation.jl"))

function main()
    manifest = generate_hskl_baseline_ode_v1(formal_difficulties = ["medium"])
    print_hskl_release_summary(manifest)
    return manifest
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
