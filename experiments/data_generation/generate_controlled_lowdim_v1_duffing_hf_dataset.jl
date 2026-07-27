const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "controlled_lowdim_v1_duffing_hf_generation.jl"))

function main()
    result = generate_controlled_lowdim_v1_duffing_hf(PROJECT_ROOT)
    result["all_passed"] || error("DUF-HF formal generation did not pass validation")
    length(result["objects"]) == 3 || error("DUF-HF formal generation did not produce three control-role objects")

    println("controlled_lowdim_v1 DUF-HF formal generation completed")
    println("  manifest: ", result["manifest_path"])
end

main()
