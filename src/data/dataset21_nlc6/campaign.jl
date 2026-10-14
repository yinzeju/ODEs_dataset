# SPDX-License-Identifier: GPL-3.0-only
using Random, SHA

"""Freeze the accepted 12-family, three-strength population without integration."""
function planned_population(cfg)
    ic=cfg["initial_conditions"];rows=Dict{String,Any}[]
    counters=Dict(s=>0 for s in ("train","validation","test"))
    for family in 1:12
        ordinal=0
        for tier in 1:3
            allocation=ic["family_strength_split_allocations"][family][tier]
            for (split,number) in zip(("train","validation","test"),allocation), _ in 1:number
                ordinal+=1;counters[split]+=1
                identity="$(get(cfg,"population_identity",cfg["release_id"]))/$(ic["seed"])/$family/$ordinal"
                seed=parse(UInt64,bytes2hex(sha256(identity))[1:16];base=16);rng=Xoshiro(seed)
                ratio=ic["added_energy_ratio_centers"][tier]*(1+ic["ratio_relative_jitter"]*(2rand(rng)-1))
                modes=family==12 ? Int[] : Int.(ic["families"][family])
                fractions=if length(modes)==1
                    [1.]
                elseif length(modes)==2
                    fraction=ic["pair_energy_fractions"][mod1(ordinal,3)];[fraction,1-fraction]
                elseif length(modes)==4
                    p=Float64.(ic["four_mode_base_energy_fractions"])[randperm(rng,4)]
                    p.*=1 .+ ic["four_mode_fraction_jitter"].*(2rand(rng,4).-1);p/sum(p)
                else
                    Float64[]
                end
                sign=isodd(ordinal) ? 1 : -1
                signs=length(modes)==0 ? Int[] : vcat(sign,rand(rng,[-1,1],length(modes)-1))
                id="NLC6_$(split)_$(lpad(counters[split],3,'0'))"
                push!(rows,Dict("id"=>id,"split"=>split,"family"=>family,"tier"=>tier,
                    "family_ordinal"=>ordinal,"seed_hex"=>string(seed;base=16),"modes"=>modes,
                    "linear_energy_fractions"=>fractions,"signs"=>signs,"static_sign"=>sign,
                    "connector_energy_ratio"=>ratio,"relative_path"=>"$split/$id/trajectory.h5"))
            end
        end
    end
    length(rows)==144 && all(counters[s]==ic["counts"][s] for s in keys(counters)) || error("Population allocation")
    if haskey(cfg,"population_plan_override")
        path=joinpath(NC.ROOT,cfg["population_plan_override"])
        NC.filehash(path)==cfg["population_plan_sha256"] || error("Override population hash mismatch")
        revised=NC.JSON.parsefile(path);scales=cfg["amplitude_overrides"]
        length(revised)==length(rows) || error("Override population length")
        issubset(Set(keys(scales)),Set(row["id"] for row in rows)) || error("Unknown amplitude override")
        for (original,replacement) in zip(rows,revised)
            id=original["id"]
            if haskey(scales,id)
                scale=Float64(scales[id])
                isfinite(scale) && 0<scale<=1 || error("Invalid amplitude reduction")
                revision=replacement["amplitude_revision"]
                revision["parent_release"]==cfg["repair_parent_release"] || error("Override parent mismatch")
                revision["original_connector_energy_ratio"]==original["connector_energy_ratio"] || error("Override original ratio")
                revision["displacement_scale"]==scale || error("Override scale mismatch")
                isapprox(replacement["connector_energy_ratio"],original["connector_energy_ratio"]*scale^2;rtol=1e-14) || error("Override energy ratio")
                restored=copy(replacement);delete!(restored,"amplitude_revision")
                restored["connector_energy_ratio"]=original["connector_energy_ratio"]
                restored==original || error("Override changed population recipe beyond amplitude")
            else
                replacement==original || error("Unapproved population change")
            end
        end
        return revised
    end
    return rows
end

