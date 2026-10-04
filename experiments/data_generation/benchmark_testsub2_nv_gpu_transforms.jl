using CUDA, LinearAlgebra, JLD2
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","gpu_batched.jl"))

function measure(f;repeats=100)
    f();CUDA.synchronize()
    elapsed=@elapsed begin
        for k in 1:repeats;f();end
        CUDA.synchronize()
    end
    return elapsed/repeats
end

function main()
    BLAS.set_num_threads(1)
    root=normpath(joinpath(@__DIR__,"..",".."))
    m=load(joinpath(root,"runs","testsub2_nv","models","shell_nr.jld2"),"model")
    A=CuArray(m.modes);results=Any[]
    for nb in (1,7,18)
        x=reshape(sin.(collect(1:m.n*nb)),m.n,nb);X=CuArray(x);Y=similar(X)
        GPUBatched.forward!(Y,A,X);forward_error=norm(Array(Y)-m.modes*x)/norm(m.modes*x)
        GPUBatched.transpose!(Y,A,X);transpose_error=norm(Array(Y)-m.modes'*x)/norm(m.modes'*x)
        forward_error<1e-12 && transpose_error<1e-12 || error("Transform parity failed")
        record=Dict("batch"=>nb,"forward_relative_error"=>forward_error,"transpose_relative_error"=>transpose_error,
            "blas_forward_seconds"=>measure(()->mul!(Y,A,X)),
            "custom_forward_seconds"=>measure(()->GPUBatched.forward!(Y,A,X)),
            "blas_transpose_seconds"=>measure(()->mul!(Y,transpose(A),X)),
            "custom_transpose_seconds"=>measure(()->GPUBatched.transpose!(Y,A,X)))
        push!(results,record);println("GPU_TRANSFORM_BENCHMARK ",record);flush(stdout)
    end
    TestSub2NV.write_json(joinpath(root,"runs","testsub2_nv","gpu_transform_benchmark.json"),Dict("results"=>results))
end
main()
