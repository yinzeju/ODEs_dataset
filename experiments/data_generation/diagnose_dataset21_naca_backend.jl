# Focused real-mesh CPU/GPU parity and timing; never publishes a dataset.
"--execute" in ARGS || error("Explicit execution authorization required")
include(joinpath(@__DIR__, "..", "..", "src", "data", "dataset21_naca", "Dataset21NACA.jl"))
using .Dataset21NACA, LinearAlgebra, Random
const NACA = Dataset21NACA
Base.include(NACA, joinpath(@__DIR__, "..", "..", "src", "data", "dataset21_naca", "gpu.jl"))

function main()
    BLAS.set_num_threads(1)
    cfg=NACA.load_config(joinpath(NACA.ROOT,"configs/releases/dataset21_naca_v1_r4.json"))
    m=NACA.JLD2.load(joinpath(NACA.ROOT,"runs/dataset21_naca_zeta006_f4096_v1_r4/models/candidate.jld2"),"model")
    q,_=NACA.initial_state(m,11,0.0021,Xoshiro(9011),cfg)
    cpu=NACA.CPUBackend(m);gpu=NACA.GPUBackend(m)
    NACA.evaluate!(cpu,m,q);NACA.evaluate!(gpu,m,q)
    println("FORCE_RELATIVE ",norm(cpu.force-gpu.force)/norm(cpu.force))
    println("TANGENT_RELATIVE ",norm(cpu.tangent-gpu.tangent)/norm(cpu.tangent))
    println("CPU_FORCE_SECONDS ",@elapsed NACA.evaluate!(cpu,m,q;tangent=false))
    println("GPU_FORCE_SECONDS ",@elapsed NACA.evaluate!(gpu,m,q;tangent=false))
    println("CPU_TANGENT_SECONDS ",@elapsed NACA.evaluate!(cpu,m,q))
    println("GPU_TANGENT_SECONDS ",@elapsed NACA.evaluate!(gpu,m,q))
    flush(stdout)
    _,receipt=NACA.benchmark_gpu(m,q,cfg)
    println("BACKEND_RECEIPT ",NACA.JSON.json(receipt));flush(stdout)
    function rollout(strategy,count)
        solver=deepcopy(cfg["solver"]);solver["tangent_strategy"]=strategy
        h=cfg["sampling"]["dt_seconds"]/solver["substeps"]
        cache=strategy=="consistent_lu" ? nothing : NACA.NewmarkCache(m,h)
        position=copy(q);velocity=zeros(length(q))
        NACA.evaluate!(gpu,m,position;tangent=false)
        acceleration=-(m.M\(m.K*position+gpu.force));statistics=NACA.StepStatistics()
        elapsed=@elapsed for _ in 1:count
            position,velocity,acceleration,_=NACA.advance(m,gpu,position,velocity,acceleration,h,solver,statistics;cache)
        end
        return vcat(position,velocity),elapsed,statistics
    end
    reference,baseline,_=rollout("consistent_lu",32)
    scale=vcat(m.qscale,m.omega[1].*m.qscale)
    for strategy in ("consistent_cholesky","cached_linear_with_consistent_fallback")
        rollout(strategy,1)
        value,elapsed,statistics=rollout(strategy,32)
        relative=norm((reference-value)./scale)/norm(reference./scale)
        println("STRATEGY ",strategy," seconds=",elapsed," baseline=",baseline,
            " relative=",relative," chord_corrections=",statistics.chord_corrections,
            " consistent_factorizations=",statistics.consistent_factorizations,
            " residual=",statistics.max_residual)
        relative<=cfg["qualification"]["temporal_state_relative"]/10 || error("Optimized solver disagrees with consistent LU")
        flush(stdout)
    end
end
Base.invokelatest(main)
