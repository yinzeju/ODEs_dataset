using JLD2
using JSON
using Plots
using Printf
using Statistics

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const RELEASE_ROOT = joinpath(PROJECT_ROOT, "data", "releases", "controlled_lowdim_v1")
const TASK_IDENTITY = "odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization"
const REPORT_DIRECTORY = joinpath(PROJECT_ROOT, "reports", TASK_IDENTITY)
const PLOTS_DIRECTORY = joinpath(REPORT_DIRECTORY, "plots")
const TABLES_DIRECTORY = joinpath(REPORT_DIRECTORY, "tables")
const REPORT_PATH = joinpath(REPORT_DIRECTORY, "$(TASK_IDENTITY).md")
const SUMMARY_PATH = joinpath(TABLES_DIRECTORY, "$(TASK_IDENTITY)_summary.csv")
const HF_REVISION_PATH = joinpath(TABLES_DIRECTORY, "$(TASK_IDENTITY)_duffing_hf_bilinear_revision.csv")
const HF_V2_PILOT_PATH =
    joinpath(TABLES_DIRECTORY, "$(TASK_IDENTITY)_duffing_hf_bilinear_pilot.csv")
const HF_PILOT_PATH =
    joinpath(TABLES_DIRECTORY, "$(TASK_IDENTITY)_duffing_hf_bilinear_window_pilot.csv")
const HF_METADATA_PATH = joinpath(
    RELEASE_ROOT,
    "duffing_hf",
    "duffing_hf_bilinc",
    "metadata.json",
)
const HF_PILOT_RESULT_PATH = joinpath(
    PROJECT_ROOT,
    "runs",
    "smoke_tests",
    "controlled_lowdim_v1_duffing_hf_bilinear_window_pilot.json",
)
const REPRESENTATIVE_TRAJECTORY_ID = 1

const DATASETS = (
    (base = "linosc", object_id = "linosc_augaut"),
    (base = "linosc", object_id = "linosc_addc"),
    (base = "linosc", object_id = "linosc_bilinc"),
    (base = "duffing", object_id = "duffing_augaut"),
    (base = "duffing", object_id = "duffing_addc"),
    (base = "duffing", object_id = "duffing_bilinc"),
    (base = "vdp", object_id = "vdp_augaut"),
    (base = "vdp", object_id = "vdp_addc"),
    (base = "vdp", object_id = "vdp_bilinc"),
    (base = "pendulum", object_id = "pendulum_augaut"),
    (base = "pendulum", object_id = "pendulum_addc"),
    (base = "pendulum", object_id = "pendulum_bilinc"),
    (base = "duffing_hf", object_id = "duffing_hf_augaut"),
    (base = "duffing_hf", object_id = "duffing_hf_addc"),
    (base = "duffing_hf", object_id = "duffing_hf_bilinc"),
)

struct ObjectSummary
    base::String
    object_id::String
    role::String
    trajectory_id::Int
    split_id::String
    matched_key::String
    state_samples::Int
    control_samples::Int
    state_time_start::Float64
    state_time_end::Float64
    control_time_start::Float64
    control_time_end::Float64
    state_1_min::Float64
    state_1_max::Float64
    state_2_min::Float64
    state_2_max::Float64
    control_min::Float64
    control_max::Float64
    control_mean::Float64
    control_std::Float64
    control_label::String
    state_path::String
    control_path::String
end

dataset_path(base::AbstractString, object_id::AbstractString) =
    joinpath(RELEASE_ROOT, base, object_id, "clean.jld2")

role_from_id(object_id::AbstractString) = split(object_id, '_')[end]

function state_labels(base::AbstractString)
    base == "pendulum" && return ("Angle θ", "Angular velocity ω")
    return ("Displacement x", "Velocity p")
end

time_label(base::AbstractString) = base == "duffing_hf" ? "Time t (s)" : "Time t"

function base_name(base::AbstractString)
    base == "linosc" && return "Linear damped oscillator"
    base == "duffing" && return "Duffing oscillator"
    base == "vdp" && return "Van der Pol oscillator"
    base == "pendulum" && return "Controlled pendulum"
    base == "duffing_hf" && return "High-frequency strong-hardening Duffing oscillator"
    error("unsupported base system: $(base)")
end

function role_name(role::AbstractString)
    role == "augaut" && return "augmented autonomous"
    role == "addc" && return "additive control"
    role == "bilinc" && return "bilinear control"
    error("unsupported control role: $(role)")
end

