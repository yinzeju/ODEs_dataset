module SKDM96BeamExtension
using LinearAlgebra, SHA, Dates
import JSON
include("skdm9_beam_extension.jl")
const Parent = SKDM9BeamExtension
const B = Parent.BaseNV

function model()
    m = B.beam_model(;elements=12)
    metadata = merge(copy(m.metadata), Dict{String,Any}(
        "damping"=>"C=0.75*(1e6/E)*K", "damping_factor"=>0.75,
        "material_damping_modulus_Pa_s"=>750000.))
    B.MechanicalModel(m.id,"FE12_SKDM96",m.n,m.M,0.75m.C,m.K,m.kernel,m.omega,
        m.modes,m.qscale,m.reference_mode,m.probe,m.translations,m.active,m.nodes,m.mesh,metadata)
end

function configuration()
    cfg = Parent.configuration()
    merge!(cfg,Dict{String,Any}("extension_id"=>"skdm96_beam_transient_h2048_v1",
        "configuration_id"=>"FE12_SKDM96", "periods"=>16,
        "amplitude_interval_m"=>[.006,.010], "damping_factor"=>.75,
        "mode2_transverse_amplitude_fraction"=>.25,
        "initial_condition_family"=>"nonlinear static midpoint release plus signed second bending eigenmode; zero velocities",
        "split_rule"=>"144 amplitude grid; offsets0,1,4,5 Train,2 Validation,3 Test in each six-point stratum; mode2 sign alternates between strata",
        "resource_rationale"=>"96/24/24 mothers,4096 steps plus initial state,2049 complete H2048 anchors; uniform window mass",
        "mechanics_and_integrator"=>"Published full66-state nonlinear FE12 kernel and Float64 Rodas5P/UMFPACK; damping and initial conditions explicitly changed",
        "transient_gate"=>Dict("diagnostic"=>"512-frame-block linear modal energy; not nonlinear SSM distance",
            "initial_mode2_fraction_min"=>.20,"pre_half_mode2_fraction_min"=>.04,
            "first_rear_block_mode1_fraction_min"=>.90,"last_block_mode1_fraction_min"=>.985,
            "first_block_below_five_percent_mode2_allowed_start"=>[1536,3072]),
        "ssm_policy"=>"Train-only rear-half fit after transient diagnostics; independent geometry/flow checks remain mandatory"))
    cfg
end

function initial(m, amplitude, sign)
    q, load, residual = B.static_release(m,amplitude)
    phi = m.modes[:,2]
    q .+= (sign*.25amplitude/maximum(abs,phi[2:3:m.n])).*phi
    q, Dict{String,Any}("static_midpoint_amplitude_m"=>amplitude,"mode2_sign"=>sign,
        "mode2_fraction"=>.25,"static_point_load_N"=>load,"static_relative_residual"=>residual,
        "initial_velocity"=>"zero","static_residual_applies_before_modal_perturbation"=>true)
end

function response_diagnostics(m,x)
    mq = transpose(m.modes)*m.M*x[1:m.n,:]
    mv = transpose(m.modes)*m.M*x[m.n+1:2m.n,:]
    E = (mv.^2 .+ (m.omega.*mq).^2)./2
    force = zeros(m.n)
    nonlinear_ratio = zeros(size(x,2)); geometric_ratio=similar(nonlinear_ratio)
    max_slope=0.
    for j in axes(x,2)
        q = view(x,1:m.n,j)
        B.nonlinear!(force,m.kernel,q)
        restoring=m.K*q
        transverse=2:3:m.n
        nonlinear_ratio[j]=norm(force[transverse])/max(norm(restoring[transverse]),eps())
        quartic=0.
        for p in m.kernel
            slope=B.localdot(p.slope,p.index,q)
            max_slope=max(max_slope,abs(slope))
            quartic+=p.weightEA*slope^4/8
        end
        geometric_ratio[j]=quartic/max(dot(q,m.K*q)/2,eps())
    end
    blocks=[begin
        ids=(start+1):(start+512); e=vec(sum(E[:,ids];dims=2)); total=sum(e)
        Dict("start_step"=>start,"end_step"=>start+511,"mode1_fraction"=>e[1]/total,
            "mode2_fraction"=>e[2]/total,"other_fraction"=>sum(e[3:end])/total,
            "transverse_nonlinear_force_ratio_median"=>sort(nonlinear_ratio[ids])[256],
            "quartic_geometric_over_linear_energy_median"=>sort(geometric_ratio[ids])[256])
    end for start in 0:512:3584]
    crossing=findfirst(b->b["mode2_fraction"]<.05,blocks)
    crossing_step=isnothing(crossing) ? -1 : blocks[crossing]["start_step"]
    passed=blocks[1]["mode2_fraction"]>=.20 && blocks[4]["mode2_fraction"]>=.04 &&
        blocks[5]["mode1_fraction"]>=.90 && blocks[end]["mode1_fraction"]>=.985 &&
        1536<=crossing_step<=3072
    Dict("blocks"=>blocks,"first_block_mode2_below_005_start"=>crossing_step,
        "maximum_absolute_slope"=>max_slope,"passed_transient_design"=>passed,
        "boundary"=>"Linear modal energy is a diagnostic, not proof of a nonlinear SSM or constant steady state")
