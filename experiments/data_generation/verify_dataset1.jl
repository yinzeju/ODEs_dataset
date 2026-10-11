include(joinpath(@__DIR__, "..", "..", "src", "data", "dataset1", "Dataset1.jl"))
using JSON

function main()
    config = JSON.parsefile(joinpath(Dataset1.ROOT, "configs", "releases", "standard_odes_v2.json"))
    folder = isempty(ARGS) ? joinpath(Dataset1.ROOT, "data", "releases", config["release_id"]) : abspath(ARGS[1])
    println(JSON.json(Dataset1.verify_release(folder; write_result=false)))
end

main()
