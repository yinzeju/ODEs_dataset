# Targeted initialization and contract checks; no time integration or qualification.
using LinearAlgebra
BLAS.set_num_threads(1)
include(joinpath(@__DIR__,"../../src/data/dataset21_naca/Dataset21NACA.jl"))
include(joinpath(@__DIR__,"../../src/data/dataset21_nlc6/Dataset21NLC6.jl"))
Base.include(Dataset21NLC6,joinpath(Dataset21NACA.ROOT,"src/data/dataset21_nlc6/campaign.jl"))

function main()
    NC=Dataset21NACA;NLC=Dataset21NLC6
    cfg=NC.JSON.parsefile(joinpath(NC.ROOT,"configs/releases/dataset21_nlc6_v1_r3.json"))
    m=NLC.with_damping(NC.JLD2.load(joinpath(NC.ROOT,cfg["base_model_path"]),"model"),cfg)
    p=NLC.build_connectors(m,cfg);rows=NLC.planned_population(cfg)
    NLC.validate_numerical_overrides(cfg,rows)
    results=Any[]
    for row in rows
        row["family"]==12 || haskey(cfg["case_solver_overrides"],row["id"]) || continue
        println("INITIALIZATION_CHECK ",row["id"]);flush(stdout)
        started=time_ns();q,details=NLC.campaign_initial_condition(m,p,row,cfg)
        hash=NLC.verify_initial_state_binding(cfg,row["id"],q)
        geo=NC.evaluate!(NC.CPUBackend(m),m,q;tangent=false)
        ratio=sum(p.kappa.*(transpose(p.B)*q).^4)/4/(dot(q,m.K*q)/2)
        geo.strain<=cfg["solver_proposal"]["maximum_strain_component"] || error("Initial strain")
        isapprox(ratio,row["connector_energy_ratio"];rtol=1e-7) || error("Initial ratio")
        push!(results,merge(Dict("id"=>row["id"],"initial_state_sha256"=>hash,
            "strain"=>geo.strain,"actual_ratio"=>ratio,"target_ratio"=>row["connector_energy_ratio"],
            "amplitude_m"=>NC.amplitude(m,q),"wall_seconds"=>(time_ns()-started)/1e9),details))
        NC.writejson(joinpath(NC.ROOT,"runs/naca_campaign_control/r3_initialization_checks.json"),
            Dict("status"=>length(results)==17 ? "passed" : "in_progress","checks"=>results,
                "integration_performed"=>false,"qualification_performed"=>false,
                "campaign_source_sha256"=>NC.filehash(joinpath(NC.ROOT,"src/data/dataset21_nlc6/campaign.jl"))))
        println("INITIALIZATION_PASSED ",row["id"]," strain=",geo.strain," ratio=",ratio);flush(stdout)
    end
end
Base.invokelatest(main)
