include(joinpath(@__DIR__, "..", "..", "src", "data", "standard_odes_v2", "StandardODEsV2.jl"))
using .StandardODEsV2, JLD2, JSON

function audit_metadata()
    cfg=JSON.parsefile(joinpath(StandardODEsV2.ROOT,"configs","releases","standard_odes_v2.json"))
    out=joinpath(StandardODEsV2.ROOT,"data","releases",cfg["release_id"])
    expected=StandardODEsV2.group_specs(cfg,:formal)
    manifest=JSON.parsefile(joinpath(out,"release_manifest.json"))
    @assert manifest["all_passed"] && length(expected)==length(manifest["objects"])
    required=split("protocol_id family_id profile base_object_id state_components state_units state_dim physical_parameters condition_parameter_names condition_values condition_id ic_law_id ic_law_parameters ic_seed ic_seed_group_id preburn_initial_state record_initial_state burn_in_time sampling_interval time_unit snapshot_count transition_count record_duration endpoint_policy layout solver solver_parameters integration_dtype storage_dtype normalization_policy observation_view noise_reference_split_id noise_covariance noise_seed target_view split_protocol split_id trajectory_id parent_trajectory_id source_references qualification_artifact_id configuration_hash")
    ic_seeds=Set{Int}(); probe_seeds=Set{Int}(); views=0
    for (s,e) in zip(expected,manifest["objects"])
        @assert s==e["spec"]
        dir=dirname(joinpath(out,e["path"]))
        meta=JLD2.load(joinpath(dir,"clean.jld2"),"metadata")
        @assert all(haskey(meta,key) for key in required)
        @assert meta["physical_parameters"]==s["parameters"]
        @assert meta["condition_values"]==repeat(permutedims(s["condition_value"]),s["R"],1)
        @assert meta["state_components"]==StandardODEsV2.components(s)
        @assert meta["ic_law_parameters"]==StandardODEsV2.ic_description(s)
        @assert meta["split_roles"]==StandardODEsV2.split_roles(s,cfg)[1]
        @assert meta["burn_in_time"]==s["burn"]
        @assert meta["record_duration"]==(s["M"]-1)*s["tau"]
        @assert meta["solver_parameters"]==StandardODEsV2.solver_settings(s;substeps=manifest["fput_substeps"])
        @assert meta["ic_seed"]==[StandardODEsV2.stable_seed(cfg,"ic",id) for id in meta["trajectory_id"]]
        union!(ic_seeds,meta["ic_seed"])
        reference=JSON.parsefile(joinpath(out,s["resource_id"],"noise_reference.json"))
        for db in (5,15)
            vm=JLD2.load(joinpath(dir,"noise_$(db)db.jld2"),"metadata")
            @assert all(haskey(vm,key) for key in required)
            @assert vm["physical_parameters"]==meta["physical_parameters"]
            @assert vm["condition_values"]==meta["condition_values"]
            @assert vm["noise_seed"]==[StandardODEsV2.stable_seed(cfg,"noise",id,db) for id in meta["trajectory_id"]]
            @assert isapprox(vm["noise_covariance"]["diagonal"],reference["power"].*10.0^(-db/10);rtol=1e-14)
            @assert vm["noise_reference_split_id"]==s["resource_id"]
        end
        views+=3
    end
    probes=JSON.parsefile(joinpath(out,"numerical_probes.json"))
    for group in values(probes), probe in group["records"]
        @assert probe["passed"] && !(probe["seed"] in probe_seeds)
        push!(probe_seeds,probe["seed"])
    end
    @assert isempty(intersect(ic_seeds,probe_seeds))
    @assert StandardODEsV2.filehash(cfg["protocol_note"])==StandardODEsV2.filehash(joinpath(out,"protocol_note_snapshot.md"))==manifest["note_sha256"]
    result=Dict("all_passed"=>true,"metadata_views"=>views,"ic_seeds"=>length(ic_seeds),
        "independent_probe_seeds"=>length(probe_seeds),"probe_data_seed_overlap"=>0,"required_fields"=>length(required))
    StandardODEsV2.write_json(joinpath(out,"metadata_audit.json"),result)
    println(JSON.json(result))
end

audit_metadata()
