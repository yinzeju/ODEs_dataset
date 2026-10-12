# Focused failure diagnosis; never creates a formal release.
"--execute" in ARGS || error("Explicit execution authorization required")
include(joinpath(@__DIR__, "..", "..", "src", "data", "dataset21_naca", "Dataset21NACA.jl"))
using .Dataset21NACA, LinearAlgebra, Random
const NACA = Dataset21NACA

function main()
    BLAS.set_num_threads(1)
    cfg = NACA.load_config(joinpath(NACA.ROOT, "configs/releases/dataset21_naca_v1_r2.json"))
    folder = joinpath(NACA.ROOT, "runs/dataset21_naca_zeta006_f4096_v1_r2")
    m = NACA.JLD2.load(joinpath(folder, "models/candidate.jld2"), "model")
    qref, _ = NACA.initial_state(m, 11, 0.0021, Xoshiro(9011), cfg)
    println("DERIVATIVES ", NACA.derivative_checks(m, qref, cfg)); flush(stdout)
    f = NACA.preload(m)
    qlinear = m.K \ f
    load = 0.001 / NACA.amplitude(m, qlinear)
    q = qlinear * load
    backend = NACA.CPUBackend(m)
    for iteration in 1:20
        NACA.evaluate!(backend, m, q)
        residual = m.K * q + backend.force - load * f
        step = (m.K + backend.tangent) \ residual
        cancellation_bound = norm(abs.(m.K) * abs.(q))
        println("STATIC iteration=", iteration, " residual=", norm(residual),
            " load_norm=", norm(load*f), " correction=", norm(step),
            " roundoff_scale=", eps()*cancellation_bound)
        accepted = false
        for weight in (1., 0.5, 0.25, 0.125, 0.0625)
            trial = q - weight * step
            NACA.evaluate!(backend, m, trial; tangent=false)
            trialnorm = norm(m.K * trial + backend.force - load * f)
            println("  weight=", weight, " residual=", trialnorm)
            if trialnorm < norm(residual)
                q = trial; accepted = true; break
            end
        end
        flush(stdout)
        accepted || break
    end
end
main()
