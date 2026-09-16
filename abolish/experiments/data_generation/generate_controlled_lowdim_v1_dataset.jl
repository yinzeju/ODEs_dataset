const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(PROJECT_ROOT, "src", "data", "controlled_lowdim_v1_generation.jl"))

function main()
    manifest = generate_controlled_lowdim_v1(PROJECT_ROOT; profile = :formal)
    manifest["all_passed"] || error("controlled_lowdim_v1 formal validation failed")
    println("controlled_lowdim_v1 formal release passed: 12 clean + 12 observed datasets")
    println("release manifest: ", manifest["release_manifest_path"])
end

main()
