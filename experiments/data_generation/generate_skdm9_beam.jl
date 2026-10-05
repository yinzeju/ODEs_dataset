# The capsule supervisor sets SKDM9_DATASET_PROJECT_ROOT explicitly.
using SHA, Dates
include(joinpath(@__DIR__,"..","..","src","data","skdm9_beam_extension.jl"))
using .SKDM9BeamExtension
function main()
    length(ARGS)==1 || error("Usage: generate_skdm9_beam.jl ABSOLUTE_NEW_OUTPUT_DIRECTORY")
    output = abspath(ARGS[1])
    try
        SKDM9BeamExtension.generate(output)
    catch error
        mkpath(output)
        SKDM9BeamExtension.BaseNV.write_json(joinpath(output,"failure_$(Dates.format(now(UTC),"yyyymmddTHHMMSS")).json"),
            Dict("error"=>sprint(showerror,error,catch_backtrace()),"failed_utc"=>string(now(UTC))))
        rethrow()
    end
end
main()