"""Reject unbound, unknown, or weakening per-case numerical repairs before execution."""
function validate_numerical_overrides(cfg,rows)
    overrides=get(cfg,"case_solver_overrides",Dict{String,Any}())
    hashes=get(cfg,"case_initial_state_sha256",Dict{String,Any}())
    Set(keys(overrides))==Set(keys(hashes)) || error("Numerical repair must bind the exact initial state")
    issubset(Set(keys(overrides)),Set(row["id"] for row in rows)) || error("Unknown numerical repair case")
    base=cfg["trial"]["solver"]["substeps"]
    for (id,override) in overrides
        Set(keys(override))==Set(["substeps"]) || error("Unapproved case solver setting: $id")
        count=override["substeps"]
        count isa Integer && !(count isa Bool) && count>base && count%base==0 ||
            error("Case substeps must be a strict integer refinement: $id")
        hash=hashes[id]
        hash isa AbstractString && occursin(r"^[0-9a-f]{64}$",hash) || error("Invalid initial-state SHA256: $id")
    end
    return nothing
end

"""Copy the frozen recipe and apply only the validated per-case solver refinement."""
function trajectory_config(cfg,row)
    result=deepcopy(cfg);merge!(result["trial"],row)
    overrides=get(cfg,"case_solver_overrides",Dict{String,Any}())
    haskey(overrides,row["id"]) && merge!(result["trial"]["solver"],overrides[row["id"]])
    return result
end

function verify_initial_state_binding(cfg,id,q0)
    hash=bytes2hex(sha256(reinterpret(UInt8,q0)))
    bindings=get(cfg,"case_initial_state_sha256",Dict{String,Any}())
    haskey(bindings,id) && bindings[id]!=hash && error("Replacement initial-state SHA256 mismatch: $id")
    return hash
end

"""Solve the full nonlinear equilibrium and energy-ratio constraint together."""
function static_initial_condition(m,p,target,sign,settings)
    backend=NC.CPUBackend(m);load_shape=NC.preload(m);shape=m.K\load_shape
    E2=dot(shape,m.K*shape)/2;E4=sum(p.kappa.*(transpose(p.B)*shape).^4)/4
    q=sign*sqrt((target/16)*E2/E4)*shape;load=sign*sqrt((target/16)*E2/E4)
    trace=Any[];absolute_stiffness=abs.(m.K)
    for ratio in target.*[1/16,1/4,1/2,1.]
        # Predict on the nonzero branch: quartic/quadratic energy scales as amplitude squared.
        previous_ratio=(sum(p.kappa.*(transpose(p.B)*q).^4)/4)/(dot(q,m.K*q)/2)
        isfinite(previous_ratio) && previous_ratio>0 || error("Invalid static continuation state")
        predictor_scale=sqrt(ratio/previous_ratio)
        q*=predictor_scale;load*=predictor_scale
        converged=false
        for iteration in 1:settings["maximum_iterations"]
            NC.evaluate!(backend,m,q;tangent=true);s=transpose(p.B)*q
            elastic=p.B*(p.kappa.*s.^3);E2=dot(q,m.K*q)/2;E4=sum(p.kappa.*s.^4)/4
            residual=m.K*q+backend.force+elastic-load*load_shape;constraint=E4-ratio*E2
            J=m.K+backend.tangent+p.B*spdiagm(0=>3 .* p.kappa.*s.^2)*transpose(p.B)
            factor=lu(J);z=factor\residual;y=factor\load_shape;gradient=elastic-ratio*(m.K*q)
            denominator=dot(gradient,y);abs(denominator)>eps()*norm(gradient)*norm(y) || error("Static branch singular")
            dload=(-constraint+dot(gradient,z))/denominator;dq=-z+y*dload
            force_tolerance=settings["force_relative_tolerance"]*max(norm(load*load_shape),1.)+
                8eps(Float64)*norm(absolute_stiffness*abs.(q))
            correction=norm(dq./m.qscale)/max(norm(q./m.qscale),eps())
            ratio_error=abs(E4/E2/ratio-1)
            if norm(residual)<=force_tolerance && correction<=settings["correction_relative_tolerance"] && ratio_error<=settings["ratio_relative_tolerance"]
                converged=true;push!(trace,Dict("ratio"=>ratio,"iterations"=>iteration,"load_N"=>load,
                    "force_residual"=>norm(residual),"force_tolerance"=>force_tolerance,
                    "correction_relative"=>correction,"ratio_relative_error"=>ratio_error,
                    "predictor_scale"=>predictor_scale));break
            end
            force_scale=max(norm(load*load_shape),1.);energy_scale=max(ratio*E2,eps())
            merit=hypot(norm(residual)/force_scale,constraint/energy_scale);accepted=false
            for weight in (1.,.5,.25,.125,.0625,.03125,.015625)
                qt=q+weight*dq;lt=load+weight*dload
                lt*sign>0 || continue
                NC.evaluate!(backend,m,qt;tangent=false);st=transpose(p.B)*qt
                rt=m.K*qt+backend.force+p.B*(p.kappa.*st.^3)-lt*load_shape
                et=sum(p.kappa.*st.^4)/4-ratio*dot(qt,m.K*qt)/2
                if hypot(norm(rt)/force_scale,et/energy_scale)<merit
                    q=qt;load=lt;accepted=true;break
                end
            end
            accepted || error("NLC6 static Newton line search failed")
        end
        converged || error("NLC6 static equilibrium did not converge")
    end
    return q,Dict("static_load_N"=>load,"static_trace"=>trace)
