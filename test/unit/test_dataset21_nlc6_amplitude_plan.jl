module NC
using JSON, SHA
const ROOT=normpath(joinpath(@__DIR__,"../.."))
filehash(path)=bytes2hex(open(sha256,path))
end
using Test
include(joinpath(NC.ROOT,"src/data/dataset21_nlc6/campaign.jl"))
basecfg=NC.JSON.parsefile(joinpath(NC.ROOT,"configs/releases/dataset21_nlc6_v1_r1.json"))
cfg=NC.JSON.parsefile(joinpath(NC.ROOT,"configs/releases/dataset21_nlc6_v1_r2.json"))
base=planned_population(basecfg);revised=planned_population(cfg)
@testset "Frozen amplitude revision contract (no integration)" begin
    @test length(revised)==144
    @test count(pair->pair[1]!=pair[2],zip(base,revised))==5
    @test [sum(row["split"]==split for row in revised) for split in ("train","validation","test")]==[96,24,24]
    @test all(a["seed_hex"]==b["seed_hex"] && a["modes"]==b["modes"] && a["signs"]==b["signs"] for (a,b) in zip(base,revised))
    @test all(isapprox(sqrt(b["connector_energy_ratio"]/a["connector_energy_ratio"]),.8) for (a,b) in zip(base,revised) if a!=b)
    bad=deepcopy(cfg);bad["amplitude_overrides"]["NLC6_train_022"]=.9
    @test_throws ErrorException planned_population(bad)
    bad=deepcopy(cfg);bad["population_plan_sha256"]="invalid"
    @test_throws ErrorException planned_population(bad)
    @test all(cfg[k]==basecfg[k] for k in ("material","ports","linear_damping","sampling","solver_proposal","trial","state_dimension"))
end

