const PROJECT_ROOT = abspath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "standard_odes_v1_generation.jl"))

manifest = generate_standard_odes_v1(:smoke)
println("dataset_id: ", manifest["dataset_id"])
println("profile: ", manifest["profile"])
println("all_passed: ", manifest["all_passed"])
println("release_manifest: ", manifest["generated_files"]["release_manifest"])
