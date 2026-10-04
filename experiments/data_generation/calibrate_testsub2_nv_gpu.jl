using LinearAlgebra, JLD2
import JSON
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_exponential.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_modal.jl"))

function main()
    BLAS.set_num_threads(1)
    root=normpath(joinpath(@__DIR__,"..",".."));id="shell_nr"
    cfg=JSON.parsefile(joinpath(root,"configs","releases","testsub2_nv_20261004.json"))
    m=load(joinpath(root,"runs","testsub2_nv","models",id*".jld2"),"model")
    folder=joinpath(root,"runs","testsub2_nv","gpu_qualification")
    fine=load(joinpath(folder,id*"_modal_base.jld2"),"base")
    expected=cfg["gpu_fine"]
    all(fine.diagnostics[1][key]==expected[key] for key in ("reltol","abstol")) || error("Cached reference tolerance mismatch")
    fine.diagnostics[1]["max_step_over_reference_period"]==expected["max_step_fraction"] || error("Cached reference step mismatch")
    ics=TestSub2NV.initial_conditions(m;resource="QUAL");q=hcat([ic.q for ic in ics]...)
    settings=cfg["gpu_baseline"]
    println("GPU_PROFILE_CALIBRATION_START; independent QUAL only");flush(stdout)
    base=GPUModal.integrate(m,q;reltol=settings["reltol"],abstol=settings["abstol"],
        max_step_fraction=settings["max_step_fraction"],label="QUAL:calibration")
    results=[Dict("trajectory_id"=>ic.id,"scaled_state_error"=>TestSub2NV.compare_trajectories(m,
        (x=view(base.x,:,:,i),),(x=view(fine.x,:,:,i),)),"baseline"=>base.diagnostics[i],"fine"=>fine.diagnostics[i])
        for (i,ic) in enumerate(ics)]
    for r in results
        r["passed"]=r["scaled_state_error"]<=1e-7 && max(r["baseline"]["energy_balance_relative"],r["fine"]["energy_balance_relative"])<=1e-7
    end
    record=Dict("results"=>results,"profile"=>"gpu_baseline / gpu_fine",
        "selection_population"=>"independent QUAL, no canonical data",
        "cached_fine_sha256"=>TestSub2NV.file_sha(joinpath(folder,id*"_modal_base.jld2")),
        "modal_source_sha256"=>TestSub2NV.file_sha(joinpath(root,"src","data","testsub2_nv","gpu_modal.jl")))
    TestSub2NV.write_json(joinpath(folder,"gpu_profile_calibration.json"),record)
    jldopen(joinpath(folder,"gpu_profile_calibration.jld2"),"w") do f;f["base"]=base;f["fine"]=fine;end
    println("GPU_PROFILE_CALIBRATION_RESULT ",results);flush(stdout)
    all(r["passed"] for r in results) || error("GPU integration profile did not qualify")
end
main()
