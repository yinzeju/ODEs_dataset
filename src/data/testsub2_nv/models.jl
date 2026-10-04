struct DuffingKernel
    alpha::Float64
end

struct BeamPoint
    index::NTuple{6,Int}
    axial::NTuple{6,Float64}
    slope::NTuple{6,Float64}
    weightEA::Float64
end

struct ShellPoint
    index::NTuple{18,Int}
    B::Matrix{Float64}
    G::Matrix{Float64}
    D::Matrix{Float64}
end

struct MechanicalModel{F}
    id::String
    configuration::String
    n::Int
    M::SparseMatrixCSC{Float64,Int}
    C::SparseMatrixCSC{Float64,Int}
    K::SparseMatrixCSC{Float64,Int}
    kernel::F
    omega::Vector{Float64}
    modes::Matrix{Float64}
    qscale::Vector{Float64}
    reference_mode::Int
    probe::Int
    translations::Vector{Int}
    active::Vector{Int}
    nodes::Matrix{Float64}
    mesh::Matrix{Int}
    metadata::Dict{String,Any}
end

function reference_modes(M,K)
    eig=eigen(Symmetric(Matrix(K)),Symmetric(Matrix(M)))
    minimum(eig.values)>0 || error("Nonpositive elastic mode")
    phi=eig.vectors
    for j in axes(phi,2)
        k=argmax(abs.(view(phi,:,j)))
        phi[k,j]<0 && (phi[:,j] .*= -1)
    end
    return sqrt.(eig.values),phi
end

function duffing_model()
    n=8; M=spdiagm(0=>ones(n)); C=0.02M
    K=spdiagm(-1=>fill(-0.2,n-1),0=>fill(1.4,n),1=>fill(-0.2,n-1))
    omega,phi=reference_modes(M,K)
    meta=Dict{String,Any}("mass"=>1.,"viscosity"=>0.02,"ground_stiffness"=>1.,
        "coupling_stiffness"=>0.2,"cubic_stiffness"=>0.1,"units"=>"dimensionless",
        "mesh_id"=>"fixed_end_chain_8","damping"=>"C=0.02 I")
    MechanicalModel("OSC-DUFFING8","BASE",n,M,C,K,DuffingKernel(0.1),omega,phi,
        ones(n),1,1,collect(1:n),collect(1:n),zeros(0,0),zeros(Int,0,0),meta)
end

function assemble_local!(I,J,V,index,A)
    for j in eachindex(index), i in eachindex(index)
        ii,jj=index[i],index[j]
        if ii>0 && jj>0
            push!(I,ii); push!(J,jj); push!(V,A[i,j])
        end
    end
end

function beam_model(;elements=12)
    E=70e9;rho=2700.;L=1.;b=0.05;h=0.02;A=b*h;inertia=b*h^3/12
    total=3(elements+1);active=collect(4:total-3);n=length(active)
    inverse=zeros(Int,total);inverse[active].=1:n
    M=zeros(n,n);K=zeros(n,n);points=BeamPoint[];ell=L/elements
    gauss=(0.046910077030668,0.2307653449471585,0.5,0.7692346550528415,0.953089922969332)
    weights=(0.1184634425280945,0.239314335249683,0.2844444444444444,0.239314335249683,0.1184634425280945)
    for e in 1:elements
        index=ntuple(i->inverse[3(e-1)+i],6)
        axial=(-1/ell,0.,0.,1/ell,0.,0.)
        for (r,w) in zip(gauss,weights)
            slope=(0.,(-6r+6r^2)/ell,1-4r+3r^2,0.,(6r-6r^2)/ell,-2r+3r^2)
            curve=(0.,(-6+12r)/ell^2,(-4+6r)/ell,0.,(6-12r)/ell^2,(-2+6r)/ell)
            nu=(1-r,0.,0.,r,0.,0.)
            nw=(0.,1-3r^2+2r^3,ell*(r-2r^2+r^3),0.,3r^2-2r^3,ell*(-r^2+r^3))
            for j in 1:6,i in 1:6
                ii,jj=index[i],index[j]; ii*jj==0 && continue
                M[ii,jj]+=rho*A*ell*w*(nu[i]*nu[j]+nw[i]*nw[j])
                K[ii,jj]+=ell*w*(E*A*axial[i]*axial[j]+E*inertia*curve[i]*curve[j])
            end
            push!(points,BeamPoint(index,axial,slope,E*A*ell*w))
        end
    end
    Ms,Ks=sparse(M),sparse(K);C=(1e6/E)*Ks
    omega,phi=reference_modes(Ms,Ks)
    nodes=hcat(collect(range(0,L,length=elements+1)),zeros(elements+1))
    mesh=hcat(collect(1:elements),collect(2:elements+1))
    translations=findall(i->mod1(i,3)!=3,active)
    meta=Dict{String,Any}("E_Pa"=>E,"density_kg_m3"=>rho,"length_m"=>L,
        "width_m"=>b,"thickness_m"=>h,"element_count"=>elements,
        "mesh_id"=>"hermite_linear_cc_$(elements)","damping"=>"C=(1e6/E)K",
        "material_damping_modulus_Pa_s"=>1e6,"units"=>"SI; axial/transverse m, slope rad")
    MechanicalModel("VK-BEAM-CC","FE12",n,Ms,C,Ks,points,omega,phi,
        fill(h,n),1,inverse[3div(elements,2)+2],translations,active,nodes,mesh,meta)
