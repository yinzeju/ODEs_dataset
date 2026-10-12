# SPDX-License-Identifier: GPL-3.0-only
# Included explicitly by the execution entry point only after --execute.
using CUDA

struct GPUBackend
    index::CuMatrix{Int32}
    B::CuArray{Float64,3}
    G::CuArray{Float64,3}
    D::CuArray{Float64,3}
    slots::CuMatrix{Int32}
    q::CuVector{Float64}
    device_force::CuVector{Float64}
    device_tangent::CuVector{Float64}
    force::Vector{Float64}
    tangent::SparseMatrixCSC{Float64,Int}
end

function GPUBackend(m::WingModel)
    CUDA.functional() || error("CUDA is not functional")
    CUDA.allowscalar(false)
    ne=length(m.elements);n=length(m.active)
    indices=zeros(Int32,18,ne);B=zeros(3,18,ne);G=zeros(6,18,ne);D=zeros(3,3,ne)
    for (e,el) in enumerate(m.elements)
        indices[:,e].=el.index;B[:,:,e]=el.B;G[:,:,e]=el.G;D[:,:,e]=el.D
    end
    return GPUBackend(CuArray(indices),CuArray(B),CuArray(G),CuArray(D),CuArray(m.slots),
        CUDA.zeros(Float64,n),CUDA.zeros(Float64,n),CUDA.zeros(Float64,nnz(m.K)),zeros(n),copy(m.K))
end

@inline function gpu_gradient(G,i,e,g1,g2,g3,g4,g5,g6)
    @inbounds return (g5*G[5,i,e],g6*G[6,i,e],g6*G[5,i,e]+g5*G[6,i,e]+
        g2*G[1,i,e]+g1*G[2,i,e]+g4*G[3,i,e]+g3*G[4,i,e])
end

function naca_element_kernel!(force,tangent,q,indices,B,G,D,slots,ne,with_tangent)
    e=(blockIdx().x-1)*blockDim().x+threadIdx().x
    if e<=ne
        g1=0.;g2=0.;g3=0.;g4=0.;g5=0.;g6=0.;b1=0.;b2=0.;b3=0.
        @inbounds for j in 1:18
            k=indices[j,e]
            if k>0
                x=q[k]
                g1+=G[1,j,e]*x;g2+=G[2,j,e]*x;g3+=G[3,j,e]*x
                g4+=G[4,j,e]*x;g5+=G[5,j,e]*x;g6+=G[6,j,e]*x
                b1+=B[1,j,e]*x;b2+=B[2,j,e]*x;b3+=B[3,j,e]*x
            end
        end
        z=(g5*g5/2,g6*g6/2,g5*g6+g1*g2+g3*g4);b=(b1,b2,b3)
        @inbounds begin
            dz=ntuple(a->D[a,1,e]*z[1]+D[a,2,e]*z[2]+D[a,3,e]*z[3],3)
            stress=ntuple(a->dz[a]+D[a,1,e]*b1+D[a,2,e]*b2+D[a,3,e]*b3,3)
            for i in 1:18
                k=indices[i,e];k==0 && continue
                ni=gpu_gradient(G,i,e,g1,g2,g3,g4,g5,g6)
                value=0.
                for a in 1:3;value+=B[a,i,e]*dz[a]+ni[a]*stress[a];end
                CUDA.@atomic force[k]+=value
            end
            if with_tangent
                for j in 1:18,i in 1:18
                    slot=slots[i+18(j-1),e];slot==0 && continue
                    ni=gpu_gradient(G,i,e,g1,g2,g3,g4,g5,g6)
                    nj=gpu_gradient(G,j,e,g1,g2,g3,g4,g5,g6)
                    value=0.
                    for a in 1:3,c in 1:3
                        value+=D[a,c,e]*(B[a,i,e]*nj[c]+ni[a]*(B[c,j,e]+nj[c]))
                    end
                    value+=stress[1]*G[5,i,e]*G[5,j,e]+stress[2]*G[6,i,e]*G[6,j,e]+
                        stress[3]*(G[5,i,e]*G[6,j,e]+G[6,i,e]*G[5,j,e]+
                        G[1,i,e]*G[2,j,e]+G[2,i,e]*G[1,j,e]+G[3,i,e]*G[4,j,e]+G[4,i,e]*G[3,j,e])
                    CUDA.@atomic tangent[slot]+=value
                end
            end
        end
    end
    return
