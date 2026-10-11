# Canonical Dataset2 API; retain the producing module identity for JLD2 compatibility.
if !isdefined(@__MODULE__, :TestSub2NV)
    include(joinpath(@__DIR__, "..", "testsub2_nv", "TestSub2NV.jl"))
end
const Dataset2NV = TestSub2NV