function role_description(base::AbstractString, role::AbstractString)
    if base == "duffing_hf"
        role == "augaut" && return "扩展自治；显示保存的物理外力 \$u_{\\mathrm{HF}}(t)\$，仅用于审计，不作为 learner 的独立输入"
        role == "addc" && return "显式加性受控；显示物理外力 \$u_{\\mathrm{HF}}(t)\$"
        role == "bilinc" && return "强相对线性刚度调制 \$k[1-\\rho_k c_{\\mathrm{HF}}(t)]\$；显示单位峰值源 \$c_{\\mathrm{HF}}(t)\$"
    end
    role == "augaut" && return "扩展自治；图中的 \$c(t)\$ 为保存的审计信号，不作为 learner 的独立输入"
    role == "addc" && return "显式加性受控；图中的 \$c(t)\$ 是控制输入"
    role == "bilinc" && return "显式双线性受控；图中的 \$c(t)\$ 参与状态--控制相互作用"
    error("unsupported control role: $(role)")
end

function trajectory_row(trajectory_ids::AbstractVector{<:Integer}, requested_id::Integer)
    row = findfirst(==(requested_id), trajectory_ids)
    isnothing(row) && error("trajectory_id=$(requested_id) is not present in the dataset")
    return row
end

function duffing_hf_representative_trajectory_id()
    path = dataset_path("duffing_hf", "duffing_hf_bilinc")
    return JLD2.jldopen(path, "r") do file
        state = Array(file["state_physical_clean"])
        trajectory_ids = file["trajectory_id"]
        time_state = vec(file["time_state"][1, :])
        head_energy = vec(mean(
            @view(state[:, 1:500, 1]).^2 .+ @view(state[:, 1:500, 2]).^2;
            dims = 2,
        ))
        tail_energy = vec(mean(
            @view(state[:, 1501:2000, 1]).^2 .+ @view(state[:, 1501:2000, 2]).^2;
            dims = 2,
        ))
        persistence_ratio = sqrt.(tail_energy) ./ (sqrt.(head_energy) .+ eps(Float32))
        sample_interval = median(diff(time_state))
        window_sample_count = round(Int, 0.5 / sample_interval)
        window_stride = round(Int, 0.1 / sample_interval)
        window_starts = 1:window_stride:(size(state, 2) - window_sample_count + 1)
        minimum_window_relative_rms = Vector{Float64}(undef, size(state, 1))
        window_rms = Vector{Float64}(undef, length(window_starts))
        for trajectory in axes(state, 1)
            for (window_index, window_start) in enumerate(window_starts)
                window_stop = window_start + window_sample_count - 1
                window_energy = mean(
                    @view(state[trajectory, window_start:window_stop, 1]).^2 .+
                    @view(state[trajectory, window_start:window_stop, 2]).^2,
                )
                window_rms[window_index] = sqrt(window_energy)
            end
            minimum_window_relative_rms[trajectory] =
                minimum(window_rms) / (median(window_rms) + eps(Float64))
        end
        eligible_rows = findall(
            row ->
                0.2 <= persistence_ratio[row] <= 5.0 &&
                    minimum_window_relative_rms[row] >= 0.1,
            axes(state, 1),
        )
        isempty(eligible_rows) &&
            error("no continuously persistent DUF-HF bilinear trajectory is available for plotting")
        eligible_median = median(@view minimum_window_relative_rms[eligible_rows])
        representative_row = eligible_rows[
            argmin(abs.(@view(minimum_window_relative_rms[eligible_rows]) .- eligible_median))
        ]
        return Int(trajectory_ids[representative_row])
    end
end

function load_clean_trajectory(base::AbstractString, object_id::AbstractString, requested_id::Integer)
    path = dataset_path(base, object_id)
    isfile(path) || error("missing clean dataset: $(path)")
    return JLD2.jldopen(path, "r") do file
        trajectory_ids = file["trajectory_id"]
        row = trajectory_row(trajectory_ids, requested_id)
        time_state = vec(file["time_state"][row, :])
        time_transition = vec(file["time_transition"][row, :])
        state = Array(file["state_physical_clean"][row, :, :])
        role = role_from_id(object_id)
        control, control_label = if base == "duffing_hf"
            if role == "bilinc"
                (
                    vec(file["source_signal_unit_peak"][row, 1:length(time_transition), 1]),
                    "Unit-peak source c_HF(t)",
                )
            else
                (
                    vec(file["forcing_additive_physical"][row, 1:length(time_transition), 1]),
                    "Physical forcing u_HF(t)",
                )
            end
        else
            (vec(file["control_left_clean"][row, :, 1]), "Control c(t)")
        end
        split_id = String(file["split_id"][row])
        matched_key = String(file["matched_key"][row])
        dataset_id = String(file["dataset_id"])

        dataset_id == object_id || error("dataset identifier mismatch in $(path)")
        size(state, 2) == 2 || error("$(object_id) physical state must have two channels")
        length(time_state) == size(state, 1) || error("state time axis is not aligned for $(object_id)")
        length(time_transition) == length(control) || error("control time axis is not aligned for $(object_id)")
        all(isfinite, state) || error("non-finite physical state in $(object_id)")
        all(isfinite, control) || error("non-finite control signal in $(object_id)")

        return (
            state = state,
            control = control,
            time_state = time_state,
            time_transition = time_transition,
            trajectory_id = Int(trajectory_ids[row]),
            split_id = split_id,
            matched_key = matched_key,
            control_label = control_label,
        )
    end
