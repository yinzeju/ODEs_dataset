# Linear mesh diagnostics only; this script cannot publish a qualified dataset.
"--execute" in ARGS || error("Explicit execution authorization required")
include(joinpath(@__DIR__, "..", "..", "src", "data", "dataset21_naca", "Dataset21NACA.jl"))
using .Dataset21NACA, LinearAlgebra
const NACA=Dataset21NACA

function main()
    BLAS.set_num_threads(1)
    option=findfirst(==("--config"),ARGS)
    planpath=option===nothing ? "configs/diagnostics/dataset21_naca_mesh_search.json" : ARGS[option+1]
    plan=NACA.JSON.parsefile(joinpath(NACA.ROOT,planpath))
    cfg=NACA.load_config(joinpath(NACA.ROOT,plan["base_config"]))
    reference=NACA.JSON.parsefile(joinpath(NACA.ROOT,plan["reference_models"]))["fine2"]["omega_rad_s"][1:4]
    gmsh=joinpath(NACA.ROOT,"data/cache/naca_tools/gmsh-4.14.1-Windows64/gmsh.exe")
    output=joinpath(NACA.ROOT,plan["output"]);mkpath(output)
    NACA.writejson(joinpath(output,"plan.json"),plan)
    rows=Any[]
    for p in plan["candidates"]
        id=get(p,"id","La$(p["La"])_a1$(p["a1"])_a2$(p["a2"])")
        folder=joinpath(output,id);path=joinpath(folder,"model.jld2")
        model=if isfile(path)
            NACA.JLD2.load(path,"model")
        else
            mesh=NACA.generate_mesh(folder,p,gmsh)
            states=12(size(mesh.nodes,1)-length(mesh.fixed_nodes))
            if states>get(plan,"maximum_candidate_state_dimension",typemax(Int))
                row=Dict("id"=>id,"parameters"=>p,"state_dimension"=>states,"status"=>"over_dimension_cap")
                push!(rows,row);NACA.writejson(joinpath(output,"results.json"),rows)
                println("MESH_DIAG ",NACA.JSON.json(row));flush(stdout)
                continue
            end
            m=NACA.assemble(mesh,cfg);NACA.JLD2.jldsave(path;model=m);m
        end
        relative=model.omega[1:4]./reference.-1
        row=Dict("id"=>id,"parameters"=>p,"state_dimension"=>2length(model.active),
            "omega"=>model.omega[1:4],"frequency_relative"=>relative,"model_sha256"=>NACA.filehash(path))
        push!(rows,row);NACA.writejson(joinpath(output,"results.json"),rows)
        println("MESH_DIAG ",NACA.JSON.json(row));flush(stdout)
    end
end
main()
