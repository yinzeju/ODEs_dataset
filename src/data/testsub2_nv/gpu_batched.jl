module GPUBatched

using CUDA

function forward_kernel!(Y,A,X,n,nb)
    i=(blockIdx().x-1)*32+threadIdx().x
    b=(blockIdx().y-1)*4+threadIdx().y
    if i<=n && b<=nb
        value=0.
        @inbounds for j in 1:n
            value=muladd(A[i,j],X[j,b],value)
        end
        @inbounds Y[i,b]=value
    end
    return
end

function transpose_kernel!(Y,A,X,n,nb)
    lane=threadIdx().x
    j=(blockIdx().x-1)*4+threadIdx().y
    b=blockIdx().y
    if j<=n
        value=0.
        @inbounds for i in lane:32:n
            value=muladd(A[i,j],X[i,b],value)
        end
        for offset in (16,8,4,2,1)
            value+=shfl_down_sync(0xffffffff,value,offset)
        end
        if lane==1;@inbounds Y[j,b]=value;end
    end
    return
end

function forward!(Y,A,X)
    n,nb=size(X)
    @cuda threads=(32,4) blocks=(cld(n,32),cld(nb,4)) forward_kernel!(Y,A,X,n,nb)
    return Y
end

function transpose!(Y,A,X)
    n,nb=size(X)
    @cuda threads=(32,4) blocks=(cld(n,4),nb) transpose_kernel!(Y,A,X,n,nb)
    return Y
end

end
