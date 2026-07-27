using JLD2
using Plots

const PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const DATASET_PATH = joinpath(
    PROJECT_ROOT,
    "data",
    "releases",
    "controlled_lowdim_v1",
    "duffing",
    "duffing_addc",
    "clean.jld2",
)
const OUTPUT_DIRECTORY = joinpath(
    PROJECT_ROOT,
    "runs",
    "smoke_tests",
    "controlled_lowdim_v1",
    "visualizations",
)

function trajectory_index(trajectory_ids::AbstractVector{<:Integer}, requested_id::Integer)
    index = findfirst(==(requested_id), trajectory_ids)
    isnothing(index) && error("trajectory_id=$(requested_id) is not present in the dataset")
    return index
end

function main()
    isfile(DATASET_PATH) || error("missing clean dataset: $(DATASET_PATH)")
    data = JLD2.load(DATASET_PATH)

    trajectory_id = 1
    row = trajectory_index(data["trajectory_id"], trajectory_id)
    time_state = vec(data["time_state"][row, :])
    time_transition = vec(data["time_transition"][row, :])
    state = data["state_physical_clean"][row, :, :]
    control = vec(data["control_left_clean"][row, :, 1])

    size(state, 2) == 2 || error("Duffing physical state must have two channels; found $(size(state, 2))")
    length(time_state) == size(state, 1) || error("state time axis is not aligned with physical state")
    length(time_transition) == length(control) || error("transition time axis is not aligned with control")
    all(isfinite, state) || error("physical-state trajectory contains non-finite values")
    all(isfinite, control) || error("control trajectory contains non-finite values")

    mkpath(OUTPUT_DIRECTORY)
    state_path = joinpath(OUTPUT_DIRECTORY, "duffing_addc_state_trajectory_001.png")
    control_path = joinpath(OUTPUT_DIRECTORY, "duffing_addc_control_trajectory_001.png")

    displacement_plot = plot(
        time_state,
        state[:, 1];
        color = :royalblue,
        dpi = 200,
        legend = false,
        linewidth = 1.5,
        xlabel = "Time t",
        ylabel = "Displacement x",
    )
    velocity_plot = plot(
        time_state,
        state[:, 2];
        color = :darkorange,
        legend = false,
        linewidth = 1.5,
        xlabel = "Time t",
        ylabel = "Velocity p",
    )
    state_plot = plot(
        displacement_plot,
        velocity_plot;
        layout = (2, 1),
        left_margin = 12 * Plots.mm,
        size = (1400, 900),
        plot_title = "duffing_addc: physical state (clean, trajectory 1)",
    )
    savefig(state_plot, state_path)

    control_plot = plot(
        time_transition,
        control;
        color = :seagreen,
        dpi = 200,
        legend = false,
        left_margin = 12 * Plots.mm,
        linewidth = 1.5,
        size = (1400, 450),
        title = "duffing_addc: left-endpoint control (clean, trajectory 1)",
        xlabel = "Time t",
        ylabel = "Control c(t)",
    )
    savefig(control_plot, control_path)

    isfile(state_path) || error("state figure was not written: $(state_path)")
    isfile(control_path) || error("control figure was not written: $(control_path)")
    println("visualization smoke passed")
    println("  dataset_id: ", data["dataset_id"])
    println("  trajectory_id: ", trajectory_id, " (split=", data["split_id"][row], ")")
    println("  state shape: ", size(state), "; control length: ", length(control))
    println("  state figure: ", state_path)
    println("  control figure: ", control_path)
end

main()