end

function render_object(base::AbstractString, object_id::AbstractString, requested_id::Integer)
    trajectory = load_clean_trajectory(base, object_id, requested_id)
    role = role_from_id(object_id)
    first_label, second_label = state_labels(base)
    horizontal_label = time_label(base)
    state_path = joinpath(PLOTS_DIRECTORY, "$(TASK_IDENTITY)_$(object_id)_state.png")
    control_path = joinpath(PLOTS_DIRECTORY, "$(TASK_IDENTITY)_$(object_id)_control.png")
    state_1 = @view trajectory.state[:, 1]
    state_2 = @view trajectory.state[:, 2]

    first_component_plot = plot(
        trajectory.time_state,
        state_1;
        color = :royalblue,
        dpi = 200,
        legend = false,
        linewidth = 1.5,
        xlabel = horizontal_label,
        ylabel = first_label,
    )
    second_component_plot = plot(
        trajectory.time_state,
        state_2;
        color = :darkorange,
        dpi = 200,
        legend = false,
        linewidth = 1.5,
        xlabel = horizontal_label,
        ylabel = second_label,
    )
    state_plot = plot(
        first_component_plot,
        second_component_plot;
        layout = (2, 1),
        left_margin = 12 * Plots.mm,
        plot_title = "$(object_id): physical state (clean, trajectory $(trajectory.trajectory_id))",
        size = (1400, 900),
    )
    savefig(state_plot, state_path)

    control_title = role == "augaut" ? "audit control" : "control"
    control_plot = plot(
        trajectory.time_transition,
        trajectory.control;
        color = :seagreen,
        dpi = 200,
        legend = false,
        left_margin = 12 * Plots.mm,
        linewidth = 1.5,
        size = (1400, 450),
        title = "$(object_id): $(control_title) (clean, trajectory $(trajectory.trajectory_id))",
        xlabel = horizontal_label,
        ylabel = trajectory.control_label,
    )
    savefig(control_plot, control_path)

    isfile(state_path) || error("state figure was not written: $(state_path)")
    isfile(control_path) || error("control figure was not written: $(control_path)")

    return ObjectSummary(
        String(base),
        String(object_id),
        role,
        trajectory.trajectory_id,
        trajectory.split_id,
        trajectory.matched_key,
        length(trajectory.time_state),
        length(trajectory.time_transition),
        Float64(first(trajectory.time_state)),
        Float64(last(trajectory.time_state)),
        Float64(first(trajectory.time_transition)),
        Float64(last(trajectory.time_transition)),
        Float64(minimum(state_1)),
        Float64(maximum(state_1)),
        Float64(minimum(state_2)),
        Float64(maximum(state_2)),
        Float64(minimum(trajectory.control)),
        Float64(maximum(trajectory.control)),
        Float64(mean(trajectory.control)),
        Float64(std(trajectory.control)),
        trajectory.control_label,
        state_path,
        control_path,
    )
end

format_number(value::Real) = @sprintf("%.6g", value)

const HF_BILINEAR_V1_BASELINE = (
    rho = 0.3,
    persistence_passing_fraction = 0.0,
    persistence_ratio_median = 1.3106620564643672e-26,
    work_damping_abs_ratio_median = 0.01990277622860294,
    bilinear_additive_relative_frobenius = 0.972152000429829,
    tail_high_frequency_energy_ratio_median = 4.114226003948581e-36,
    state_max_abs = 0.43525445461273193,
)

const HF_BILINEAR_V2_BASELINE = (
    rho = 10.0,
    persistence_passing_fraction = 0.65625,
    persistence_ratio_median = 0.6274576246689396,
    work_damping_abs_ratio_median = 0.9764878087688355,
    bilinear_additive_relative_frobenius = 1.5171241853391677,
    tail_high_frequency_energy_ratio_median = 0.30584902723248353,
    state_max_abs = 0.860045660438812,
    continuous_window_passing_fraction = 0.3736979166666667,
    minimum_window_relative_rms_median = 0.05976765345020005,
)

function load_hf_revision_evidence()
    isfile(HF_METADATA_PATH) || error("missing DUF-HF BIL metadata: $(HF_METADATA_PATH)")
    isfile(HF_PILOT_RESULT_PATH) || error("missing DUF-HF BIL pilot result: $(HF_PILOT_RESULT_PATH)")
    metadata = JSON.parsefile(HF_METADATA_PATH)
    pilot = JSON.parsefile(HF_PILOT_RESULT_PATH)
    diagnostics = metadata["diagnostics"]
    physical = diagnostics["bilinear_physical_diagnostics"]
    diagnostics["passed"] === true || error("DUF-HF BIL formal diagnostics did not pass")
    diagnostics["bilinear_physical_acceptance_passed"] === true ||
        error("DUF-HF BIL physical acceptance did not pass")
    return (
        metadata = metadata,
        diagnostics = diagnostics,
        physical = physical,
        pilot = pilot,
    )
