module NC
using JSON, SHA
const ROOT=normpath(joinpath(@__DIR__,"../.."))
filehash(path)=bytes2hex(open(sha256,path))
end
using Test
include(joinpath(NC.ROOT,"src/data/dataset21_nlc6/campaign.jl"))
cfg=NC.JSON.parsefile(joinpath(NC.ROOT,"configs/releases/dataset21_nlc6_v1_r3.json"))
rows=planned_population(cfg)
@testset "Bound per-case numerical refinement (no integration)" begin
    @test validate_numerical_overrides(cfg,rows)===nothing
    @test length(cfg["case_solver_overrides"])==5
    original=deepcopy(cfg)
    for row in rows
        effective=trajectory_config(cfg,row)
        solver=effective["trial"]["solver"]
        @test solver["substeps"]==(haskey(cfg["case_solver_overrides"],row["id"]) ? 4 : 2)
        @test all(solver[k]==cfg["trial"]["solver"][k] for k in keys(solver) if k!="substeps")
    end
    @test cfg==original
    for override in (Dict("substeps"=>2),Dict("substeps"=>4.0),Dict("substeps"=>true),
        Dict("substeps"=>3),Dict("substeps"=>4,"newton_relative_tolerance"=>1e-10))
        bad=deepcopy(cfg);bad["case_solver_overrides"]["NLC6_train_078"]=override
        @test_throws ErrorException validate_numerical_overrides(bad,rows)
    end
    bad=deepcopy(cfg);delete!(bad["case_initial_state_sha256"],"NLC6_train_078")
    @test_throws ErrorException validate_numerical_overrides(bad,rows)
    bad=deepcopy(cfg);bad["case_initial_state_sha256"]["NLC6_train_078"]="invalid"
    @test_throws ErrorException validate_numerical_overrides(bad,rows)
    bad=deepcopy(cfg);bad["case_solver_overrides"]["unknown"]=Dict("substeps"=>4)
    bad["case_initial_state_sha256"]["unknown"]=repeat("0",64)
    @test_throws ErrorException validate_numerical_overrides(bad,rows)
    q=[1.,2.];hash=bytes2hex(sha256(reinterpret(UInt8,q)))
    binding=Dict("case_initial_state_sha256"=>Dict("case"=>hash))
    @test verify_initial_state_binding(binding,"case",q)==hash
    @test_throws ErrorException verify_initial_state_binding(binding,"case",[1.,3.])
end
