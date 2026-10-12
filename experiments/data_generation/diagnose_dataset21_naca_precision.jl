# Full-duration time-refinement diagnosis only; never publishes a dataset.
"--execute" in ARGS || error("Explicit execution authorization required")
include(joinpath(@__DIR__, "..", "..", "src", "data", "dataset21_naca", "Dataset21NACA.jl"))
using .Dataset21NACA, LinearAlgebra, Random
const NACA=Dataset21NACA
Base.include(NACA,joinpath(@__DIR__,"..","..","src","data","dataset21_naca","gpu.jl"))

function main()
    BLAS.set_num_threads(1)
    index=findfirst(==("--config"),ARGS)
    index===nothing && error("A diagnostic config is required")
    cfg=NACA.load_config(joinpath(NACA.ROOT,ARGS[index+1]))
    diagnostic=cfg["diagnostic"]
    modelpath=joinpath(NACA.ROOT,diagnostic["model_path"])
    NACA.filehash(modelpath)==diagnostic["model_sha256"] || error("Diagnostic model binding changed")
    m=NACA.JLD2.load(modelpath,"model")
    q,_=NACA.initial_state(m,diagnostic["family"],diagnostic["amplitude_m"],Xoshiro(diagnostic["seed"]),cfg)
    output=joinpath(NACA.ROOT,"runs",cfg["release_id"])
    NACA.bind_inputs(output,cfg)
    backend=NACA.GPUBackend(m)
    cpu=NACA.CPUBackend(m);NACA.evaluate!(cpu,m,q;tangent=false)
    NACA.evaluate!(backend,m,view(reshape(q,:,1),:,1);tangent=false)
    device_error=norm(cpu.force-backend.force)/max(norm(cpu.force),eps())
    device_error<cfg["qualification"]["cpu_gpu_relative_tolerance"] || error("Stage-view CPU/GPU force parity")
    println("NACA_STAGE_VIEW_PARITY ",device_error);flush(stdout)
    steps,path,receipt,relative=NACA.qualify_time(joinpath(output,"time_pair"),m,q,cfg,backend)
    NACA.writejson(joinpath(output,"diagnosis.json"),Dict("status"=>"single_case_time_pair_passed",
        "steps"=>steps,"relative"=>relative,"receipt"=>receipt,"path"=>path,
        "scope"=>"Independent full-duration Newton-precision diagnosis; not complete campaign qualification"))
    println("NACA_PRECISION_PAIR_PASSED relative=",relative," energy=",receipt["max_energy_balance_relative"])
end
Base.invokelatest(main)
