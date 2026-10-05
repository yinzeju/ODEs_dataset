module SKDM9BeamExtension

using SHA, Dates, LinearAlgebra
import JSON

const ROOT = abspath(get(ENV,"SKDM9_DATASET_PROJECT_ROOT",normpath(joinpath(@__DIR__,"..",".."))))
const BASE_BINDING = "add4a54bd864922b9c3c7cc3374ffe9ca6611d74bed638e54061fc1244938ba8"
const BASE_SOURCE = joinpath(ROOT,"data","releases","testsub2_nv_20261004","TestSub2",
    "audit_only","source_snapshots",BASE_BINDING)
file_sha(path) = bytes2hex(sha256(read(path)))

function verify_base_source()
    manifest = JSON.parsefile(joinpath(BASE_SOURCE,"snapshot_manifest.json"))
    manifest["binding"]==BASE_BINDING || error("Unexpected base source identity")
    for (_,entry) in manifest["files"]
        file_sha(joinpath(BASE_SOURCE,entry["snapshot_path"]))==entry["sha256"] ||
            error("Published Beam source capsule hash mismatch")
    end
    true
end
verify_base_source()
include(joinpath(BASE_SOURCE,"src","data","testsub2_nv","TestSub2NV.jl"))
const BaseNV = TestSub2NV

function configuration(;smoke=false)
    original = JSON.parsefile(joinpath(BASE_SOURCE,"configs","releases","testsub2_nv_20261004.json"))
    result = Dict{String,Any}(key=>original[key] for key in
        ["baseline","fine","maximum_scaled_state_error","maximum_relative_energy_balance_error"])
    result["periods"] = smoke ? 2 : 32
    result["samples_per_period"] = 256
    result["object_id"] = "VK-BEAM-CC"
    result["configuration_id"] = "FE12"
    result["extension_id"] = smoke ? "skdm9_beam_smoke" : "skdm9_beam_h512_v1"
    result["base_source_binding"] = BASE_BINDING
    result["counts"] = smoke ? Dict("train"=>1,"val"=>0,"test"=>0) : Dict("train"=>96,"val"=>24,"test"=>24)
    result["initial_condition_family"] = "static midpoint transverse displacement; zero initial velocity"
    result["amplitude_interval_m"] = [0.0015,0.0025]
    result["split_rule"] = "144 ordered amplitudes in the original interval; each six-point stratum assigns offsets 0,1,4,5 to Train, 2 to Validation and 3 to Test"
    result["resource_rationale"] = "737376 full H512 Train windows before common-domain qualification; an initial resource budget, not a claim that coverage is already qualified"
    result["mechanics_and_integrator"] = "Unmodified published Float64 Rodas5P/UMFPACK and analytic Jacobian"
    result["test_policy"] = "Generating frozen truth is allowed; learning and model selection must not open Test"
    result
end

function initial_conditions(m;smoke=false)
    smoke && return [(split="train",id="SMOKE_train_001",q=BaseNV.static_release(m,0.0019)[1],
        meta=Dict{String,Any}("probe_amplitude"=>0.0019,"ic_family"=>"static"))]
    counts = Dict("train"=>0,"val"=>0,"test"=>0)
    result = NamedTuple[]
    for (i,amplitude) in enumerate(range(0.0015,0.0025;length=144))
        offset = mod(i-1,6)
        split = offset==2 ? "val" : offset==3 ? "test" : "train"
        counts[split] += 1
        q,load,residual = BaseNV.static_release(m,amplitude)
        id = "SKDM9_$(split)_$(lpad(counts[split],3,'0'))"
        push!(result,(;split,id,q,meta=Dict{String,Any}(
            "ic_family"=>"static","probe_amplitude"=>amplitude,
            "static_point_load_N"=>load,"static_relative_residual"=>residual,
            "initial_velocity"=>"all zero","amplitude_grid_index"=>i)))
    end
    length(unique(ic.meta["probe_amplitude"] for ic in result))==144 || error("Split overlap")
    counts==Dict("train"=>96,"val"=>24,"test"=>24) || error("Population count mismatch")
    result
end

function generate(output;smoke=false)
    verify_base_source()
    BLAS.set_num_threads(1)
    cfg = configuration(;smoke)
    binding = bytes2hex(sha256(BASE_BINDING*JSON.json(cfg)*file_sha(@__FILE__)))
    mkpath(output)
    configpath = joinpath(output,"generation_config.json")
    if isfile(configpath)
        JSON.parsefile(configpath)["binding"]==binding || error("Existing extension configuration differs")
    else
        BaseNV.write_json(configpath,Dict("binding"=>binding,"config"=>cfg))
    end
    m = BaseNV.beam_model(;elements=12)
    m.n==33 || error("Beam state dimension changed")
    population = initial_conditions(m;smoke)
    BaseNV.write_json(joinpath(output,"population.json"),[Dict("split"=>ic.split,"id"=>ic.id,"metadata"=>ic.meta) for ic in population])
    certificates = Any[]
    started = time()
    for (i,ic) in enumerate(population)
        certificate = BaseNV.solve_certified(m,ic,cfg,output,binding)
        push!(certificates,certificate)
        BaseNV.write_json(joinpath(output,"progress.json"),Dict("completed"=>i,"total"=>length(population),
            "trajectory"=>ic.id,"elapsed_seconds"=>time()-started,"binding"=>binding,"updated_utc"=>string(now(UTC))))
    end
    entries = [Dict("trajectory_id"=>c["trajectory_id"],"split"=>c["split"],"path"=>c["state_path"],
                    "sha256"=>c["state_sha256"]) for c in certificates]
    dt = (2pi/m.omega[m.reference_mode])/cfg["samples_per_period"]
    learner = Dict("schema"=>"skdm9.beam_extension.v1","object_id"=>m.id,"configuration_id"=>m.configuration,
        "state_dimension"=>66,"snapshot_count"=>cfg["periods"]*256+1,"dt_output"=>dt,
        "reference_period"=>2pi/m.omega[m.reference_mode],"state_layout"=>"col(all q, all v), original active nodal order",
        "active_dof_indices"=>m.active,"trajectories"=>entries,"binding"=>binding,
        "base_release"=>"testsub2_nv_20261004","full_source_binding"=>BASE_BINDING)
    BaseNV.write_json(joinpath(output,"learner_manifest.json"),learner)
    complete = Dict("status"=>"passed","binding"=>binding,"trajectories"=>length(entries),
        "manifest_sha256"=>file_sha(joinpath(output,"learner_manifest.json")),
        "maximum_scaled_state_error"=>maximum(c["scaled_state_error"] for c in certificates),
        "maximum_energy_error"=>maximum(max(c["baseline"]["energy_balance_relative"],c["fine"]["energy_balance_relative"]) for c in certificates),
        "elapsed_seconds"=>time()-started,"completed_utc"=>string(now(UTC)),"smoke_only"=>smoke)
    BaseNV.write_json(joinpath(output,"complete.json"),complete)
    println("SKDM9_BEAM_DATA_COMPLETE ",JSON.json(complete));flush(stdout)
    complete
end

end
