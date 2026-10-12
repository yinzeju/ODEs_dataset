# One explicitly authorized full-state trajectory; never launches a population.
"--execute" in ARGS || error("Explicit single-trial execution authorization required")
include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
include(joinpath(@__DIR__,"..","..","src","data","dataset21_nlc6","Dataset21NLC6.jl"))
const NC=Dataset21NACA
const NL=Dataset21NLC6
using LinearAlgebra,SHA
Base.include(NC,joinpath(NC.ROOT,"src","data","dataset21_naca","gpu.jl"))

function main(config_path)
    BLAS.set_num_threads(1)
    cfg=NC.JSON.parsefile(config_path)
    cfg["execution_authorized"]===true && cfg["formal_launch_authorized"]===false || error("Single-trial authorization mismatch")
    cfg["trial"]["trajectory_count"]==1 || error("Only one trajectory is authorized")
    id=cfg["trial"]["id"];occursin(r"^[a-zA-Z0-9_-]+$",id) || error("Invalid trial identity")
    folder=joinpath(NC.ROOT,"runs",id);mkpath(folder)
    lock=joinpath(folder,"execution.lock");ispath(lock) && error("Trial lock exists")
    mkdir(lock)
    try
        fingerprints=Dict{String,String}()
        for directory in ("src/data/dataset21_naca","src/data/dataset21_nlc6","configs/environments/dataset21_naca")
            for (parent,_,files) in walkdir(joinpath(NC.ROOT,directory)),name in files
                path=joinpath(parent,name);relative=NC.portable_relative(path,NC.ROOT)
                fingerprints[relative]=NC.filehash(path)
            end
        end
        for path in (config_path,@__FILE__,joinpath(NC.ROOT,"configs/designs/dataset21_naca_nlc6_proposal.json"))
            fingerprints[NC.portable_relative(path,NC.ROOT)]=NC.filehash(path)
        end
        manifest=joinpath(folder,"input_fingerprint.json")
        isfile(manifest) && NC.JSON.parsefile(manifest)!=fingerprints && error("Trial inputs changed; create a fresh attempt")
        NC.writejson(manifest,fingerprints)
        for (relative,hash) in fingerprints
            target=joinpath(folder,"source_snapshot",relative);mkpath(dirname(target))
            if isfile(target)
                NC.filehash(target)==hash || error("Snapshot changed")
            else
                cp(joinpath(NC.ROOT,relative),target)
            end
        end
        modelpath=joinpath(NC.ROOT,"runs/dataset21_naca_zeta006_f4096_v3_partial/models/candidate.jld2")
        NC.filehash(modelpath)==cfg["base_model_sha256"] || error("Base model hash")
        base=NC.JLD2.load(modelpath,"model");m=NL.with_damping(base,cfg);p=NL.build_connectors(m,cfg)
        2length(m.active)==cfg["state_dimension"]<=30000 || error("Physical state cap")
        q0,coefficients=NL.initial_condition(m,p,cfg);v0=zeros(length(q0))
        geo=NC.CPUBackend(m);g=NC.evaluate!(geo,m,q0;tangent=false)
        g.strain<=cfg["solver_proposal"]["maximum_strain_component"] || error("Initial strain gate")
        ports=NL.connector_values(p,q0,v0)
        ratio=ports.potential/(dot(q0,m.K*q0)/2)
        isapprox(ratio,cfg["trial"]["connector_energy_ratio"];rtol=1e-10) || error("Initial connector-energy ratio")
        backend=NC.GPUBackend(m)
        cpu_force=copy(geo.force);NC.evaluate!(backend,m,q0;tangent=false)
        force_error=norm(cpu_force-backend.force)/max(norm(cpu_force),eps())
        force_error<=1e-10 || error("GPU force parity")
        initial=Dict("modes"=>cfg["trial"]["modes"],"modal_coefficients"=>coefficients,
            "connector_energy_ratio"=>ratio,"maximum_translation_m"=>NC.amplitude(m,q0),
            "initial_strain"=>g.strain,"initial_connector_displacement_m"=>ports.s,
            "initial_state_sha256"=>bytes2hex(sha256(reinterpret(UInt8,q0))),
            "gpu_force_relative_error"=>force_error,"base_model_sha256"=>cfg["base_model_sha256"])
        NC.writejson(joinpath(folder,"initial_condition.json"),initial)
        NC.JLD2.jldsave(joinpath(folder,"trial_model.jld2");model=m,connectors=p,q0)
        NC.HDF5.h5open(joinpath(folder,"analysis_reference.h5"),"w") do f
            f["modes"]=m.modes;f["mass_modes"]=m.M*m.modes;f["omega"]=m.omega
            f["active"]=m.active;f["nodes"]=m.mesh.nodes;f["q0"]=q0
            f["B"]=Matrix(p.B);f["modal_coefficients"]=coefficients
            f["linear_damping"]=Float64[m.aM,m.aK]
        end
        println("NLC6_TRIAL_START states=",2length(q0)," frames=",cfg["sampling"]["frames"],
            " initial_amplitude_mm=",1000*NC.amplitude(m,q0)," connector_energy_ratio=",ratio," gpu_force_error=",force_error);flush(stdout)
        path=joinpath(folder,"trajectory.h5")
        receipt=NL.integrate(path,m,backend,p,q0,cfg)
        NC.HDF5.h5open(path,"r") do f
            size(f["x"])==(2length(q0),4096) || error("Saved state shape")
            t=read(f["t"]);maximum(abs,t-collect(0:4095)*cfg["sampling"]["dt_candidate_s"])<1e-12 || error("Time grid")
            for first in 1:32:4096
                all(isfinite,f["x"][:,first:min(first+31,4096)]) || error("Nonfinite saved values")
            end
            E=read(f["energy"]);D=read(f["dissipated"])
            isapprox(maximum(abs.(E+D.-E[1]))/E[1],receipt["max_energy_balance_relative"];atol=1e-12) || error("Energy readback")
            for k in (1,2048,4096)
                x=f["x"][:,k]
                norm(transpose(p.B)*x[1:length(q0)]-f["connector_displacement"][:,k])<1e-12 || error("Port mapping readback")
            end
        end
        NC.writejson(joinpath(folder,"completion.json"),Dict("status"=>"single_trial_completed",
            "full_readback_passed"=>true,"physics_checks_passed"=>receipt["physics_checks_passed"],
            "trajectory_sha256"=>receipt["sha256"],"temporal_refinement"=>"not performed on this physical initial condition",
            "population_generation_authorized"=>false))
        println("NLC6_TRIAL_COMPLETED ",NC.JSON.json(receipt));flush(stdout)
    catch exception
        NC.writejson(joinpath(folder,"failure.json"),Dict("status"=>"failed","error"=>sprint(showerror,exception)))
        rethrow()
    finally
        rm(lock)
    end
end

index=findfirst(==("--config"),ARGS)
config_path=index===nothing ? joinpath(NC.ROOT,"configs/trials/dataset21_nlc6_one.json") : abspath(ARGS[index+1])
Base.invokelatest(main,config_path)
