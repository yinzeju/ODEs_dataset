using Test

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "dynamics", "kdsm_basic_diagnostic_systems.jl"))
include(joinpath(PROJECT_ROOT, "src", "datasets", "kdsm_basic_diagnostic_dataset_objects.jl"))
include(joinpath(PROJECT_ROOT, "src", "io", "kdsm_basic_diagnostic_io.jl"))
include(joinpath(PROJECT_ROOT, "src", "registries", "kdsm_basic_diagnostic_registry.jl"))

@testset "kdsm_basic system registry" begin
    systems = kbasic_load_toml(joinpath(PROJECT_ROOT, "configs", "systems", "kdsm_basic_diagnostic_v1_systems.toml"))
    observations = kbasic_load_toml(joinpath(PROJECT_ROOT, "configs", "observations", "kdsm_basic_diagnostic_v1_observations.toml"))
    @test kbasic_validate_registry_configs(systems, observations)
    specs = [kbasic_object_spec(systems, object_config; difficulty = "default") for object_config in systems["objects"]]
    @test length(specs) == 8
    @test [spec.object_id for spec in specs] == kbasic_expected_object_ids()
    @test all(spec -> spec.R == 64 && spec.M == 256 && spec.tau == 0.05, specs)
    @test specs[end].beta == 0.02
end