end

function generate(output;design=false)
    ispath(output) && error("New generation attempt requires a new output directory")
    mkpath(output); BLAS.set_num_threads(1)
    cfg=configuration(); m=model()
    binding=bytes2hex(sha256(Parent.BASE_BINDING*JSON.json(cfg)*Parent.file_sha(@__FILE__)))
    B.write_json(joinpath(output,"generation_config.json"),Dict("binding"=>binding,"config"=>cfg))
    B.write_json(joinpath(output,"mechanics.json"),Dict("metadata"=>m.metadata,"checks"=>B.mechanical_checks(m),
        "active_dof_indices"=>m.active,"omega"=>m.omega,"dt"=>(2pi/m.omega[1])/256))
    population=NamedTuple[]; counts=Dict("train"=>0,"val"=>0,"test"=>0)
    if design
        for (i,(a,s)) in enumerate([(.006,1),(.010,-1)])
            q,meta=initial(m,a,s);push!(population,(split="design",id="SKDM96_design_$i",q=q,meta=meta))
        end
    else
        for (i,a) in enumerate(range(.006,.010;length=144))
            offset=mod(i-1,6); split=offset==2 ? "val" : offset==3 ? "test" : "train"
            counts[split]+=1; sign=isodd(cld(i,6)) ? 1 : -1
            q,meta=initial(m,a,sign);meta["grid_index"]=i
            push!(population,(split=split,id="SKDM96_$(split)_$(lpad(counts[split],3,'0'))",q=q,meta=meta))
        end
    end
    B.write_json(joinpath(output,"population.json"),[Dict("id"=>p.id,"split"=>p.split,"metadata"=>p.meta) for p in population])
    certificates=Any[]; checks=Any[]; started=time()
    for (i,ic) in enumerate(population)
        cert=B.solve_certified(m,ic,cfg,output,binding);push!(certificates,cert)
        x=B.jldopen(joinpath(output,cert["state_path"]),"r") do f;f["x"];end
        diag=response_diagnostics(m,x);diag["id"]=ic.id;push!(checks,diag)
        B.write_json(joinpath(output,"transient_checks.json"),checks)
        diag["passed_transient_design"] || error("Transient design gate failed for $(ic.id); retain evidence, no learner manifest")
        B.write_json(joinpath(output,"progress.json"),Dict("completed"=>i,"total"=>length(population),
            "trajectory"=>ic.id,"elapsed_seconds"=>time()-started,"updated_utc"=>string(now(UTC))))
    end
    entries=[Dict("trajectory_id"=>c["trajectory_id"],"split"=>c["split"],"path"=>c["state_path"],"sha256"=>c["state_sha256"]) for c in certificates]
    learner=Dict("schema"=>"skdm96.beam_extension.v1","object_id"=>m.id,"configuration_id"=>m.configuration,
        "state_dimension"=>66,"snapshot_count"=>4097,"dt_output"=>(2pi/m.omega[1])/256,
        "reference_period"=>2pi/m.omega[1],"state_layout"=>"col(all q, all v), original active nodal order",
        "active_dof_indices"=>m.active,"trajectories"=>entries,"binding"=>binding,
        "full_source_binding"=>Parent.BASE_BINDING,"design_only"=>design)
    B.write_json(joinpath(output,"learner_manifest.json"),learner)
    complete=Dict("status"=>"passed_numerics_and_transient_design","design_only"=>design,
        "trajectories"=>length(entries),"manifest_sha256"=>Parent.file_sha(joinpath(output,"learner_manifest.json")),
        "maximum_scaled_state_error"=>maximum(c["scaled_state_error"] for c in certificates),
        "maximum_energy_error"=>maximum(max(c["baseline"]["energy_balance_relative"],c["fine"]["energy_balance_relative"]) for c in certificates),
        "elapsed_seconds"=>time()-started,"binding"=>binding,"completed_utc"=>string(now(UTC)))
    B.write_json(joinpath(output,"complete.json"),complete)
    println("SKDM96_DATA_COMPLETE ",JSON.json(complete));flush(stdout)
end
end
