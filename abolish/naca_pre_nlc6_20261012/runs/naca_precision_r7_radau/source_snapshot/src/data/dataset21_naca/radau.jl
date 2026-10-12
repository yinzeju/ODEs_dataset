# SPDX-License-Identifier: GPL-3.0-only
# Three-stage Radau IIA collocation of the unchanged full mechanical equations.
# Reference: Hairer & Wanner, JCAM 111 (1999), 93-111.
# https://www.unige.ch/~hairer/preprints/coimbra.html
# The complex transform is only across THREE time stages, never mechanical modes.

struct RadauSystem{R,C}
    real_factor::R
    complex_factor::C
end
function RadauSystem(m::WingModel,h::Real,roots)
    real_shift=real(roots[1])/h;complex_shift=roots[2]/h
    real_matrix=m.K+real_shift*m.C+real_shift^2*m.M
    complex_matrix=m.K+complex_shift*m.C+complex_shift^2*m.M
    return RadauSystem(cholesky(Symmetric(real_matrix)),lu(complex_matrix))
end

struct RadauCache{S}
    systems::Dict{Float64,S}
    inverse_A::Matrix{Float64}
    transform::Matrix{ComplexF64}
    inverse_transform::Matrix{ComplexF64}
    roots::Vector{ComplexF64}
    nodes::Vector{Float64}
    weights::Vector{Float64}
    scale::Vector{Float64}
end
function radau_tableau()
    r=sqrt(6.)
    A=[(88-7r)/360 (296-169r)/1800 (-2+3r)/225;
       (296+169r)/1800 (88+7r)/360 (-2-3r)/225;
       (16-r)/36 (16+r)/36 1/9]
    return A,[(4-r)/10,(4+r)/10,1.],Vector(A[3,:])
end
function RadauCache(m::WingModel,h::Real)
    A,nodes,weights=radau_tableau();inverse_A=inv(A)
    eig=eigen(inverse_A)
    ir=argmin(abs.(imag.(eig.values)));ic=argmax(imag.(eig.values))
    transform=hcat(complex.(real.(eig.vectors[:,ir])),eig.vectors[:,ic],conj.(eig.vectors[:,ic]))
    roots=ComplexF64[real(eig.values[ir]),eig.values[ic],conj(eig.values[ic])]
    inverse_transform=inv(transform)
    norm(inverse_A*transform-transform*Diagonal(roots))<1e-12 || error("Radau stage transform")
    system=RadauSystem(m,h,roots)
    return RadauCache(Dict(Float64(h)=>system),inverse_A,transform,inverse_transform,
        roots,nodes,weights,Vector(max.(abs.(diag(m.K)).*m.qscale,1.)))
end

function radau_residual(m,backend,q,v,Z,h,cache;linear=false)
    # Store increments directly to avoid cancellation when recovering velocities.
    Q=q .+ Z
    V=(Z*transpose(cache.inverse_A))/h
    W=((V .- v)*transpose(cache.inverse_A))/h
    residual=m.M*W+m.C*V+m.K*Q
    for stage in 1:3
        evaluate!(backend,m,view(Q,:,stage);tangent=false,linear)
        @views residual[:,stage].+=backend.force
    end
    return residual,V,W
end

function radau_chord_correction(residual,system,cache)
    transformed=residual*transpose(cache.inverse_transform)
    correction=similar(transformed)
    correction[:,1]=system.real_factor\real.(transformed[:,1])
    correction[:,2]=system.complex_factor\transformed[:,2]
    correction[:,3]=conj.(correction[:,2])
    return real.(correction*transpose(cache.transform))
end

function radau_consistent_correction(m,backend,q,Z,h,cache,residual;linear=false)
    blocks=SparseMatrixCSC{Float64,Int}[]
    for stage in 1:3
        evaluate!(backend,m,q+Z[:,stage];tangent=true,linear)
        push!(blocks,m.K+backend.tangent)
    end
    stage_matrix=kron(sparse(cache.inverse_A^2/h^2),m.M)+
        kron(sparse(cache.inverse_A/h),m.C)+blockdiag(blocks...)
    return reshape(stage_matrix\vec(residual),length(q),3)
end

function radau_step(m,backend,q,v,h,solver,statistics,cache;linear=false)
    system=get!(cache.systems,h) do
        RadauSystem(m,h,cache.roots)
    end
    Z=h.*v.*transpose(cache.nodes)
    consistent=false;tolerance=solver["newton_relative_tolerance"]
    for iteration in 1:solver["newton_max_iterations"]
        residual,V,W=radau_residual(m,backend,q,v,Z,h,cache;linear)
        errornorm=maximum(abs,residual./cache.scale)
        if errornorm<=tolerance
            statistics.steps+=1;statistics.newton_iterations+=iteration-1
            statistics.max_residual=max(statistics.max_residual,errornorm)
            work=0.
            for stage in 1:3
                velocity=view(V,:,stage)
                work+=h*cache.weights[stage]*dot(velocity,m.C*velocity)
            end
            return q+Z[:,3],V[:,3],W[:,3],work
        end
        correction=if consistent
            statistics.consistent_factorizations+=1
            radau_consistent_correction(m,backend,q,Z,h,cache,residual;linear)
        else
            statistics.chord_corrections+=1
            radau_chord_correction(residual,system,cache)
        end
        all(isfinite,correction) || error("Radau Newton nonfinite correction")
        accepted=false
        for weight in (1.,0.5,0.25,0.125,0.0625,0.03125)
            trial=Z-weight*correction
            trial_residual,_,_=radau_residual(m,backend,q,v,trial,h,cache;linear)
            if maximum(abs,trial_residual./cache.scale)<errornorm
                Z=trial;accepted=true;break
            end
        end
        if !accepted && !consistent
            consistent=true;continue
        end
        accepted || error("Radau Newton line search failed")
        iteration>=get(solver,"maximum_chord_iterations",10) && !linear && (consistent=true)
    end
    error("Radau Newton did not converge")
end

function radau_advance(m,backend,q,v,a,h,solver,statistics,cache;linear=false,depth=0)
    try
        return radau_step(m,backend,q,v,h,solver,statistics,cache;linear)
    catch exception
        exception isa InterruptException && rethrow()
        retryable=exception isa ErrorException && startswith(exception.msg,"Radau Newton")
        retryable && depth<solver["maximum_bisections"] || rethrow()
        statistics.subdivisions+=1
        qh,vh,ah,d1=radau_advance(m,backend,q,v,a,h/2,solver,statistics,cache;linear,depth=depth+1)
        q1,v1,a1,d2=radau_advance(m,backend,qh,vh,ah,h/2,solver,statistics,cache;linear,depth=depth+1)
        return q1,v1,a1,d1+d2
    end
end
