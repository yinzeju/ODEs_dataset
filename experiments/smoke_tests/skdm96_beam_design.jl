# Independent physical-design qualification; no learning or Test population.
using LinearAlgebra, SparseArrays, SHA
import JSON
include(joinpath(@__DIR__, "..", "..", "src", "data", "skdm9_beam_extension.jl"))
const B96 = SKDM9BeamExtension.BaseNV

function design_model(damping_factor)
    m = B96.beam_model(; elements=12)
    metadata = merge(copy(m.metadata), Dict{String,Any}(
        "damping_factor_relative_to_original" => damping_factor,
        "damping" => "C=damping_factor*(1e6/E)*K"))
    B96.MechanicalModel(m.id, "FE12_SKDM96_DESIGN", m.n, m.M,
        damping_factor*m.C, m.K, m.kernel, m.omega, m.modes, m.qscale,
        m.reference_mode, m.probe, m.translations, m.active, m.nodes, m.mesh, metadata)
end

function mixed_initial(m, amplitude, fraction)
    q = B96.static_release(m, amplitude)[1]
    transverse = 2:3:m.n
    mode = m.modes[:, 2]
    q .+= (fraction*amplitude/maximum(abs, mode[transverse])) .* mode
    q
end

function diagnostics(m, x)
    modal_q = transpose(m.modes)*m.M*x[1:m.n, :]
    modal_v = transpose(m.modes)*m.M*x[m.n+1:2m.n, :]
    modal_energy = (modal_v.^2 .+ (m.omega .* modal_q).^2)./2
    force = zeros(m.n)
    exposure = [begin
        q = view(x, 1:m.n, j)
        B96.nonlinear!(force, m.kernel, q)
        norm(force ./ m.qscale)/max(norm((m.K*q)./m.qscale), eps())
    end for j in axes(x, 2)]
    blocks = [begin
        span = (start+1):(start+512)
        energies = vec(sum(modal_energy[:, span]; dims=2))
        Dict("first_step"=>start, "last_step"=>start+511,
             "mode2_energy_fraction"=>energies[2]/sum(energies),
             "mode1_energy_fraction"=>energies[1]/sum(energies),
             "other_energy_fraction"=>sum(energies[3:end])/sum(energies),
             "nonlinear_force_ratio_median"=>sort(exposure[span])[256],
             "nonlinear_force_ratio_max"=>maximum(exposure[span]))
    end for start in 0:512:3584]
    Dict("blocks"=>blocks, "initial_nonlinear_force_ratio"=>exposure[1],
         "linear_modal_energy_interpretation"=>"Diagnostic coordinates only; nonlinear SSM distance is not established")
end

function main()
    length(ARGS)==1 || error("Usage: skdm96_beam_design.jl NEW_OUTPUT")
    output = abspath(ARGS[1])
    ispath(output) && error("Design output must be new")
    mkpath(output)
    BLAS.set_num_threads(1)
    cfg = SKDM9BeamExtension.configuration()
    cfg["periods"] = 16
    results = Any[]
    for (i, (damping, amplitude)) in enumerate([(1.0, .006), (1.0, .010), (.5, .006), (.5, .010)])
        m = design_model(damping)
        q = mixed_initial(m, amplitude, .25)
        ic = (split="design", id="design_$(i)", q=q,
              meta=Dict{String,Any}("amplitude_m"=>amplitude, "mode2_fraction"=>.25,
                  "damping_factor"=>damping, "initial_velocity"=>"zero"))
        binding = bytes2hex(sha256(read(@__FILE__)))
        cert = B96.solve_certified(m, ic, cfg, output, binding)
        x = B96.jldopen(joinpath(output, cert["state_path"]), "r") do f; f["x"]; end
        row = merge(Dict("case"=>i, "settings"=>ic.meta, "certificate"=>cert), diagnostics(m, x))
        push!(results, row)
        B96.write_json(joinpath(output, "design_results.json"), Dict("cases"=>results,
            "status"=>"physical_design_only_not_formal_dataset", "source_sha256"=>binding))
        println("DESIGN_CASE_COMPLETE ", JSON.json(row)); flush(stdout)
    end
end
main()
