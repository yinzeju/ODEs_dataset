# CPU-only linear calibration and initial-state algebra; no time integration.
include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
using .Dataset21NACA, LinearAlgebra, SparseArrays, Random
const NC = Dataset21NACA

function main()
    BLAS.set_num_threads(1)
    root=NC.ROOT
    modelpath=joinpath(root,"runs","dataset21_naca_zeta006_f4096_v3_partial","models","candidate.jld2")
    model=NC.JLD2.load(modelpath,"model")
    xyz=model.mesh.nodes; nn=size(xyz,1); nq=length(model.active)
    @assert 2nq<=30000
    lumped_area=zeros(nn)
    for (e,triangle) in enumerate(eachrow(model.mesh.triangles))
        model.mesh.domains[e]==1 || continue
        a,b,c=(xyz[i,:] for i in triangle)
        area=norm(cross(b-a,c-a))/2
        lumped_area[triangle].+=area/3
    end
    centers=[(0.20,3.0),(0.80,3.0),(0.20,4.5),(0.80,4.5)]
    names=["mid_front","mid_rear","outer_front","outer_rear"]
    P=zeros(nq,8);patches=Any[]
    for (j,(xc,zc)) in enumerate(centers)
        # Finite patch support in the reference configuration, both skin faces.
        nodes=findall(i->abs(xyz[i,1]-xc)<=0.10 && abs(xyz[i,3]-zc)<=0.12 && lumped_area[i]>0,1:nn)
        @assert length(nodes)>=3 && all(i->!(i in model.mesh.fixed_nodes),nodes)
        weights=lumped_area[nodes]/sum(lumped_area[nodes])
        full=zeros(6nn);full[6 .* (nodes.-1).+2]=weights
        P[:,j]=full[model.active]
        full=zeros(6nn);full[6 .* (nodes.-1).+1]=weights
        P[:,j+4]=full[model.active]
        push!(patches,Dict("name"=>names[j],"center_x_z_m"=>[xc,zc],
            "half_width_x_z_m"=>[0.10,0.12],"nodes_one_based"=>nodes,
            "weights"=>weights,"node_count"=>length(nodes),
            "weighted_center_m"=>vec(transpose(weights)*xyz[nodes,:])))
    end
    B=hcat((P[:,1]+P[:,2])/2,(P[:,3]+P[:,4])/2,P[:,2]-P[:,1],P[:,4]-P[:,3],
        (P[:,5]+P[:,6])/2,(P[:,7]+P[:,8])/2)
    @assert rank(B)==6
    factor=cholesky(Symmetric(model.K))
    compliance=transpose(B)*(factor\B)
    @assert isposdef(Symmetric(compliance))
    kref=1 ./ diag(compliance)
    participation=transpose(B)*model.modes[:,1:4]
    omega_ref=sqrt.(vec(sum(participation.^2 .* transpose(model.omega[1:4].^2);dims=2))./
        vec(sum(participation.^2;dims=2)))
    sref=[0.002,0.002,0.001,0.001,0.002,0.002]
    stiffness_ratio=1.0
    k3=stiffness_ratio*kref./sref.^2
    carrier=model.omega[[1,1,4,4,2,2]]
    damping_reference_ratio=0.0005
    damping_cap=2damping_reference_ratio*kref./carrier
    saturation_speed=[0.020,0.030,0.050,0.070,0.060,0.090]
    @assert all(k3.>0) && all(damping_cap.>0)
    ports=[Dict("name"=>name,"kref_N_per_m"=>kref[j],"reference_extension_m"=>sref[j],
        "reference_omega_rad_s"=>omega_ref[j],"reference_velocity_m_per_s"=>omega_ref[j]*sref[j],
        "cubic_stiffness_N_per_m3"=>k3[j],
        "damping_carrier_rad_s"=>carrier[j],"damping_cap_N_s_per_m"=>damping_cap[j],
        "saturation_speed_m_per_s"=>saturation_speed[j],
        "low_velocity_cubic_damping_N_s3_per_m3"=>damping_cap[j]/saturation_speed[j]^2)
        for (j,name) in enumerate(["mid_bending_ground","outer_bending_ground","mid_differential","outer_differential","mid_chord_ground","outer_chord_ground"])]
    cfg=NC.load_config(joinpath(root,"configs","releases","dataset21_naca_v3_partial.json"))
    initial_checks=Any[]
    for family in 1:11
        modes=cfg["initial_conditions"]["families"][family]
        fractions=length(modes)==1 ? [1.] : length(modes)==2 ? [0.5,0.5] : [0.1,0.2,0.3,0.4]
        shape=model.modes[:,modes]*(sqrt.(2 .* fractions)./model.omega[modes])
        e2=dot(shape,model.K*shape)/2
        e4=sum(k3 .* (transpose(B)*shape).^4)/4
        @assert e4>0
        for ratio in (0.025,0.10,0.25)
            scale=sqrt(ratio*e2/e4);q=scale*shape
            d=NC.evaluate!(NC.CPUBackend(model),model,q;tangent=false)
            push!(initial_checks,Dict("family"=>family,"target_added_potential_ratio"=>ratio,
                "maximum_translation_mm"=>1000*NC.amplitude(model,q),
                "initial_strain_component"=>d.strain,
                "initial_strain_screen_passed"=>d.strain<=0.001,
                "port_extensions_mm"=>1000transpose(B)*q))
        end
    end
    proposal=Dict("status"=>"proposal_linear_calibration_only_no_time_integration",
        "model_sha256"=>NC.filehash(modelpath),"state_dimension"=>2nq,
        "patches"=>patches,"ports"=>ports,"compliance_m_per_N"=>[collect(row) for row in eachrow(compliance)],
        "modal_port_participation"=>[collect(row) for row in eachrow(participation)],
        "stiffness_force_ratio_at_reference"=>stiffness_ratio,
        "damping_reference_ratio"=>damping_reference_ratio,
        "damping_law"=>"d_j(w)=damping_cap_j*w^3/(w^2+saturation_speed_j^2)",
        "initial_algebraic_checks"=>initial_checks,
        "note"=>"Fixed-direction generalized patch connectors, not axial springs following current endpoint geometry. No hidden DOFs or rigid patch constraints. No dynamical nonlinear-strength qualification is claimed.")
    folder=joinpath(root,"runs","naca_connector_design")
    NC.writejson(joinpath(folder,"proposal_calibration.json"),proposal)
    NC.JLD2.jldsave(joinpath(folder,"patch_operators.jld2");B=sparse(B),P=sparse(P))
    println("CONNECTOR_DESIGN_LINEAR_CALIBRATION nq=",nq," states=",2nq," ports=6")
    println(NC.JSON.json(ports))
    println("INITIAL_ALGEBRAIC_CHECKS passed=",count(r->r["initial_strain_screen_passed"],initial_checks),"/",length(initial_checks))
end
main()
