# Use the published CPU source capsule's Julia environment.
include(joinpath(@__DIR__,"..","..","src","data","skdm9_beam_extension.jl"))
using .SKDM9BeamExtension
using Dates
function main()
    output = joinpath(@__DIR__,"..","..","runs","smoke_tests","skdm9_beam_extension",Dates.format(now(UTC),"yyyymmddTHHMMSS"))
    result = SKDM9BeamExtension.generate(normpath(output);smoke=true)
    result["trajectories"]==1 || error("Smoke population count")
    result["maximum_scaled_state_error"]<=1e-7 || error("State qualification failed")
    result["maximum_energy_error"]<=1e-7 || error("Energy qualification failed")
end
main()
