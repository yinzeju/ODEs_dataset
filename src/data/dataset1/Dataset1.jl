# Canonical Dataset1 API; existing frozen artifacts retain their producer identity.
if !isdefined(@__MODULE__, :StandardODEsV2)
    include(joinpath(@__DIR__, "..", "standard_odes_v2", "StandardODEsV2.jl"))
end
const Dataset1 = StandardODEsV2
