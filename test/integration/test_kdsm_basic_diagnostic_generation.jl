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

@testset "kdsm_basic small object generation" begin
    configs = kbasic_load_generation_configs(PROJECT_ROOT)
    spec = kbasic_object_spec(configs["systems"], configs["systems"]["objects"][1]; difficulty = "smoke")
    obj = kbasic_generate_dataset_object(spec, configs["splits"], configs["windows"]; difficulty = "smoke")
    @test size(obj.state) == (12, 33, 2)
    @test obj.diagnostics["split_counts"] == Dict("train" => 8, "val" => 2, "test" => 2)
    @test obj.diagnostics["amplitude_counts"]["small"] > 0
    @test obj.diagnostics["amplitude_counts"]["mid"] > 0
    @test obj.diagnostics["amplitude_counts"]["large"] > 0
    @test obj.diagnostics["manifest_summary"]["linear_recurrence_error_max"] <= 1.0e-14
    @test obj.diagnostics["passed"]
end
