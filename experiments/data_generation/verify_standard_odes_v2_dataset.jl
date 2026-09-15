include(joinpath(@__DIR__, "..", "..", "src", "data", "standard_odes_v2", "StandardODEsV2.jl"))
using JSON
cfg=JSON.parsefile(joinpath(StandardODEsV2.ROOT,"configs","releases","standard_odes_v2.json"))
out=isempty(ARGS) ? joinpath(StandardODEsV2.ROOT,"data","releases",cfg["release_id"]) : abspath(ARGS[1])
println(JSON.json(StandardODEsV2.verify_release(out)))
