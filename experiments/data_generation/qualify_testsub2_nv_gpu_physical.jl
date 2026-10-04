using LinearAlgebra, JLD2
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_exponential.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_physical.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_modal.jl"))

function main()
    BLAS.set_num_threads(1)
    root=normpath(joinpath(@__DIR__,"..",".."));id=isempty(ARGS) ? "shell_nr" : ARGS[1]
    m=load(joinpath(root,"runs","testsub2_nv","models",id*".jld2"),"model")
    ics=TestSub2NV.initial_conditions(m;resource="QUAL");q=hcat([ic.q for ic in ics]...)
    coordinates=length(ARGS)>1 ? ARGS[2] : "physical"
    solver=coordinates=="modal" ? GPUModal.integrate : GPUPhysical.integrate
    path=joinpath(root,"runs","testsub2_nv","gpu_qualification",id*"_"*coordinates*".json")
    mkpath(dirname(path))
    println("GPU_ADAPTIVE_QUALIFICATION_START ",id," coordinates=",coordinates," batch=",length(ics));flush(stdout)
    base=solver(m,q;label="QUAL:base")
    jldopen(replace(path,".json"=>"_base.jld2"),"w") do f;f["base"]=base;end
    println("GPU_BASE_DONE ",base.diagnostics);flush(stdout)
    fine=solver(m,q;reltol=2e-12,abstol=2e-14,max_step_fraction=1/512,label="QUAL:fine")
    results=[Dict("trajectory_id"=>ic.id,"scaled_state_error"=>TestSub2NV.compare_trajectories(m,
        (x=view(base.x,:,:,i),),(x=view(fine.x,:,:,i),)),"baseline"=>base.diagnostics[i],"fine"=>fine.diagnostics[i])
        for (i,ic) in enumerate(ics)]
    for r in results
        r["passed"]=r["scaled_state_error"]<=1e-7 && max(r["baseline"]["energy_balance_relative"],r["fine"]["energy_balance_relative"])<=1e-7
    end
    TestSub2NV.write_json(path,Dict("results"=>results))
    jldopen(replace(path,".json"=>".jld2"),"w") do f;f["base"]=base;f["fine"]=fine;end
    println("GPU_PHYSICAL_QUALIFICATION_RESULT ",results);flush(stdout)
end
main()