end

function campaign_initial_condition(m,p,row,cfg)
    if row["family"]==12
        return static_initial_condition(m,p,row["connector_energy_ratio"],row["static_sign"],cfg["static_initialization"])
    end
    trialcfg=deepcopy(cfg);merge!(trialcfg["trial"],row)
    q,coefficients=initial_condition(m,p,trialcfg)
    return q,Dict("modal_coefficients"=>coefficients)
end

"""Check the saved artifact without a second simulation or qualification trajectory."""
function readback_trajectory(path,m,p,q0,cfg,receipt)
    n=length(q0);frames=cfg["sampling"]["frames"];dt=cfg["sampling"]["dt_candidate_s"]
    NC.HDF5.h5open(path,"r") do f
        size(f["x"])==(2n,frames) || error("Readback shape")
        f["x"][:,1]==vcat(q0,zeros(n)) || error("Readback initial state")
        maximum(abs,read(f["t"])-collect(0:frames-1)*dt)<1e-12 || error("Readback time grid")
        E=read(f["energy"]);D=read(f["dissipated"]);D0=read(f["dissipated_linear"]);Dn=read(f["dissipated_connector"])
        all(isfinite,E) && minimum(E)>0 && all(isfinite,D) || error("Readback energy values")
        maximum(abs,D-D0-Dn)<1e-12*max(E[1],1.) || error("Readback dissipation sum")
        minimum(diff(D0))>=-1e-12 && minimum(diff(Dn))>=-1e-12 || error("Nonpassive saved dissipation")
        isapprox(maximum(abs.(E+D.-E[1]))/E[1],receipt["max_energy_balance_relative"];atol=1e-12) || error("Readback energy balance")
        for first in 1:32:frames
            last=min(first+31,frames);x=f["x"][:,first:last]
            all(isfinite,x) || error("Nonfinite saved state")
            s=transpose(p.B)*view(x,1:n,:);w=transpose(p.B)*view(x,n+1:2n,:)
            maximum(abs,s-f["connector_displacement"][:,first:last])<1e-12 || error("Readback port displacement")
            maximum(abs,w-f["connector_velocity"][:,first:last])<1e-12 || error("Readback port velocity")
            expected=vec(sum(p.kappa.*s.^4;dims=1))/4
            maximum(abs,expected-f["connector_potential"][first:last])<1e-11*max(E[1],1.) || error("Readback port potential")
        end
    end
    NC.filehash(path)==receipt["sha256"] || error("Readback SHA mismatch")
    return true
end

