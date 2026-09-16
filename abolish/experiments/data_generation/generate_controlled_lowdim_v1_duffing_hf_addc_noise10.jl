const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(
    PROJECT_ROOT,
    "src",
    "data",
    "controlled_lowdim_v1_duffing_hf_noise_generation.jl",
))

function main()
    metadata =
        generate_controlled_lowdim_v1_duffing_hf_addc_noise10(PROJECT_ROOT)
    metadata["passed"] || error(
        "DUF-HF-ADD 10 dB observation-noise generation failed validation.",
    )
end

main()
