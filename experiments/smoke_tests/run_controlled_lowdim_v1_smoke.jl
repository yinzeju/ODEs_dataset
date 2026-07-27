const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(PROJECT_ROOT, "src", "data", "controlled_lowdim_v1_generation.jl"))

function main()
    manifest = generate_controlled_lowdim_v1(PROJECT_ROOT; profile = :smoke)
    manifest["all_passed"] || error("controlled_lowdim_v1 smoke validation failed")
    manifest["clean_dataset_count"] == 12 || error("expected 12 clean smoke datasets")
    manifest["observed_dataset_count"] == 12 || error("expected 12 observed smoke datasets")
    println("controlled_lowdim_v1 smoke passed: 12 clean + 12 observed datasets")
end

main()