end

function write_hf_revision_csv(path::AbstractString, evidence)
    current = evidence.physical
    rho = evidence.metadata["parameters"]["bilinear_relative_stiffness_depth"]
    open(path, "w") do io
        println(io, "version,rho,persistence_passing_fraction,persistence_ratio_median,continuous_window_passing_fraction,minimum_window_relative_rms_median,work_damping_abs_ratio_median,bilinear_additive_relative_frobenius,tail_high_frequency_energy_ratio_median,state_max_abs")
        println(
            io,
            join((
                "v1_baseline",
                format_number(HF_BILINEAR_V1_BASELINE.rho),
                format_number(HF_BILINEAR_V1_BASELINE.persistence_passing_fraction),
                format_number(HF_BILINEAR_V1_BASELINE.persistence_ratio_median),
                "",
                "",
                format_number(HF_BILINEAR_V1_BASELINE.work_damping_abs_ratio_median),
                format_number(HF_BILINEAR_V1_BASELINE.bilinear_additive_relative_frobenius),
                format_number(HF_BILINEAR_V1_BASELINE.tail_high_frequency_energy_ratio_median),
                format_number(HF_BILINEAR_V1_BASELINE.state_max_abs),
            ), ','),
        )
        println(
            io,
            join((
                "v2_formal",
                format_number(HF_BILINEAR_V2_BASELINE.rho),
                format_number(HF_BILINEAR_V2_BASELINE.persistence_passing_fraction),
                format_number(HF_BILINEAR_V2_BASELINE.persistence_ratio_median),
                format_number(HF_BILINEAR_V2_BASELINE.continuous_window_passing_fraction),
                format_number(HF_BILINEAR_V2_BASELINE.minimum_window_relative_rms_median),
                format_number(HF_BILINEAR_V2_BASELINE.work_damping_abs_ratio_median),
                format_number(HF_BILINEAR_V2_BASELINE.bilinear_additive_relative_frobenius),
                format_number(HF_BILINEAR_V2_BASELINE.tail_high_frequency_energy_ratio_median),
                format_number(HF_BILINEAR_V2_BASELINE.state_max_abs),
            ), ','),
        )
        println(
            io,
            join((
                "v3_formal",
                format_number(rho),
                format_number(current["persistence_passing_fraction"]),
                format_number(current["persistence_ratio_median"]),
                format_number(current["continuous_window_passing_fraction"]),
                format_number(current["minimum_window_relative_rms_median"]),
                format_number(current["work_damping_abs_ratio_median"]),
                format_number(current["bilinear_additive_relative_frobenius"]),
                format_number(current["tail_high_frequency_energy_ratio_median"]),
                format_number(current["state_max_abs"]),
            ), ','),
        )
    end
    return path
end

function write_hf_pilot_csv(path::AbstractString, evidence)
    selected_depth = evidence.pilot["selected_relative_stiffness_depth"]
    records = sort(
        evidence.pilot["candidate_records"];
        by = record -> Float64(record["relative_stiffness_depth"]),
    )
    open(path, "w") do io
        println(io, "rho,selected,passed,persistence_passing_fraction,persistence_ratio_median,continuous_window_passing_fraction,minimum_window_relative_rms_median,work_damping_abs_ratio_median,tail_high_frequency_energy_ratio_median,state_max_abs")
        for record in records
            metrics = record["metrics"]
            rho = Float64(record["relative_stiffness_depth"])
            println(
                io,
                join((
                    format_number(rho),
                    string(rho == selected_depth),
                    string(record["passed"]),
                    format_number(metrics["persistence_passing_fraction"]),
                    format_number(metrics["persistence_ratio_median"]),
                    format_number(metrics["continuous_window_passing_fraction"]),
                    format_number(metrics["minimum_window_relative_rms_median"]),
                    format_number(metrics["work_damping_abs_ratio_median"]),
                    format_number(metrics["tail_high_frequency_energy_ratio_median"]),
                    format_number(metrics["state_max_abs"]),
                ), ','),
            )
        end
    end
    return path
end

function write_summary_csv(path::AbstractString, summaries::AbstractVector{ObjectSummary})
    open(path, "w") do io
        println(io, "object_id,base_system,control_role,trajectory_id,split_id,matched_key,state_samples,control_samples,state_time_start,state_time_end,control_time_start,control_time_end,state_1_min,state_1_max,state_2_min,state_2_max,control_min,control_max,control_mean,control_std")
        for summary in summaries
            fields = (
                summary.object_id,
                summary.base,
                summary.role,
                string(summary.trajectory_id),
                summary.split_id,
                summary.matched_key,
                string(summary.state_samples),
                string(summary.control_samples),
                format_number(summary.state_time_start),
                format_number(summary.state_time_end),
                format_number(summary.control_time_start),
                format_number(summary.control_time_end),
                format_number(summary.state_1_min),
                format_number(summary.state_1_max),
                format_number(summary.state_2_min),
                format_number(summary.state_2_max),
                format_number(summary.control_min),
                format_number(summary.control_max),
                format_number(summary.control_mean),
                format_number(summary.control_std),
            )
            println(io, join(fields, ','))
        end
    end
    return path
