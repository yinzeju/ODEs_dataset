const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const L96_NX10_TASK_CODE = "l96_nx10_raw_v1"

include(joinpath(PROJECT_ROOT, "src", "data", "highdim_nonlinear_v2_generation.jl"))

function l96_nx10_formal_profile(project_root::AbstractString)
    base = hdnd_profile(project_root, :formal)
    return HDNDProfile(
        name = :formal,
        split_counts = base.split_counts,
        l96_steps = base.l96_steps,
        pde_steps = base.pde_steps,
        l96_burn = base.l96_burn,
        ks_warm = base.ks_warm,
        l96_lyapunov_time = base.l96_lyapunov_time,
        ks_lyapunov_time = base.ks_lyapunov_time,
        check_count = base.check_count,
        sample_states_per_split = base.sample_states_per_split,
        master_seed = base.master_seed,
        output_root = joinpath(
            project_root,
            "data",
            "releases",
            L96_NX10_TASK_CODE,
        ),
        report_root = joinpath(
            project_root,
            "reports",
            "v2_core",
            L96_NX10_TASK_CODE,
        ),
    )
end

function run_l96_nx10_formal()
    profile = l96_nx10_formal_profile(PROJECT_ROOT)
    result = generate_hdnd_l96(
        PROJECT_ROOT,
        profile;
        spec = HDNDL96Spec(nx = 10),
        task_code = L96_NX10_TASK_CODE,
        system_name = "L96-10",
        output_filename = "l96_nx10_raw_v1.h5",
        certificate_filename = "l96_nx10_data_certificate_v1.json",
    )
    summary = Dict(
        "task_code" => L96_NX10_TASK_CODE,
        "profile" => "formal",
        "created_at" => string(now()),
        "dataset_path" => result["path"],
        "certificate_path" => result["certificate_path"],
        "passed" => result["certificate"]["passed"],
        "state_dimension" => 10,
        "split_counts" => Dict(pairs(profile.split_counts)),
        "snapshot_count" => profile.l96_steps + 1,
        "base_sampling_interval" => 0.05,
        "normalization_policy" => "none_raw_physical_coordinates",
    )
    summary_path = save_json(
        joinpath(profile.report_root, "logs", "run_summary_formal.json"),
        summary,
    )
    @printf("task_code: %s\n", L96_NX10_TASK_CODE)
    @printf("passed: %s\n", summary["passed"])
    @printf("dataset_path: %s\n", summary["dataset_path"])
    @printf("certificate_path: %s\n", summary["certificate_path"])
    @printf("summary_path: %s\n", summary_path)
    summary["passed"] || error("L96-Nx10 formal generation failed")
    return summary
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    run_l96_nx10_formal()
end
