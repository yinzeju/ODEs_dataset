include(joinpath(@__DIR__, "..", "..", "src", "data", "standard_odes_v2", "StandardODEsV2.jl"))
using .StandardODEsV2
include(joinpath(@__DIR__, "..", "..", "test", "unit", "test_standard_odes_v2.jl"))
StandardODEsV2.generate(:smoke)