end

function evaluate!(backend::GPUBackend,m,q;tangent=true,linear=false)
    if linear
        fill!(backend.force,0.);tangent && fill!(nonzeros(backend.tangent),0.)
        return (energy=0.,strain=0.)
    end
    copyto!(backend.q,q);fill!(backend.device_force,0.)
    tangent && fill!(backend.device_tangent,0.)
    ne=length(m.elements)
    @cuda threads=128 blocks=cld(ne,128) naca_element_kernel!(backend.device_force,
        backend.device_tangent,backend.q,backend.index,backend.B,backend.G,backend.D,backend.slots,ne,tangent)
    copyto!(backend.force,backend.device_force)
    tangent && copyto!(nonzeros(backend.tangent),backend.device_tangent)
    # CPU computes independent physical diagnostics at output frames.
    return (energy=NaN,strain=NaN)
end

function benchmark_gpu(m,q,cfg)
    cpu=CPUBackend(m);gpu=GPUBackend(m)
    evaluate!(cpu,m,q);evaluate!(gpu,m,q) # Compilation excluded from timing.
    force_error=norm(cpu.force-gpu.force)/max(norm(cpu.force),eps())
    tangent_error=norm(nonzeros(cpu.tangent)-nonzeros(gpu.tangent))/max(norm(nonzeros(cpu.tangent)),eps())
    tolerance=cfg["qualification"]["cpu_gpu_relative_tolerance"]
    force_error<tolerance && tangent_error<tolerance || error("NACA CPU/GPU parity failed")
    cpu_times=Float64[];gpu_times=Float64[]
    for _ in 1:cfg["compute"]["benchmark_repeats"]
        push!(cpu_times,@elapsed evaluate!(cpu,m,q))
        push!(gpu_times,@elapsed evaluate!(gpu,m,q))
    end
    function short_rollout(backend,count)
        position=copy(q);velocity=zeros(length(q));evaluate!(backend,m,position;tangent=false)
        acceleration=-(m.M\(m.K*position+backend.force));statistics=StepStatistics()
        h=cfg["sampling"]["dt_seconds"]/cfg["solver"]["substeps"]
        elapsed=@elapsed for _ in 1:count
            position,velocity,acceleration,_=advance(m,backend,position,velocity,acceleration,h,cfg["solver"],statistics)
        end
        return elapsed,vcat(position,velocity)
    end
    short_rollout(cpu,1);short_rollout(gpu,1)
    tc,xc=short_rollout(cpu,8);tg,xg=short_rollout(gpu,8)
    scaled=vcat(m.qscale,m.omega[1].*m.qscale)
    trajectory_error=norm((xc-xg)./scaled)/max(norm(xc./scaled),eps())
    trajectory_error<cfg["qualification"]["temporal_state_relative"]/10 || error("GPU benchmark trajectory parity")
    return gpu,Dict("force_error"=>force_error,"tangent_error"=>tangent_error,
        "cpu_seconds"=>median(cpu_times),"gpu_seconds_including_transfers"=>median(gpu_times),
        "newmark_cpu_seconds"=>tc,"newmark_gpu_seconds"=>tg,"short_trajectory_relative"=>trajectory_error,
        "device"=>CUDA.name(CUDA.device()),"precision"=>"Float64",
        "atomic_reproducibility"=>"tolerance-based; not guaranteed bitwise identical")
end
