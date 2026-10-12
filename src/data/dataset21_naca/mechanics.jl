# SPDX-License-Identifier: GPL-3.0-only
struct ShellElement
    index::NTuple{18,Int}
    B::Matrix{Float64}
    G::Matrix{Float64}
    D::Matrix{Float64}
    bending_recovery::Vector{Matrix{Float64}}
    membrane_recovery::Vector{Matrix{Float64}}
end
struct WingModel
    mesh::WingMesh
    active::Vector{Int}
    elements::Vector{ShellElement}
    slots::Matrix{Int32}
    M::SparseMatrixCSC{Float64,Int}
    K::SparseMatrixCSC{Float64,Int}
    C::SparseMatrixCSC{Float64,Int}
    omega::Vector{Float64}
    modes::Matrix{Float64}
    aM::Float64
    aK::Float64
    qscale::Vector{Float64}
end

function assemble(mesh::WingMesh,cfg)
    println("NACA_ASSEMBLY_BEGIN elements=",size(mesh.triangles,1)," nodes=",size(mesh.nodes,1));flush(stdout)
    material=cfg["material"]; nfull=6size(mesh.nodes,1)
    fixed=Set(6(i-1)+d for i in mesh.fixed_nodes for d in 1:6)
    active=[i for i in 1:nfull if !(i in fixed)]
    reduced=zeros(Int,nfull);reduced[active]=1:length(active)
    elements=ShellElement[];localM=Matrix{Float64}[];localK=Matrix{Float64}[]
    I=Int[];J=Int[]
    for tri in eachrow(mesh.triangles)
        M,K,B,G,D,Rb,Rm=shell_element(mesh.nodes[tri,:],material["E"],material["nu"],material["rho"],material["thickness"])
        index=Tuple(reduced[6(i-1)+d] for i in tri for d in 1:6)
        push!(elements,ShellElement(index,B,G,D,Rb,Rm));push!(localM,M);push!(localK,K)
        for j in index,i in index
            if i>0 && j>0;push!(I,i);push!(J,j);end
        end
    end
    n=length(active);pattern=sparse(I,J,ones(length(I)),n,n)
    locations=Dict((rowvals(pattern)[p],j)=>p for j in 1:n for p in nzrange(pattern,j))
    M=copy(pattern);K=copy(pattern);fill!(nonzeros(M),0.);fill!(nonzeros(K),0.)
    slots=zeros(Int32,324,length(elements))
    for (e,el) in enumerate(elements),j in 1:18,i in 1:18
        a,b=el.index[i],el.index[j]
        if a>0 && b>0
            slot=locations[(a,b)];slots[i+18(j-1),e]=slot
            nonzeros(M)[slot]+=localM[e][i,j];nonzeros(K)[slot]+=localK[e][i,j]
        end
    end
    norm(M-M')/norm(M)<1e-11 || error("Mass symmetry")
    norm(K-K')/norm(K)<1e-11 || error("Stiffness symmetry")
    println("NACA_ASSEMBLY_MATRICES n_q=",n," stored_entries=",nnz(K));flush(stdout)
    cholesky(Symmetric(M));cholesky(Symmetric(K))
    nev=min(Int(cfg["mesh"]["modes"]),n-2)
    values,modes,nconv,_,_,_=Arpack.eigs(Symmetric(K),Symmetric(M);nev, sigma=0.,which=:LM,
        explicittransform=:none,ncv=min(n,max(4nev+1,48)),
        tol=1e-10,maxiter=3000,v0=randn(Xoshiro(20261011),n))
    nconv==nev || error("Incomplete reference spectrum")
    isreal(values) && isreal(modes) || error("Unexpected complex conservative modes")
    order=sortperm(real.(values));values=real.(values[order]);modes=real.(modes[:,order])
    minimum(values)>0 || error("Nonpositive mechanical eigenvalue")
    for j in axes(modes,2)
        modes[:,j]./=sqrt(dot(modes[:,j],M*modes[:,j]))
        signvalue=modes[argmax(abs.(modes[:,j])),j]
        modes[:,j].*=sign(signvalue)
        norm(K*modes[:,j]-values[j]*M*modes[:,j])/norm(K*modes[:,j])<1e-7 || error("Eigenpair residual")
    end
    omega=sqrt.(values);zeta=cfg["damping"]["target_ratio"]
    println("NACA_MODES n_q=",n," omega=",omega[1:min(4,end)]);flush(stdout)
    aM=2zeta*omega[1]*omega[2]/(omega[1]+omega[2]);aK=2zeta/(omega[1]+omega[2])
    C=copy(K);nonzeros(C).=aM.*nonzeros(M).+aK.*nonzeros(K)
    span=maximum(mesh.nodes[:,3])-minimum(mesh.nodes[:,3])
    qscale=[mod1(i,6)<=3 ? span : 1. for i in active]
    return WingModel(mesh,active,elements,slots,M,K,C,omega,modes,aM,aK,qscale)
end

struct CPUBackend
    force::Vector{Float64}
    tangent::SparseMatrixCSC{Float64,Int}
end
CPUBackend(m::WingModel)=CPUBackend(zeros(length(m.active)),copy(m.K))

"""Source-equivalent membrane strain correction and its first derivative."""
function element_quantities(el,q)
    qe=[i==0 ? 0. : q[i] for i in el.index]
    g=el.G*qe;linear=el.B*qe
    z=[g[5]^2/2,g[6]^2/2,g[5]*g[6]+g[1]*g[2]+g[3]*g[4]]
    N=zeros(3,18)
    @inbounds for j in 1:18
        N[1,j]=g[5]*el.G[5,j];N[2,j]=g[6]*el.G[6,j]
        N[3,j]=g[6]*el.G[5,j]+g[5]*el.G[6,j]+g[2]*el.G[1,j]+g[1]*el.G[2,j]+
            g[4]*el.G[3,j]+g[3]*el.G[4,j]
    end
    return g,linear,z,N
end

function evaluate!(backend::CPUBackend,m,q; tangent=true,linear=false)
    fill!(backend.force,0.); tangent && fill!(nonzeros(backend.tangent),0.)
    linear && return (energy=0.,strain=0.)
    energy=0.;strain=0.
    for (e,el) in enumerate(m.elements)
        g,b,z,N=element_quantities(el,q)
        stress=el.D*(b+z);Dz=el.D*z
        force=el.B'*Dz+N'*stress
        energy+=dot(b+z/2,Dz)
        qe=[i==0 ? 0. : q[i] for i in el.index]
        for (Rb,Rm) in zip(el.bending_recovery,el.membrane_recovery)
            curvature=Rb*qe
            membrane=b+z+Rm*qe
            strain=max(strain,maximum(abs,membrane+curvature),maximum(abs,membrane-curvature))
        end
        for i in 1:18
            a=el.index[i];a==0 && continue
            backend.force[a]+=force[i]
        end
        if tangent
            Q=el.B+N;Ke=Q'*el.D*Q-el.B'*el.D*el.B
            @inbounds for j in 1:18,i in 1:18
                slot=m.slots[i+18(j-1),e];slot==0 && continue
                G=el.G
                value=Ke[i,j]+stress[1]*G[5,i]*G[5,j]+stress[2]*G[6,i]*G[6,j]+
                    stress[3]*(G[5,i]*G[6,j]+G[6,i]*G[5,j]+G[1,i]*G[2,j]+
                    G[2,i]*G[1,j]+G[3,i]*G[4,j]+G[4,i]*G[3,j])
                nonzeros(backend.tangent)[slot]+=value
            end
        end
    end
    return (;energy,strain)
end

function potential(m,q)
    b=CPUBackend(m);diagnostic=evaluate!(b,m,q;tangent=false)
    return dot(q,m.K*q)/2+diagnostic.energy
end
function full_coordinates(m,q)
    full=zeros(6size(m.mesh.nodes,1));full[m.active]=q;return full
end
function amplitude(m,q)
    full=reshape(full_coordinates(m,q),6,:)
    return maximum(sqrt(sum(abs2,view(full,1:3,j))) for j in axes(full,2))
end

function preload(m)
    # Unit-total distributed y load over the final 10% of skin (physical group 1).
    full=zeros(6size(m.mesh.nodes,1));tip=maximum(m.mesh.nodes[:,3])
    for (e,tri) in enumerate(eachrow(m.mesh.triangles))
        m.mesh.domains[e]==1 || continue
        xyz=m.mesh.nodes[tri,:];mean(xyz[:,3])>=0.9tip || continue
        area=norm(cross(xyz[2,:]-xyz[1,:],xyz[3,:]-xyz[1,:]))/2
        for i in tri;full[6(i-1)+2]+=area/3;end
    end
    f=full[m.active];sum(f)>0 || error("Empty tip preload selection")
    return f/sum(f)
end

function static_release(m,target,cfg;trace=nothing)
    b=CPUBackend(m);f=preload(m);qlinear=m.K\f
    load=target/amplitude(m,qlinear);q=qlinear*load
    absolute_stiffness=abs.(m.K)
    for _ in 1:20
        converged=false
        for iteration in 1:cfg["solver"]["newton_max_iterations"]
            evaluate!(b,m,q)
            residual=m.K*q+b.force-load*f
            step=(m.K+b.tangent)\residual
            # Thin-shell stiffness cancellation makes the former absolute
            # residual target smaller than Float64 roundoff. Require BOTH a
            # roundoff-aware force balance and a small displacement correction.
            force_tolerance=1e-10*max(norm(load*f),1.)+
                8eps(Float64)*norm(absolute_stiffness*abs.(q))
            correction_relative=norm(step./m.qscale)/max(norm(q./m.qscale),eps())
            if norm(residual)<=force_tolerance && correction_relative<=1e-9
                converged=true
                trace===nothing || push!(trace,Dict("iterations"=>iteration,
                    "force_residual_norm"=>norm(residual),"force_tolerance"=>force_tolerance,
                    "correction_relative"=>correction_relative,"load_N"=>load))
                break
            end
            accepted=false
            for weight in (1.,0.5,0.25,0.125,0.0625)
                trial=q-weight*step;evaluate!(b,m,trial;tangent=false)
                if norm(m.K*trial+b.force-load*f)<norm(residual)
                    q=trial;accepted=true;break
                end
            end
            accepted || error("Static Newton line search failed")
        end
        converged || error("Static Newton convergence")
        observed=amplitude(m,q)
        abs(observed/target-1)<1e-6 && return q,load
        factor=clamp(target/observed,0.5,2.);load*=factor;q*=factor
    end
    error("Static release amplitude did not converge")
end
