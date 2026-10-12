using Test
include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
const NACA=Dataset21NACA
@testset "Explicit partial qualification contract" begin
    cfg=NACA.load_config(joinpath(NACA.ROOT,"configs","releases","dataset21_naca_v3_partial.json"))
    folder=joinpath(NACA.ROOT,"runs",cfg["release_id"])
    @test NACA.partial_qualification(cfg)
    @test NACA.qualification_filename(cfg)=="partial_authorization.json"
    q=NACA.accepted_qualification(folder,cfg)
    @test q["status"]=="user_authorized_partial"
    @test length(q["cases"])==2
    @test q["substeps"]==2
    @test !NACA.partial_qualification(NACA.load_config(joinpath(NACA.ROOT,"configs","releases","dataset21_naca_v2.json")))
    mktempdir() do temp
        mkpath(joinpath(temp,"qualification"))
        for name in ("models.json","input_fingerprint.json")
            cp(joinpath(folder,name),joinpath(temp,name))
        end
        altered=deepcopy(q);altered["status"]="qualified"
        target=joinpath(temp,"qualification","partial_authorization.json")
        NACA.writejson(target,altered)
        @test_throws ErrorException NACA.accepted_qualification(temp,cfg)
        altered=deepcopy(q);altered["config_sha256"]="stale"
        NACA.writejson(target,altered)
        @test_throws ErrorException NACA.accepted_qualification(temp,cfg)
    end
end