end

function write_report(path::AbstractString, summaries::AbstractVector{ObjectSummary}, evidence)
    object_count = length(summaries)
    figure_count = 2 * object_count
    hf_trajectory_id = only(unique(
        summary.trajectory_id for summary in summaries if summary.base == "duffing_hf"
    ))
    metadata = evidence.metadata
    diagnostics = evidence.diagnostics
    physical = evidence.physical
    pilot = evidence.pilot
    rho = Float64(metadata["parameters"]["bilinear_relative_stiffness_depth"])
    frequencies = Float64.(metadata["source"]["frequencies_hz"])
    weights = Float64.(metadata["source"]["harmonic_weights"])
    pilot_records = sort(
        pilot["candidate_records"];
        by = record -> Float64(record["relative_stiffness_depth"]),
    )
    open(path, "w") do io
        println(io, "# controlled_lowdim_v1：", object_count, " 个受控低维对象的代表轨线图")
        println(io)
        println(io, "## 目标与范围")
        println(io)
        println(io, "本报告为 `controlled_lowdim_v1` 的 ", object_count, " 个规范数据对象各绘制两张 clean-view 示意图：一张物理状态图与一张控制信号图，共 ", figure_count, " 张图。图形用于核查轨线的时间尺度、物理状态分量与保存的控制字段，不用于模型训练、预测性能评估或跨对象的聚合评分。")
        println(io)
        println(io, "绘图遵循 `docs/notes/mathematical explanation/controlled_lowdim_v1.md` 的 KSF-D1 数据契约；DUF-HF 的 BIL 方程、加权频带与物理验收由用户提供的 `D:\\MyVault\\Document\\Obsidian\\Notebook\\草稿本\\草稿3.md` 覆盖修订。v3 在此基础上加入连续时间窗验收，专门排除中间段近似直线的轨线。报告只读取每个对象的 `clean.jld2`，因此图中反映的是原始物理坐标。")
        println(io)
        println(io, "## 数据与绘图约定")
        println(io)
        println(io, "- 数据源：`data/releases/controlled_lowdim_v1`，正式 release，", object_count, " 个 clean 对象均通过 release manifest 验证。")
        println(io, "- 代表轨线：原有 12 个对象使用 `trajectory_id = 1`。DUF-HF 三个角色统一使用 `trajectory_id = ", hf_trajectory_id, "`；它同时通过首尾持续性与连续时间窗门槛，并最接近合格轨线的中位最弱窗比。三个角色仍共享同一 matched key，保持初始物理状态与外部源初值可配对。")
        println(io, "- 状态图：读取 `state_physical_clean`。线性振子、两个 Duffing 底座与 Van der Pol 的两个通道分别为 \$x\$ 与 \$p\$；单摆的两个通道为 raw angle \$\\theta\$ 与 angular velocity \$\\omega\$。")
        println(io, "- 控制图：原有四个动力学底座读取左端点控制 `control_left_clean`。DUF-HF 的 AUG/ADD 显示物理外力 `forcing_additive_physical`，BIL 显示单位峰值 `source_signal_unit_peak`；三者都在 `time_transition` 上绘制。")
        println(io, "- 时间轴：原有四个底座使用 \$\\tau=0.01\$、状态 2,001 点 \$[0,20]\$ 与控制 2,000 点 \$[0,19.99]\$。DUF-HF 使用 500 Hz 模型网格（\$\\tau=0.002\$），按 half-open 端点策略保存状态 2,000 点 \$[0,3.998]\$ 与控制 1,999 点 \$[0,3.996]\$。数学说明将 DUF-HF 的频率明确为 Hz，因此其图的时间坐标以秒解释；其余对象未声明物理单位，仍标为 `Time t`。")
        println(io)
        println(io, "## 生成与验证协议")
        println(io)
        println(io, "每个对象的状态图包含上下两个子图，分别显示两个物理状态分量在完整状态时间网格上的值。控制图显示完整控制区间网格上的 \$c_m^{\\mathrm L}\$。脚本在保存前检查：状态维度为 2、状态与时间轴长度一致、控制与转移时间轴长度一致，并确认所绘数据全为有限值。")
        println(io)
        println(io, "本次生成结果：", object_count, " 个对象均输出 1 张状态图与 1 张控制图。每张图均使用对象对应的完整保存网格；各对象的精确样本数、起止时间与数值范围见下表。")
        println(io)
        println(io, "DUF-HF v3 采用冻结正式 profile：\$m=1\$、\$d=40\$、\$k=3000\$、\$k_c=5\\times10^8\$、加性外力峰值 \$A_{\\mathrm{HF}}=20\$、双线性相对刚度深度 \$\\rho_k=", format_number(rho), "\$。共同 source 的频率为 `", join(format_number.(frequencies), ", "), "` Hz，并对 9 Hz 与 17.5 Hz 赋权 2，其余谐波赋权 1，随后执行全局单位峰值归一化。高保真仿真采样率为 2,000 Hz，再以零相位 FIR 抗混叠后降至 500 Hz；AUG 和 ADD 共享物理母轨线，BIL 单独采用强刚度调制。512/128/128 个 train/val/test 轨线的 clean release 已重新生成；可选 10 dB 观测视图按当前配置关闭。")
        println(io)
        println(io, "## DUF-HF BIL v3 连续性优化与调整记录")
        println(io)
        println(io, "修订后的纯 BIL 方程为")
        println(io)
        println(io, "\$\$")
        println(io, "\\dot x=p,\\qquad")
        println(io, "m\\dot p=-dp-k[1-\\rho_k c_{\\mathrm{HF}}(t)]x-k_cx^3.")
        println(io, "\$\$")
        println(io)
        println(io, "该分支没有加性外力；当 \$1-\\rho_k c_{\\mathrm{HF}}(t)<0\$ 时，原点暂时失稳，而正的三次硬化项继续约束大位移。v3 正式数据中的瞬时线性刚度范围为 `[", format_number(diagnostics["bilinear_minimum_linear_stiffness"]), ", ", format_number(diagnostics["bilinear_maximum_linear_stiffness"]), "]`，负刚度样本比例为 ", format_number(diagnostics["bilinear_negative_stiffness_fraction"]), "。")
        println(io)
        println(io, "v2 的首尾持续性指标只比较前 1 s 与后 1 s，无法发现中间局部衰减。对 v2 全量 768 条轨线补算 0.5 s 窗、0.1 s 步长后，连续窗通过率仅为 ", format_number(HF_BILINEAR_V2_BASELINE.continuous_window_passing_fraction), "，中位最弱窗相对 RMS 仅为 ", format_number(HF_BILINEAR_V2_BASELINE.minimum_window_relative_rms_median), "；这解释了代表轨线中间段近似直线的现象。")
        println(io)
        println(io, "令第 \$\\ell\$ 个 0.5 s 窗的状态 RMS 为")
        println(io)
        println(io, "\$\$")
        println(io, "R_{i,\\ell}=\\left[\\frac{1}{|\\mathcal W_\\ell|}\\sum_{m\\in\\mathcal W_\\ell}\\left(x_{i,m}^2+p_{i,m}^2\\right)\\right]^{1/2},\\qquad")
        println(io, "\\Gamma_{i,\\mathrm{win}}=\\frac{\\min_\\ell R_{i,\\ell}}{\\operatorname{median}_\\ell R_{i,\\ell}+\\epsilon}.")
        println(io, "\$\$")
        println(io)
        println(io, "v3 要求 \$\\Gamma_{i,\\mathrm{win}}\\ge 0.1\$ 的轨线比例至少达到 0.75，同时保留原有首尾持续性、做功/耗散、BIL--ADD 差异、高频能量、有限性与状态上界门槛。新的 64 条 training-side pilot 扫描 \$\\rho_k\\in\\{10,12,14,16,18,20\\}\$；\$\\rho_k=10\$ 的连续窗通过率只有 0.421875，因而失败；\$\\rho_k=12\$ 的通过率为 0.96875，是通过所有门槛的最小候选，因此冻结为 v3 正式值。")
        println(io)
        println(io, "v2 原 pilot 表保留在 [`$(basename(HF_V2_PILOT_PATH))`](tables/$(basename(HF_V2_PILOT_PATH)))；v3 连续窗 pilot 表见 [`$(basename(HF_PILOT_PATH))`](tables/$(basename(HF_PILOT_PATH)))。")
        println(io)
        println(io, "| \$\\rho_k\$ | Selected | Passed | Persistence fraction | Window fraction | Median \$\\Gamma_{\\mathrm{win}}\$ | Median \$|W_{\\mathrm{bil}}|/D_{\\mathrm{damp}}\$ | Tail >20 Hz energy | State max |")
        println(io, "| ---: | :---: | :---: | ---: | ---: | ---: | ---: | ---: | ---: |")
        for record in pilot_records
            metrics = record["metrics"]
            candidate = Float64(record["relative_stiffness_depth"])
            println(
                io,
                "| ", format_number(candidate),
                " | ", candidate == pilot["selected_relative_stiffness_depth"] ? "yes" : "no",
                " | ", record["passed"] ? "yes" : "no",
                " | ", format_number(metrics["persistence_passing_fraction"]),
                " | ", format_number(metrics["continuous_window_passing_fraction"]),
                " | ", format_number(metrics["minimum_window_relative_rms_median"]),
                " | ", format_number(metrics["work_damping_abs_ratio_median"]),
                " | ", format_number(metrics["tail_high_frequency_energy_ratio_median"]),
                " | ", format_number(metrics["state_max_abs"]), " |",
            )
        end
        println(io)
        println(io, "v1、v2 与 v3 的正式物理证据对比见 [`$(basename(HF_REVISION_PATH))`](tables/$(basename(HF_REVISION_PATH)))：")
        println(io)
        println(io, "| Metric | v1 baseline | v2 formal | v3 formal |")
        println(io, "| --- | ---: | ---: | ---: |")
        println(io, "| \$\\rho_k\$ | ", format_number(HF_BILINEAR_V1_BASELINE.rho), " | ", format_number(HF_BILINEAR_V2_BASELINE.rho), " | ", format_number(rho), " |")
        println(io, "| Persistence passing fraction | ", format_number(HF_BILINEAR_V1_BASELINE.persistence_passing_fraction), " | ", format_number(HF_BILINEAR_V2_BASELINE.persistence_passing_fraction), " | ", format_number(physical["persistence_passing_fraction"]), " |")
        println(io, "| Median \$\\Gamma_{\\mathrm{persist}}\$ | ", format_number(HF_BILINEAR_V1_BASELINE.persistence_ratio_median), " | ", format_number(HF_BILINEAR_V2_BASELINE.persistence_ratio_median), " | ", format_number(physical["persistence_ratio_median"]), " |")
        println(io, "| Continuous-window passing fraction | not measured | ", format_number(HF_BILINEAR_V2_BASELINE.continuous_window_passing_fraction), " | ", format_number(physical["continuous_window_passing_fraction"]), " |")
        println(io, "| Median \$\\Gamma_{\\mathrm{win}}\$ | not measured | ", format_number(HF_BILINEAR_V2_BASELINE.minimum_window_relative_rms_median), " | ", format_number(physical["minimum_window_relative_rms_median"]), " |")
        println(io, "| Median \$|W_{\\mathrm{bil}}|/D_{\\mathrm{damp}}\$ | ", format_number(HF_BILINEAR_V1_BASELINE.work_damping_abs_ratio_median), " | ", format_number(HF_BILINEAR_V2_BASELINE.work_damping_abs_ratio_median), " | ", format_number(physical["work_damping_abs_ratio_median"]), " |")
        println(io, "| Tail >20 Hz energy ratio | ", format_number(HF_BILINEAR_V1_BASELINE.tail_high_frequency_energy_ratio_median), " | ", format_number(HF_BILINEAR_V2_BASELINE.tail_high_frequency_energy_ratio_median), " | ", format_number(physical["tail_high_frequency_energy_ratio_median"]), " |")
        println(io, "| BIL--ADD relative Frobenius difference | ", format_number(HF_BILINEAR_V1_BASELINE.bilinear_additive_relative_frobenius), " | ", format_number(HF_BILINEAR_V2_BASELINE.bilinear_additive_relative_frobenius), " | ", format_number(physical["bilinear_additive_relative_frobenius"]), " |")
        println(io, "| State maximum absolute value | ", format_number(HF_BILINEAR_V1_BASELINE.state_max_abs), " | ", format_number(HF_BILINEAR_V2_BASELINE.state_max_abs), " | ", format_number(physical["state_max_abs"]), " |")
        println(io)
        println(io, "v3 正式结果通过全部门槛：首尾持续性通过率 ", format_number(physical["persistence_passing_fraction"]), "，连续窗通过率 ", format_number(physical["continuous_window_passing_fraction"]), "，中位 \$\\Gamma_{\\mathrm{win}}=", format_number(physical["minimum_window_relative_rms_median"]), "\$，中位做功/耗散比 ", format_number(physical["work_damping_abs_ratio_median"]), "，尾段 20 Hz 以上能量比 ", format_number(physical["tail_high_frequency_energy_ratio_median"]), "，状态最大绝对值 ", format_number(physical["state_max_abs"]), "，低于配置上限 ", format_number(physical["state_abs_limit"]), "。AUG 与 ADD 的物理状态最大绝对差仍为 0，保留了 matched learner-interface comparison。")
        println(io)
        println(io, "## 代表轨线数值摘要")
        println(io)
        println(io, "完整机器可读表见 [`$(basename(SUMMARY_PATH))`](tables/$(basename(SUMMARY_PATH)))。范围和统计量均基于图中实际绘制的一条 clean 轨线。")
        println(io)
        println(io, "| Object | Role | State 1 range | State 2 range | Control range | Control mean ± std |")
        println(io, "| --- | --- | ---: | ---: | ---: | ---: |")
        for summary in summaries
            state_1_range = "[" * format_number(summary.state_1_min) * ", " * format_number(summary.state_1_max) * "]"
            state_2_range = "[" * format_number(summary.state_2_min) * ", " * format_number(summary.state_2_max) * "]"
            control_range = "[" * format_number(summary.control_min) * ", " * format_number(summary.control_max) * "]"
            control_stats = format_number(summary.control_mean) * " ± " * format_number(summary.control_std)
            println(io, "| `", summary.object_id, "` | `", summary.role, "` | ", state_1_range, " | ", state_2_range, " | ", control_range, " | ", control_stats, " |")
        end
        println(io)
        println(io, "## 曲线图")
        println(io)
        for summary in summaries
            println(io, "### `", summary.object_id, "`")
            println(io)
            println(io, "- 动力学底座：", base_name(summary.base), "。")
            println(io, "- 控制语义：", role_description(summary.base, summary.role), "。")
            println(io, "- 控制图纵轴：`", summary.control_label, "`。")
            println(io, "- 代表轨线：`trajectory_id = ", summary.trajectory_id, "`，`split_id = ", summary.split_id, "`，`matched_key = ", summary.matched_key, "`。")
            println(io)
            println(io, "![", summary.object_id, " physical-state trajectory](plots/", basename(summary.state_path), ")")
            println(io)
            println(io, "![", summary.object_id, " control trajectory](plots/", basename(summary.control_path), ")")
            println(io)
        end
        println(io, "## 解读、限制与复现")
        println(io)
        println(io, "三个角色必须分别解读：`augaut` 将外部源状态纳入自治 learner state，`addc` 为正式的显式加性控制接口，`bilinc` 则含有状态--控制相互作用。图中的控制曲线用于展示同一保存信号的时间变化，不能据此将三类对象当作同一控制律的重复样本。")
        println(io)
        println(io, "这些图仅展示每个对象的一条训练轨线，因而不能代替 512 条轨迹上的分布、split、激励 Gram、零控制退化或控制灵敏度诊断。release metadata 中的这些正式生成诊断仍是数据集有效性的依据。")
        println(io)
        println(io, "复现命令：`julia --project=. experiments/visualization/plot_controlled_lowdim_v1_trajectories.jl`。脚本、图像、摘要表和本报告位于同一任务目录下。")
    end
    return path
