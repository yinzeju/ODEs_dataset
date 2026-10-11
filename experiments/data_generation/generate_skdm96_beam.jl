include(joinpath(@__DIR__,"..","..","src","data","skdm96_beam_extension.jl"))
length(ARGS)==2 || error("Usage: generate_skdm96_beam.jl design|formal NEW_OUTPUT")
ARGS[1] in ("design","formal") || error("Unknown generation stage")
SKDM96BeamExtension.generate(abspath(ARGS[2]);design=ARGS[1]=="design")
