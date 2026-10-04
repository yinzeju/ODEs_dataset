using LinearAlgebra, JLD2, SHA
import JSON
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
using .TestSub2NV

function check(condition,message)
    condition || error(message)
end

function check_refinement(certificate)
    base,fine=certificate["baseline"],certificate["fine"]
    check(fine["reltol"]<base["reltol"] && fine["abstol"]<base["abstol"],"Fine tolerances were not tightened")
    check(isapprox(fine["max_step_over_reference_period"],base["max_step_over_reference_period"]/2;rtol=1e-14),"Fine internal step cap was not halved")
    check(min(base["minimum_damping_power"],fine["minimum_damping_power"])>=-1e-12,"Negative damping power")
end

function main()
    BLAS.set_num_threads(1)
    root=normpath(joinpath(@__DIR__,"..",".."))
    cfg=JSON.parsefile(joinpath(root,"configs","releases","testsub2_nv_20261004.json"))
    release=joinpath(root,"data","releases",cfg["release_id"],"TestSub2")
    release_path=joinpath(release,"release_manifest.json")
    published=isfile(release_path)
    previous=published ? JSON.parsefile(release_path) : nothing
    if published
        catalog_path=joinpath(release,previous["artifact_manifest"])
        check(TestSub2NV.file_sha(catalog_path)==previous["artifact_manifest_sha256"],"Artifact catalog changed")
        catalog=JSON.parsefile(catalog_path)
        for (relative,expected) in catalog["files"]
            path=normpath(joinpath(release,relative))
            check(!isabspath(relative) && !startswith(relpath(path,release),".."),"Unsafe artifact path")
            check(TestSub2NV.file_sha(path)==expected,"Published artifact changed: $relative")
        end
    end
    identity=Dict("duffing"=>("OSC-DUFFING8","BASE"),"beam"=>("VK-BEAM-CC","FE12"),
        "shell_nr"=>("VK-SHELL-SHALLOW","NR"),"shell_ir12"=>("VK-SHELL-SHALLOW","IR12"),
        "plate"=>("VK-PLATE-SQUARE","FE200"))
    results=Any[];totalbytes=0;bindings=Set{String}()
    for id in cfg["objects"]
        object,configuration=identity[id]
        folder=joinpath(release,object,configuration)
        info=JSON.parsefile(joinpath(folder,"manifests","configuration.json"))
        check(info["status"]=="qualified","Configuration is not qualified")
        push!(bindings,info["binding"])
        m=jldopen(joinpath(root,"runs","testsub2_nv","models",id*".jld2"),"r") do f;f["model"];end
        assembly=joinpath(root,"runs","testsub2_nv","models",id*"_assembly.json")
        if !published
            cp(assembly,joinpath(folder,"qualification","mechanical_assembly.json");force=true)
        end
        manifest=JSON.parsefile(joinpath(folder,"manifests","learner_manifest.json"))
        ndof=m.id=="OSC-DUFFING8" ? 1 : m.id=="VK-BEAM-CC" ? 3 : 6
        q_units=m.id=="OSC-DUFFING8" ? fill("dimensionless",m.n) :
            [mod1(i,ndof)<=(ndof==3 ? 2 : 3) ? "m" : "rad" for i in m.active]
        v_units=[u=="dimensionless" ? "dimensionless/time" : u*"/s" for u in q_units]
        channel_contract=Dict("q_rows"=>[1,m.n],"v_rows"=>[m.n+1,2m.n],
            "units"=>vcat(q_units,v_units),"active_nodal_dof_indices"=>m.active,
            "dofs_per_node"=>ndof,"ordering"=>"ascending original nodal DOF index after boundary elimination")
        if published
            check(manifest["channel_contract"]==channel_contract,"Published channel contract mismatch")
        else
            manifest["channel_contract"]=channel_contract
            TestSub2NV.write_json(joinpath(folder,"manifests","learner_manifest.json"),manifest)
        end
        hashes=Set{String}();counts=zeros(Int,3);maxstate=0.;maxenergy=0.;exposures=Float64[]
        total=zeros(2m.n);square=zeros(2m.n);train_count=0;maxrhs=0.
        for row in manifest["trajectories"]
            data=TestSub2NV.load_learner_view(folder,row["trajectory_id"])
            x,t=data["x"],data["t"]
            check(eltype(x)==Float64,"Truth precision is not Float64")
            check(size(x)==(2m.n,4097),"State dimensions or record length mismatch")
            check(length(t)==4097 && first(t)==0.,"Invalid release time origin")
            check(all(isfinite,x),"Nonfinite state data")
            check(all(iszero,view(x,m.n+1:2m.n,1)),"Initial velocity must be zero")
            check(maximum(abs.(diff(t).-manifest["dt_output"]))<1e-11,"Output time grid mismatch")
            ih=bytes2hex(sha256(reinterpret(UInt8,x[:,1])))
            check(!(ih in hashes),"Trajectory initial condition reused across canonical splits")
            push!(hashes,ih)
            split=findfirst(==(row["split"]),["train","val","test"])
            check(!isnothing(split),"Invalid canonical split");counts[split]+=1
            certificate=JSON.parsefile(joinpath(folder,"qualification",row["trajectory_id"]*"_certificate.json"))
            check(certificate["passed"] && certificate["binding"]==info["binding"],"Certificate identity mismatch")
            check_refinement(certificate)
            check(certificate["state_sha256"]==row["sha256"],"Certificate checksum differs from learner manifest")
            maxstate=max(maxstate,certificate["scaled_state_error"])
            maxenergy=max(maxenergy,certificate["baseline"]["energy_balance_relative"],certificate["fine"]["energy_balance_relative"])
            check(maxstate<=1e-7 && maxenergy<=1e-7,"Numerical qualification threshold exceeded")
            metadata_path=joinpath(folder,"audit_only","trajectory_manifests",row["trajectory_id"]*".json")
            metadata=JSON.parsefile(metadata_path)
            if !haskey(metadata,"solver_version")
                check(!published,"Published solver metadata missing")
                metadata["solver_version"]="Julia 1.12.5; "*certificate["fine"]["solver"]*"; dependencies in frozen source snapshot"
                TestSub2NV.write_json(metadata_path,metadata)
            end
            q0=view(x,1:m.n,1);fnl=zeros(m.n)
            TestSub2NV.nonlinear!(fnl,m.kernel,q0)
            exposure=norm(fnl./m.qscale)/max(norm((m.K*q0)./m.qscale),eps())
            check(isfinite(exposure) && exposure>=0,"Invalid initial nonlinear exposure")
            push!(exposures,exposure)
            if haskey(metadata,"initial_nonlinear_exposure")
                check(isapprox(metadata["initial_nonlinear_exposure"],exposure;rtol=1e-10,atol=1e-14),"Initial nonlinear exposure mismatch")
            else
                check(!published,"Published nonlinear exposure metadata missing")
                metadata["initial_nonlinear_exposure"]=exposure
                metadata["nonlinear_exposure_scale"]="displacement block of the frozen numerical state scale; epsilon=eps(Float64)"
                TestSub2NV.write_json(metadata_path,metadata)
            end
            # Verify the stored velocity block against the kinematic rows of the
            # independently evaluated first-order mechanical residual.
            p=TestSub2NV.integration_cache(m);du=zeros(2m.n+1)
            for j in unique([1,1025,2049,3073,4097])
                u=vcat(x[1:m.n,j]./m.qscale,x[m.n+1:2m.n,j]./(p.omega.*m.qscale),0.)
                TestSub2NV.mechanical_rhs!(du,u,p,0.)
                maxrhs=max(maxrhs,norm(du[1:m.n].*(p.omega.*m.qscale)-x[m.n+1:2m.n,j]))
            end
            if row["split"]=="train"
                total .+= vec(sum(x;dims=2));square .+= vec(sum(abs2,x;dims=2));train_count+=size(x,2)
            end
            totalbytes+=filesize(joinpath(folder,row["path"]))
        end
        check(counts==cfg["canonical_counts"][id],"Incorrect canonical population")
        jldopen(joinpath(folder,"can","train_normalizer.jld2"),"r") do f
            check(f["fitted_split"]=="train" && f["snapshot_count"]==train_count,"Normalizer fit population mismatch")
            check(isapprox(f["mean"],total./train_count;rtol=1e-12,atol=1e-14),"Normalizer mean mismatch")
            expected=sqrt.(max.(square./train_count.-(total./train_count).^2,0.))
            expected=max.(expected,1e-12.*vcat(m.qscale,m.omega[m.reference_mode].*m.qscale))
            check(isapprox(f["scale"],expected;rtol=1e-12,atol=1e-14),"Normalizer scale mismatch")
        end
        qualfiles=filter(p->startswith(basename(p),"QUAL_") && endswith(p,"_certificate.json"),
            readdir(joinpath(folder,"qualification");join=true))
        check(length(qualfiles)==info["qualification_count"],"Independent qualification population mismatch")
        maxqualstate=0.;maxqualenergy=0.
        for path in qualfiles
            cert=JSON.parsefile(path)
            check(cert["passed"] && cert["binding"]==info["binding"],"Independent qualification failed")
            check_refinement(cert)
            maxqualstate=max(maxqualstate,cert["scaled_state_error"])
            maxqualenergy=max(maxqualenergy,cert["baseline"]["energy_balance_relative"],cert["fine"]["energy_balance_relative"])
            check(maxqualstate<=1e-7 && maxqualenergy<=1e-7,"Independent qualification threshold exceeded")
            statepath=joinpath(folder,cert["state_path"])
            check(TestSub2NV.file_sha(statepath)==cert["state_sha256"],"QUAL checksum mismatch")
            q=jldopen(statepath,"r") do f;f["x"][:,1];end
            check(!(bytes2hex(sha256(reinterpret(UInt8,q))) in hashes),"QUAL state overlaps CAN population")
        end
        # Only allowlisted canonical trajectory IDs may enter the learner loader.
        rejected=false
        try
            TestSub2NV.load_learner_view(folder,"../audit_only/mechanical_model")
        catch
            rejected=true
        end
        check(rejected,"Audit path was visible through learner loader")
        result=Dict("object_id"=>object,"configuration_id"=>configuration,
            "canonical_counts"=>counts,"canonical_trajectories"=>sum(counts),"displacement_dofs"=>m.n,
            "snapshot_count_per_trajectory"=>4097,"maximum_scaled_state_error"=>maxstate,
            "maximum_energy_balance_relative_error"=>maxenergy,"kinematic_rhs_residual"=>maxrhs,
            "maximum_independent_qualification_state_error"=>maxqualstate,
            "maximum_independent_qualification_energy_error"=>maxqualenergy,
            "initial_nonlinear_exposure_range"=>[minimum(exposures),maximum(exposures)],
            "independent_qualification_trajectories"=>length(qualfiles),"complete_readback"=>true)
        if !published
            TestSub2NV.write_json(joinpath(folder,"qualification","readback.json"),result)
        end
        push!(results,result)
        println("READBACK_OK ",object,"/",configuration," count=",sum(counts));flush(stdout)
    end
    for binding in bindings
        provenance=JSON.parsefile(joinpath(release,"manifests","provenance_$(binding[1:12]).json"))
        snapshot=joinpath(release,"audit_only","source_snapshots",binding)
        snapshot_index=JSON.parsefile(joinpath(snapshot,"snapshot_manifest.json"))
        for (relative,expected) in provenance["files"]
            saved=snapshot_index["files"][relative]
            check(saved["sha256"]==expected,"Frozen source index mismatch")
            check(TestSub2NV.file_sha(joinpath(snapshot,saved["snapshot_path"]))==expected,
                "Frozen source changed: $relative")
        end
    end
    if published
        check(previous["formal_trajectory_count"]==sum(r["canonical_trajectories"] for r in results),"Published population changed")
        check(Set(previous["source_bindings"])==bindings,"Published source bindings changed")
        println("FROZEN_RELEASE_VERIFIED ",release_path)
        return
    end
    cp(@__FILE__,joinpath(release,"audit_only","release_verifier.jl");force=true)
    artifacts=Dict{String,String}()
    for (directory,_,files) in walkdir(release),filename in files
        path=joinpath(directory,filename)
        relative=replace(relpath(path,release),'\\'=>'/')
        relative in ("release_manifest.json","manifests/artifact_manifest.json") && continue
        check(!endswith(filename,".tmp"),"Incomplete temporary artifact remains")
        artifacts[relative]=TestSub2NV.file_sha(path)
    end
    catalog=TestSub2NV.write_json(joinpath(release,"manifests","artifact_manifest.json"),Dict("files"=>artifacts))
    # HV entries are explicit external responsibilities, never fabricated data.
    result=Dict("release_id"=>cfg["release_id"],"status"=>"dataset-qualified",
        "resource"=>"CAN","noise_views"=>["clean"],"formal_trajectory_count"=>sum(r["canonical_trajectories"] for r in results),
        "canonical_data_bytes"=>totalbytes,"configurations"=>results,"source_bindings"=>sort!(collect(bindings)),
        "artifact_manifest"=>"manifests/artifact_manifest.json","artifact_manifest_sha256"=>TestSub2NV.file_sha(catalog),
        "HV"=>Dict("MEMS-GYRO"=>"external user COMSOL generation pending","TRC-JOINT"=>"external user COMSOL generation pending"),
        "REPLAY"=>"Not a strict replay release; CAN populations use independently declared amplitudes and seeds.",
        "qualification_scope"=>"Full-state time refinement for every CAN and independent QUAL trajectory; reference FE matrix parity; energy and kinematics; no continuum mesh-convergence claim.")
    manifest=TestSub2NV.write_json(joinpath(release,"release_manifest.json"),result)
    TestSub2NV.write_json(joinpath(root,"data","testsub2_nv_active.json"),Dict("release_id"=>cfg["release_id"],
        "manifest"=>replace(relpath(manifest,root),'\\'=>'/'),"sha256"=>TestSub2NV.file_sha(manifest)))
    println("RELEASE_PUBLISHED ",manifest," canonical_trajectories=",result["formal_trajectory_count"])
end
main()