end

function rectangular_mesh(nx,ny,width,length,curvature)
    nodes=zeros((nx+1)*(ny+1),3)
    radius=curvature==0 ? Inf : (curvature^2+(length/2)^2)/(2curvature)
    for j in 0:ny,i in 0:nx
        row=j*(nx+1)+i+1;x=width*i/nx;y=length*(1-j/ny)
        # Remove only the reference code's constant vertical translation.
        z=curvature==0 ? 0. : sqrt(radius^2-(y-length/2)^2)-sqrt(radius^2-(length/2)^2)
        nodes[row,:]=[x,y,z]
    end
    mesh=zeros(Int,2nx*ny,3);e=0
    for j in 0:ny-1,i in 1:nx
        a=j*(nx+1)+i;bb=(j+1)*(nx+1)+i
        mesh[e+1,:]=[a,bb+1,a+1];mesh[e+2,:]=[a,bb,bb+1];e+=2
    end
    return nodes,mesh
end

function shell_model(configuration;divisions=10)
    plate=configuration=="PLATE";nx=divisions;ny=plate ? nx : 2nx
    width=1.;L=plate ? 1. : 2.;h=0.01;E=70e9;rho=2700.;nu=0.33
    curvature=plate ? 0. : configuration=="NR" ? 0.1 : 0.041
    nodes,mesh=rectangular_mesh(nx,ny,width,L,curvature)
    boundary=findall(i->(i<=nx+1 || i>ny*(nx+1) ||
        (plate && (mod1(i,nx+1) in (1,nx+1)))),axes(nodes,1))
    fixed=sort!([6(i-1)+d for i in boundary for d in 1:3])
    active=setdiff(collect(1:6size(nodes,1)),fixed);n=length(active)
    inverse=zeros(Int,6size(nodes,1));inverse[active].=1:n
    mi=Int[];mj=Int[];mv=Float64[];ki=Int[];kj=Int[];kv=Float64[]
    points=ShellPoint[]
    for triangle in eachrow(mesh)
        Me,Ke,B,G,D=shell_element(nodes[triangle,:],E,nu,rho,h)
        index=ntuple(i->inverse[6(triangle[cld(i,6)]-1)+mod1(i,6)],18)
        assemble_local!(mi,mj,mv,index,Me);assemble_local!(ki,kj,kv,index,Ke)
        push!(points,ShellPoint(index,B,G,D))
    end
    M=sparse(mi,mj,mv,n,n);K=sparse(ki,kj,kv,n,n)
    M=(M+M')/2;K=(K+K')/2;dropzeros!(M);dropzeros!(K)
    omega,phi=reference_modes(M,K)
    if plate
        am,ak=1.,4e-6
    else
        am,ak=[1/omega[1] omega[1];1/omega[2] omega[2]]\[0.004,0.004]
    end
    C=am*M+ak*K
    target=plate ? [0.2,0.3] : [0.5,0.5]
    node=argmin([sum(abs2,nodes[i,1:2]-target) for i in axes(nodes,1)])
    probe=inverse[6(node-1)+3]
    translations=findall(i->mod1(i,6)<=3,active)
    meta=Dict{String,Any}("E_Pa"=>E,"density_kg_m3"=>rho,"poisson_ratio"=>nu,
        "length_m"=>L,"width_m"=>width,"thickness_m"=>h,"curvature_m"=>curvature,
        "element_count"=>size(mesh,1),"mesh_id"=>"allman_$(nx)x$(ny)_$(configuration)",
        "mass_form"=>"reference Allman diagonal element mass, rotated and assembled",
        "damping"=>"C=a_M M+a_K K","rayleigh_mass"=>am,"rayleigh_stiffness"=>ak,
        "nonlinear_shear"=>"w_x*w_y+u_x*u_y+v_x*v_y; source v1.1",
        "vertical_origin"=>"boundary plane z=0; constant translation of source geometry",
        "units"=>"SI; translations m, rotations rad")
    MechanicalModel(plate ? "VK-PLATE-SQUARE" : "VK-SHELL-SHALLOW",
        plate ? "FE200" : configuration,n,M,C,K,points,omega,phi,fill(h,n),
        plate ? 2 : 1,probe,translations,active,nodes,mesh,meta)
end

@inline function localdot(a,index,q)
    value=0.
    @inbounds for i in eachindex(index)
        k=index[i];k>0 && (value+=a[i]*q[k])
    end
    value
end

function nonlinear!(f,k::DuffingKernel,q)
    @. f=k.alpha*q^3
    return sum(abs2,q.^2)*k.alpha/4
end