end

function validate_release_manifest()
    manifest_path = joinpath(RELEASE_ROOT, "release_manifest.json")
    isfile(manifest_path) || error("missing release manifest: $(manifest_path)")
    manifest = JSON.parsefile(manifest_path)
    manifest["all_passed"] === true || error("controlled_lowdim_v1 release manifest is not passed")
    length(manifest["objects"]) == length(DATASETS) || error("release manifest does not contain the expected objects")
    return manifest
end

function main()
    validate_release_manifest()
    mkpath(PLOTS_DIRECTORY)
    mkpath(TABLES_DIRECTORY)

    hf_representative_id = duffing_hf_representative_trajectory_id()
    evidence = load_hf_revision_evidence()
    summaries = ObjectSummary[]
    for dataset in DATASETS
        requested_id =
            dataset.base == "duffing_hf" ? hf_representative_id : REPRESENTATIVE_TRAJECTORY_ID
        summary = render_object(dataset.base, dataset.object_id, requested_id)
        push!(summaries, summary)
        @printf(
            "%-18s state=%d [%g, %g] control=%d [%g, %g]\n",
            summary.object_id,
            summary.state_samples,
            summary.state_time_start,
            summary.state_time_end,
            summary.control_samples,
            summary.control_time_start,
            summary.control_time_end,
        )
    end

    figure_paths = vcat([summary.state_path for summary in summaries], [summary.control_path for summary in summaries])
    expected_figure_count = 2 * length(DATASETS)
    count(isfile, figure_paths) == expected_figure_count || error("expected $(expected_figure_count) figure files")
    write_summary_csv(SUMMARY_PATH, summaries)
    write_hf_revision_csv(HF_REVISION_PATH, evidence)
    write_hf_pilot_csv(HF_PILOT_PATH, evidence)
    write_report(REPORT_PATH, summaries, evidence)
    isfile(SUMMARY_PATH) || error("summary table was not written: $(SUMMARY_PATH)")
    isfile(HF_REVISION_PATH) || error("DUF-HF revision table was not written: $(HF_REVISION_PATH)")
    isfile(HF_PILOT_PATH) || error("DUF-HF pilot table was not written: $(HF_PILOT_PATH)")
    isfile(REPORT_PATH) || error("report was not written: $(REPORT_PATH)")
    image_references = count(line -> occursin("](plots/", line), eachline(REPORT_PATH))
    image_references == expected_figure_count || error("report should contain $(expected_figure_count) embedded figure references")

    println("controlled_lowdim_v1 visualization completed")
    println("  figures: ", expected_figure_count)
    println("  summary: ", SUMMARY_PATH)
    println("  report: ", REPORT_PATH)
end

main()
