using LinearAlgebra, SparseArrays, JLD2, HDF5
include(joinpath(@__DIR__,"..","..","src","data","testsub2_nv","TestSub2NV.jl"))
using .TestSub2NV

function main()
    BLAS.set_num_threads(4)
    root=normpath(joinpath(@__DIR__,"..",".."))
    cache=joinpath(root,"runs","testsub2_nv","models");mkpath(cache)
    builders=[("duffing",TestSub2NV.duffing_model),("beam",TestSub2NV.beam_model),
        ("shell_nr",()->TestSub2NV.shell_model("NR")),
        ("shell_ir12",()->TestSub2NV.shell_model("IR12")),
        ("plate",()->TestSub2NV.shell_model("PLATE"))]
    for (id,build) in builders
        println("ASSEMBLY_START ",id);flush(stdout)
        elapsed=@elapsed m=build()
        evidence=TestSub2NV.mechanical_checks(m)
        evidence["assembly_seconds"]=elapsed
        reference=joinpath(root,"data","cache","testsub2_references",id*"_linear.h5")
        if isfile(reference)
            h5open(reference,"r") do f
                n=m.n
                A=sparse(Int.(read(f["row"])).+1,Int.(read(f["col"])).+1,read(f["value"]),2n,2n)
                rk=norm(m.M*A[n+1:2n,1:n]+m.K)/norm(m.K)
                rc=norm(m.M*A[n+1:2n,n+1:2n]+m.C)/norm(m.C)
                evidence["published_matrix_stiffness_residual"]=rk
                evidence["published_matrix_damping_residual"]=rc
                println("REFERENCE_MATRIX ",id," K=",rk," C=",rc)
                rk<1e-7 && rc<1e-7 || error("Published linear model parity failed")
            end
        end
        TestSub2NV.write_json(joinpath(cache,id*"_assembly.json"),evidence)
        jldopen(joinpath(cache,id*".jld2"),"w") do f;f["model"]=m;end
        println("ASSEMBLY_OK ",id," n=",m.n," omega=",m.omega[1:min(5,m.n)]," seconds=",elapsed);flush(stdout)
    end
end
main()
