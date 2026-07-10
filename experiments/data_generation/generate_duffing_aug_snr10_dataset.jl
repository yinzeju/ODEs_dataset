## Formal KDSM-MP Duffing augmented 10 dB dataset generation entry point

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

try
    @eval import Plots
catch err
    @warn "Plots.jl could not be loaded; time-series plots will be skipped" exception = err
end

include(joinpath(PROJECT_ROOT, "src", "generators", "duffing_aug_snr10_generator.jl"))

function run_duffing_aug_snr10_generation()
    return generate_duffing_aug_snr10_dataset(PROJECT_ROOT; profile = :formal)
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    metadata = run_duffing_aug_snr10_generation()
    metadata["diagnostics"]["passed"] || error("duffing_aug_snr10 generation failed diagnostics")
end
