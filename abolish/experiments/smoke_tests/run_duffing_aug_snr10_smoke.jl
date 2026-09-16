const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

try
    @eval import Plots
catch err
    @warn "Plots.jl could not be loaded; smoke plots will be skipped" exception = err
end

include(joinpath(PROJECT_ROOT, "src", "generators", "duffing_aug_snr10_generator.jl"))

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    metadata = generate_duffing_aug_snr10_dataset(PROJECT_ROOT; profile = :smoke)
    metadata["diagnostics"]["passed"] || error("duffing_aug_snr10 smoke generation failed")
end
