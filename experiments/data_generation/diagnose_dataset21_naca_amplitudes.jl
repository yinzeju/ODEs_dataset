# Initial-state elastic-domain diagnostics; no trajectory population is generated.
"--execute" in ARGS || error("Explicit execution authorization required")
include(joinpath(@__DIR__, "..", "..", "src", "data", "dataset21_naca", "Dataset21NACA.jl"))
using .Dataset21NACA, LinearAlgebra, Random
const NACA=Dataset21NACA
function main()
    BLAS.set_num_threads(1)
    cfg=NACA.load_config(joinpath(NACA.ROOT,"configs/releases/dataset21_naca_v1_r5.json"))
    sources=["runs/dataset21_naca_zeta006_f4096_v1_r5/models/candidate.jld2",
        "runs/naca_campaign_control/mesh_search_03/almost_uniform_33/model.jld2"]
    rows=Any[]
    for path in sources
        m=NACA.JLD2.load(joinpath(NACA.ROOT,path),"model")
        factor=cholesky(Symmetric(m.K));backend=NACA.CPUBackend(m)
        for amplitude in cfg["initial_conditions"]["amplitude_candidates_m"],family in 1:12
            q,_=NACA.initial_state(m,family,amplitude,Xoshiro(9000+family),cfg)
            diagnostic=NACA.evaluate!(backend,m,q;tangent=false)
            correction=factor\backend.force
            row=Dict("model"=>path,"model_sha256"=>NACA.filehash(joinpath(NACA.ROOT,path)),
                "family"=>family,"amplitude_m"=>amplitude,"strain"=>diagnostic.strain,
                "nonlinear_energy_fraction"=>diagnostic.energy/(dot(q,m.K*q)/2),
                "linear_compliance_nonlinear_correction_relative"=>norm(correction./m.qscale)/norm(q./m.qscale))
            push!(rows,row)
        end
        println("NACA_AMPLITUDE_DIAG completed ",path);flush(stdout)
        NACA.writejson(joinpath(NACA.ROOT,"runs/naca_campaign_control/amplitude_diagnosis.json"),rows)
    end
end
main()
