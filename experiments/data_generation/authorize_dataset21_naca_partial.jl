# Bind the explicit user-requested partial-qualification release before generation.
include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
using .Dataset21NACA
function main()
    cfg=load_config(joinpath(Dataset21NACA.ROOT,"configs","releases","dataset21_naca_v3_partial.json"))
    folder=joinpath(Dataset21NACA.ROOT,"runs",cfg["release_id"])
    Dataset21NACA.bind_inputs(folder,cfg)
    path=joinpath(folder,"qualification","partial_authorization.json")
    q=Dataset21NACA.JSON.parsefile(path)
    q["inputs_sha256"]=Dataset21NACA.filehash(joinpath(folder,"input_fingerprint.json"))
    Dataset21NACA.writejson(path,q)
    Dataset21NACA.accepted_qualification(folder,cfg)
    # Check the retained full trajectories once before publication of this lineage.
    parent=joinpath(Dataset21NACA.ROOT,"runs",q["parent_release"],"qualification")
    for case in ("case_1","case_2"),name in readdir(joinpath(parent,case))
        endswith(name,".h5.json") || continue
        receipt=Dataset21NACA.JSON.parsefile(joinpath(parent,case,name))
        trajectory=joinpath(parent,case,name[1:end-5])
        Dataset21NACA.filehash(trajectory)==receipt["sha256"] || error("Retained trajectory changed")
    end
    println("NACA_PARTIAL_AUTHORIZATION_BOUND retained_cases=2 substeps=2 status=user_authorized_partial")
end
main()