function bind_campaign_inputs(folder,config_path,cfg)
    hashes=Dict{String,String}()
    for directory in ("src/data/dataset21_naca","src/data/dataset21_nlc6","configs/environments/dataset21_naca")
        for (parent,_,names) in walkdir(joinpath(NC.ROOT,directory)),name in names
            path=joinpath(parent,name);hashes[NC.portable_relative(path,NC.ROOT)]=NC.filehash(path)
        end
    end
    for path in (config_path,joinpath(NC.ROOT,"experiments/data_generation/run_dataset21_nlc6_campaign.jl"),
        joinpath(NC.ROOT,"configs/designs/dataset21_naca_nlc6_proposal.json"))
        hashes[NC.portable_relative(path,NC.ROOT)]=NC.filehash(path)
    end
    if haskey(cfg,"population_plan_override")
        path=joinpath(NC.ROOT,cfg["population_plan_override"])
        hashes[NC.portable_relative(path,NC.ROOT)]=NC.filehash(path)
    end
    manifest=joinpath(folder,"input_fingerprint.json")
    isfile(manifest) && Dict(NC.JSON.parsefile(manifest))!=hashes && error("Campaign inputs changed; preserve evidence and use a versioned repair")
    NC.writejson(manifest,hashes)
    for (relative,hash) in hashes
        target=joinpath(folder,"source_snapshot",relative);mkpath(dirname(target))
        if isfile(target)
            NC.filehash(target)==hash || error("Source snapshot changed")
        else
            cp(joinpath(NC.ROOT,relative),target)
        end
    end
    return hashes
end

