using Printf

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "pdeid_fhn32_fhn64_ks64_generation.jl"))

function run_pdeid_smoke()
    summary = run_pdeid_fhn32_fhn64_ks64_generation(PROJECT_ROOT; profile_name = :smoke)
    print_pdeid_summary(summary)
    summary["passed"] || error("PDEID FHN32/FHN64/KS64 smoke generation failed diagnostics")
    return summary
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    run_pdeid_smoke()
end
