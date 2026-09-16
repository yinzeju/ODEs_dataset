const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "data", "controlled_lowdim_v1_duffing_hf_generation.jl"))

function main()
    result = cldhf_run_bilinear_pilot(PROJECT_ROOT)
    selected_depth = result["selected_relative_stiffness_depth"]
    isnothing(selected_depth) && error("DUF-HF bilinear pilot did not select a candidate")

    println("controlled_lowdim_v1 DUF-HF bilinear pilot completed")
    println("  selected relative stiffness depth: ", selected_depth)
    println("  output: ", result["output_path"])
end

main()