function nonlinear!(f,points::Vector{BeamPoint},q)
    fill!(f,0.);potential=0.
    @inbounds for p in points
        a=localdot(p.axial,p.index,q);b=localdot(p.slope,p.index,q)
        potential+=p.weightEA*(a*b*b/2+b^4/8)
        for i in 1:6
            ii=p.index[i];ii==0 && continue
            f[ii]+=p.weightEA*(p.axial[i]*b*b/2+p.slope[i]*(a*b+b^3/2))
        end
    end
    return potential
end

@inline function shell_strain(p,q)
    g=ntuple(a->localdot(view(p.G,a,:),p.index,q),6)
    e=ntuple(a->localdot(view(p.B,a,:),p.index,q),3)
    z=(g[5]^2/2,g[6]^2/2,g[5]*g[6]+g[1]*g[2]+g[3]*g[4])
    return g,e,z
end

@inline function nonlinear_gradient(p,g,i)
    G=p.G
    (g[5]*G[5,i],g[6]*G[6,i],g[6]*G[5,i]+g[5]*G[6,i]+
        g[2]*G[1,i]+g[1]*G[2,i]+g[4]*G[3,i]+g[3]*G[4,i])
end

function nonlinear!(f,points::Vector{ShellPoint},q)
    fill!(f,0.);potential=0.
    @inbounds for p in points
        g,e,z=shell_strain(p,q)
        dz=ntuple(a->sum(p.D[a,b]*z[b] for b in 1:3),3)
        stress=ntuple(a->sum(p.D[a,b]*(e[b]+z[b]) for b in 1:3),3)
        potential+=sum((e[a]+z[a]/2)*dz[a] for a in 1:3)
        for i in 1:18
            ii=p.index[i];ii==0 && continue
            bnl=nonlinear_gradient(p,g,i)
            f[ii]+=sum(p.B[a,i]*dz[a]+bnl[a]*stress[a] for a in 1:3)
        end
    end
    return potential
end

function tangent_nonlinear!(K,k::DuffingKernel,q)
    fill!(nonzeros(K),0.)
    for i in eachindex(q);K[i,i]=3k.alpha*q[i]^2;end
end

function tangent_nonlinear!(K,points::Vector{BeamPoint},q)
    fill!(nonzeros(K),0.)
    @inbounds for p in points
        a=localdot(p.axial,p.index,q);b=localdot(p.slope,p.index,q)
        for j in 1:6,i in 1:6
            ii,jj=p.index[i],p.index[j];ii*jj==0 && continue
            K[ii,jj]+=p.weightEA*(b*(p.axial[i]*p.slope[j]+p.slope[i]*p.axial[j])+
                (a+1.5b*b)*p.slope[i]*p.slope[j])
        end
    end
end

function tangent_nonlinear!(K,points::Vector{ShellPoint},q)
    fill!(nonzeros(K),0.)
    @inbounds for p in points
        g,e,z=shell_strain(p,q)
        stress=ntuple(a->sum(p.D[a,b]*(e[b]+z[b]) for b in 1:3),3)
        for j in 1:18
            jj=p.index[j];jj==0 && continue
            nj=nonlinear_gradient(p,g,j)
            dn=ntuple(a->sum(p.D[a,b]*nj[b] for b in 1:3),3)
            dt=ntuple(a->sum(p.D[a,b]*(p.B[b,j]+nj[b]) for b in 1:3),3)
            for i in 1:18
                ii=p.index[i];ii==0 && continue
                ni=nonlinear_gradient(p,g,i);G=p.G
                s3=G[5,i]*G[6,j]+G[6,i]*G[5,j]+G[1,i]*G[2,j]+G[2,i]*G[1,j]+
                    G[3,i]*G[4,j]+G[4,i]*G[3,j]
                K[ii,jj]+=sum(p.B[a,i]*dn[a]+ni[a]*dt[a] for a in 1:3)+
                    stress[1]*G[5,i]*G[5,j]+stress[2]*G[6,i]*G[6,j]+stress[3]*s3
            end
        end
    end
end

function potential(m,q)
    f=zeros(m.n)
    return dot(q,m.K*q)/2+nonlinear!(f,m.kernel,q)
end

function static_release(m,amplitude)
    q=zeros(m.n);f=zeros(m.n);Knl=copy(m.K);load=0.
    # Displacement-controlled continuation solves the unknown static point load.
    for target in range(amplitude/10,amplitude,length=10)
        for iteration in 1:35
            nonlinear!(f,m.kernel,q);f .+= m.K*q;f[m.probe]-=load
            tangent_nonlinear!(Knl,m.kernel,q)
            p=sparse([m.probe],[1],[1.],m.n,1)
            J=[m.K+Knl -p;p' spzeros(1,1)]
            delta=J\(-vcat(f,q[m.probe]-target))
            q .+= view(delta,1:m.n);load+=delta[end]
            if norm(view(delta,1:m.n)./m.qscale)<1e-11;break;end
            iteration==35 && error("Static continuation did not converge")
        end
    end
    nonlinear!(f,m.kernel,q);f .+= m.K*q;f[m.probe]-=load
    residual=norm(f)/max(abs(load),1.)
    residual<1e-8 || error("Static equilibrium residual $residual")
    return q,load,residual
end
