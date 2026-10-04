using LinearAlgebra, JLD2
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_exponential.jl"))

function main()
    BLAS.set_num_threads(1)
    root=normpath(joinpath(@__DIR__,"..",".."))
    id=isempty(ARGS) ? "shell_nr" : ARGS[1]
    substeps=length(ARGS)>1 ? parse(Int,ARGS[2]) : 8
    m=load(joinpath(root,"runs","testsub2_nv","models",id*".jld2"),"model")
    parity=GPUExponential.force_parity(m)
    println("GPU_FORCE_PARITY ",parity);flush(stdout)
    ics=TestSub2NV.initial_conditions(m;resource="QUAL")
    q=hcat([ic.q for ic in ics]...)
    println("GPU_FULL_QUALIFICATION_START ",id," substeps=",substeps," batch=",length(ics));flush(stdout)
    base=GPUExponential.integrate(m,q;substeps=substeps,label="QUAL:base")
    fine=GPUExponential.integrate(m,q;substeps=2substeps,label="QUAL:fine")
    scale=vcat(m.qscale,m.omega[m.reference_mode].*m.qscale)
    results=Any[]
    for i in eachindex(ics)
        error=maximum(norm((base.x[:,k,i]-fine.x[:,k,i])./scale)/
            max(1.,norm(fine.x[:,k,i]./scale)) for k in axes(base.x,2))
        push!(results,Dict("trajectory_id"=>ics[i].id,"scaled_state_error"=>error,
            "baseline"=>base.diagnostics[i],"fine"=>fine.diagnostics[i],
            "passed"=>error<=1e-7 && max(base.diagnostics[i]["energy_balance_relative"],fine.diagnostics[i]["energy_balance_relative"])<=1e-7))
    end
    path=joinpath(root,"runs","testsub2_nv","gpu_qualification",id*"_$(substeps).json")
    TestSub2NV.write_json(path,Dict("force_parity"=>parity,"results"=>results))
    jldopen(replace(path,".json"=>".jld2"),"w") do f;f["base"]=base;f["fine"]=fine;end
    println("GPU_QUALIFICATION_RESULT ",results);flush(stdout)
end
main()
