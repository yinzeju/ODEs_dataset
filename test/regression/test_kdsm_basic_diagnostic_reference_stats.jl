using Test

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))

include(joinpath(PROJECT_ROOT, "src", "dynamics", "kdsm_basic_diagnostic_systems.jl"))
include(joinpath(PROJECT_ROOT, "src", "observations", "kdsm_basic_diagnostic_observations.jl"))
include(joinpath(PROJECT_ROOT, "src", "splits", "kdsm_basic_diagnostic_splits.jl"))
include(joinpath(PROJECT_ROOT, "src", "windows", "kdsm_basic_diagnostic_windows.jl"))
include(joinpath(PROJECT_ROOT, "src", "datasets", "kdsm_basic_diagnostic_dataset_objects.jl"))
include(joinpath(PROJECT_ROOT, "src", "io", "kdsm_basic_diagnostic_io.jl"))
include(joinpath(PROJECT_ROOT, "src", "manifests", "kdsm_basic_diagnostic_manifest.jl"))
include(joinpath(PROJECT_ROOT, "src", "registries", "kdsm_basic_diagnostic_registry.jl"))
include(joinpath(PROJECT_ROOT, "src", "diagnostics", "kdsm_basic_diagnostic_data_checks.jl"))
include(joinpath(PROJECT_ROOT, "src", "generators", "kdsm_basic_diagnostic_generator.jl"))

@testset "kdsm_basic reference stats" begin
    configs = kbasic_load_generation_configs(PROJECT_ROOT)
    specs = kbasic_build_generation_plan(configs["systems"]; difficulty = "smoke")
    beta_values = [spec.beta for spec in specs if spec.system_kind == "weak_duffing"]
    @test beta_values == [0.0, 1.0e-4, 1.0e-3, 5.0e-3, 1.0e-2, 2.0e-2]
    d0 = specs[end]
    obj = kbasic_generate_dataset_object(d0, configs["splits"], configs["windows"]; difficulty = "smoke")
    @test obj.spec.object_id == "kdsm_basic__D0_reference_near_linear_damped"
    @test obj.spec.alpha == 1.0
    @test obj.spec.delta == 0.08
    @test obj.spec.gamma == 0.0
    @test obj.diagnostics["manifest_summary"]["all_finite"]
    @test obj.diagnostics["manifest_summary"]["final_le_initial_fraction"] >= 0.9
end