function run_campaign(config_path)
    BLAS.set_num_threads(1);cfg=NC.JSON.parsefile(config_path)
    cfg["execution_authorized"]===true && cfg["formal_launch_authorized"]===true || error("Campaign authorization missing")
    !get(cfg,"revision_driver_required",false) && !get(cfg,"numerical_revision_driver_required",false) || error("Revision launch interlock")
    cfg["qualification_status"]=="user_waived_independent_qualification" || error("Qualification scope")
    cfg["sampling"]["frames"]==4096 && cfg["state_dimension"]<=30000 || error("State/frame contract")
    id=cfg["release_id"];occursin(r"^[a-zA-Z0-9_-]+$",id) || error("Release identity")
    folder=joinpath(NC.ROOT,"runs",id);release=joinpath(NC.ROOT,"data","releases",id)
    mkpath(folder);mkpath(release);lock=joinpath(folder,"execution.lock")
    ispath(lock) && error("Execution lock exists; verify process identity before manual recovery")
    mkdir(lock);current="initialization"
    try
        hashes=bind_campaign_inputs(folder,abspath(config_path),cfg)
        basepath=joinpath(NC.ROOT,cfg["base_model_path"])
        NC.filehash(basepath)==cfg["base_model_sha256"] || error("Base model hash")
        m=with_damping(NC.JLD2.load(basepath,"model"),cfg);p=build_connectors(m,cfg)
        2length(m.active)==cfg["state_dimension"] || error("Physical dimension mismatch")
        rows=planned_population(cfg);validate_numerical_overrides(cfg,rows)
        backend=NC.GPUBackend(m)
        planpath=joinpath(folder,"population_plan.json")
        isfile(planpath) && NC.JSON.parsefile(planpath)!=rows && error("Population plan changed")
        NC.writejson(planpath,rows);NC.writejson(joinpath(release,"population_plan.json"),rows)
        modelpath=joinpath(release,"model.jld2")
        isfile(modelpath) || NC.JLD2.jldsave(modelpath;model=m,connectors=p)
        metadata=Dict("schema"=>"dataset21.nlc6.release.v1","release_id"=>id,
            "qualification_status"=>cfg["qualification_status"],"status"=>"generating",
            "state_dimension"=>cfg["state_dimension"],"frames"=>4096,"counts"=>cfg["initial_conditions"]["counts"],
            "dt_seconds"=>cfg["sampling"]["dt_candidate_s"],"model_sha256"=>NC.filehash(modelpath),
            "source_fingerprint"=>hashes,"trajectories"=>Any[],"noise_views"=>Any[])
        completed=Any[];quarantined=Any[];seen=Set{String}()
        for row in rows
            try
            current=row["id"];path=joinpath(release,row["relative_path"]);mkpath(dirname(path))
            NC.writejson(joinpath(folder,"campaign_status.json"),Dict("status"=>"generating","current_id"=>current,
                "current_path"=>NC.portable_relative(path,NC.ROOT),"completed"=>length(completed),"total"=>144))
            println("NLC6_INITIALIZE ",current," family=",row["family"]," tier=",row["tier"]);flush(stdout)
            q0,details=campaign_initial_condition(m,p,row,cfg)
            initialhash=verify_initial_state_binding(cfg,current,q0)
            initialhash in seen && error("Duplicate initial state")
            push!(seen,initialhash);geo=NC.evaluate!(NC.CPUBackend(m),m,q0;tangent=false)
            geo.strain<=cfg["solver_proposal"]["maximum_strain_component"] || error("NLC6 physics gate: initial strain limit: $current")
            ratio=sum(p.kappa.*(transpose(p.B)*q0).^4)/4/(dot(q0,m.K*q0)/2)
            isapprox(ratio,row["connector_energy_ratio"];rtol=1e-7) || error("Initial energy ratio")
            initial=merge(copy(row),details,Dict("initial_state_sha256"=>initialhash,"initial_strain"=>geo.strain,
                "initial_amplitude_m"=>NC.amplitude(m,q0),"actual_connector_energy_ratio"=>ratio))
            initialpath=joinpath(dirname(path),"initial_condition.json")
            isfile(initialpath) && NC.JSON.parsefile(initialpath)!=initial && error("Initial-condition binding changed")
            NC.writejson(initialpath,initial)
            trajectorycfg=trajectory_config(cfg,row)
            if isfile(path)
                isfile(path*".json") || error("Completed file lacks receipt")
                receipt=NC.JSON.parsefile(path*".json")
            else
                receipt=integrate(path,m,backend,p,q0,trajectorycfg)
            end
            receipt["solver"]==trajectorycfg["trial"]["solver"] || error("Actual solver receipt differs from the bound case settings: $current")
            receipt["physics_checks_passed"]===true || error("NLC6 physics gate: trajectory limits: $current")
            readback_trajectory(path,m,p,q0,cfg,receipt)
            NC.writejson(joinpath(dirname(path),"readback.json"),Dict("status"=>"passed","sha256"=>receipt["sha256"],"frames"=>4096))
            result=merge(copy(row),Dict("sha256"=>receipt["sha256"],"initial_state_sha256"=>initialhash,
                "wall_seconds"=>receipt["wall_seconds"],"max_energy_balance_relative"=>receipt["max_energy_balance_relative"],
                "max_strain"=>receipt["max_recovered_strain_component"],"final_energy_ratio"=>receipt["final_energy_ratio"],
                "solver"=>receipt["solver"]))
            originpath=joinpath(dirname(path),"reused_from.json")
            isfile(originpath) && (result["reused_from"]=NC.JSON.parsefile(originpath))
            push!(completed,result);metadata["trajectories"]=completed
            NC.writejson(joinpath(release,"release_manifest.json"),metadata)
            NC.writejson(joinpath(folder,"completed.json"),completed)
            println("NLC6_TRAJECTORY_COMPLETE id=",current," completed=",length(completed),"/144");flush(stdout)
            GC.gc()
            catch exception
                if get(cfg,"quarantine_physics_failures",false) && exception isa ErrorException && startswith(exception.msg,"NLC6 physics gate:")
                    push!(quarantined,Dict("id"=>current,"error"=>sprint(showerror,exception),"row"=>row))
                    NC.writejson(joinpath(folder,"quarantined.json"),quarantined)
                    metadata["quarantined"]=quarantined
                    NC.writejson(joinpath(release,"release_manifest.json"),metadata)
                    println("NLC6_QUARANTINED id=",current," reason=",sprint(showerror,exception));flush(stdout)
                    continue
                end
                rethrow()
            end
        end
        if !isempty(quarantined)
            metadata["status"]="incomplete_quarantined_physics_cases"
            NC.writejson(joinpath(release,"release_manifest.json"),metadata)
            NC.writejson(joinpath(folder,"campaign_status.json"),Dict("status"=>metadata["status"],
                "completed"=>length(completed),"quarantined"=>length(quarantined),"total"=>144))
            return nothing
        end
        metadata["status"]="complete_user_waived_independent_qualification"
        NC.writejson(joinpath(release,"release_manifest.json"),metadata)
        NC.writejson(joinpath(folder,"campaign_status.json"),Dict("status"=>"complete","completed"=>144,
            "full_readback_passed"=>true,"manifest_sha256"=>NC.filehash(joinpath(release,"release_manifest.json"))))
    catch exception
        failure=Dict("status"=>"needs_repair","current_id"=>current,"error"=>sprint(showerror,exception))
        NC.writejson(joinpath(folder,"failure_$(time_ns()).json"),failure)
        NC.writejson(joinpath(folder,"campaign_status.json"),failure);rethrow()
    finally
        rm(lock)
    end
end
