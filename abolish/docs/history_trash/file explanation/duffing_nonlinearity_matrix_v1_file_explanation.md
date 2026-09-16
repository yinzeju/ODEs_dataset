# Duffing Nonlinearity Matrix v1 File Explanation

## Task Summary

This task generated and then extended the formal `duffing_nonlinearity_matrix_v1` dataset from `docs/notes/mathematical explanation/duffing_nonlinearity_matrix_v1_math.md`.

The current v1.1 release contains 56 objects: 2 linear health-check objects and 54 Duffing cells over `beta in {0, 0.05, 0.2, 0.5, 1, 2, 5, 10, 20}` and `Q in {0.25, 0.5, 1.0, 1.5, 2.0, 4.0}`. Every object uses shape `(512, 1025, 2)`, trajectory-level split counts `384/64/64`, clean full-state observations, and target tensors equal to the physical state.

The v1.1 extension adds the `beta=20` row and the `Q=4` column to the original `8 x 5` grid. This adds 14 Duffing cells and raises the maximum nonlinearity index from `chi_nl=40` to `chi_nl=320` at `D_beta_20000__Q_400`.

## Run Entry Points And Scripts

The formal generation entry point is:

- `experiments/data_generation/generate_duffing_nonlinearity_matrix_v1_dataset.jl`

It includes:

- `src/dynamics/duffing_nonlinearity_matrix_v1_systems.jl`
- `src/generators/duffing_nonlinearity_matrix_v1_generator.jl`

The formal command used for validation was:

```text
$env:JULIA_NUM_THREADS='auto'; julia --project=. experiments/data_generation/generate_duffing_nonlinearity_matrix_v1_dataset.jl
```

## Core Source, Configs, And Docs Changed

Core source:

- `src/dynamics/duffing_nonlinearity_matrix_v1_systems.jl` defines object specs, object ID formatting, exact L0 metadata, linear oscillator metadata, shell initial-condition sampling, Duffing energy, and the self-contained embedded Dormand-Prince 5(4) adaptive stepper.
- `src/generators/duffing_nonlinearity_matrix_v1_generator.jl` loads configs, builds the 56-object plan, creates shared initial-condition libraries by `Q`, builds split/window metadata, saves raw and processed JLD2 tensors, writes object/release manifests, writes report tables, and validates the release.
- Extreme cells with `chi_nl >= 80` use stricter integration settings: `reltol=1.0e-11`, `abstol=1.0e-13`, and `max_internal_step=0.0005`.

Configs:

- `configs/systems/duffing_nonlinearity_matrix_v1_systems.toml`
- `configs/observations/duffing_nonlinearity_matrix_v1_observations.toml`
- `configs/splits/duffing_nonlinearity_matrix_v1_split_trajectory_I.toml`
- `configs/windows/duffing_nonlinearity_matrix_v1_windows.toml`
- `configs/tasks/duffing_nonlinearity_matrix_v1_tasks.toml`
- `configs/benchmarks/duffing_nonlinearity_matrix_v1_benchmark.toml`
- `configs/releases/duffing_nonlinearity_matrix_v1_release.toml`

Completion docs:

- `reports/v1_core/duffing_nonlinearity_matrix_v1/notebooks/duffing_nonlinearity_matrix_v1_report.md`
- `docs/notes/file explanation/duffing_nonlinearity_matrix_v1_file_explanation.md`
- `docs/spec/object_registry.md`
- `docs/spec/project_task_list.md`

## Generated Data, Artifacts, Reports, And Logs

Generated data are local release outputs under:

- `data/raw/duffing_nonlinearity_matrix_v1/<object_id>/raw_trajectories.jld2`
- `data/processed/duffing_nonlinearity_matrix_v1/<object_id>/processed_tensors.jld2`
- `data/manifests/duffing_nonlinearity_matrix_v1/<object_id>_manifest.toml`
- `data/releases/duffing_nonlinearity_matrix_v1/duffing_nonlinearity_matrix_v1_manifest.toml`
- `data/releases/duffing_nonlinearity_matrix_v1/release_index.toml`
- `data/releases/duffing_nonlinearity_matrix_v1/checksums.toml`

Generated report evidence:

- `reports/v1_core/duffing_nonlinearity_matrix_v1/tables/duffing_nonlinearity_matrix_v1_object_summary.csv`
- `reports/v1_core/duffing_nonlinearity_matrix_v1/tables/duffing_nonlinearity_matrix_v1_duffing_matrix_summary.csv`
- `reports/v1_core/duffing_nonlinearity_matrix_v1/tables/duffing_nonlinearity_matrix_v1_window_counts.csv`
- `reports/v1_core/duffing_nonlinearity_matrix_v1/logs/duffing_nonlinearity_matrix_v1_generation.log`

## Script-To-Script Data Flow

1. The experiment entry point resolves `PROJECT_ROOT` and includes the dynamics and generator source files.
2. The generator loads the seven TOML configs under `configs/`.
3. The generation plan creates two linear base specs and fifty-four Duffing cell specs.
4. The generator builds one trajectory-level split with counts `384/64/64`.
5. For each `Q`, it creates one fixed shell-sampled initial-condition library and reuses that library across all beta values.
6. Each object produces a state tensor with shape `(512, 1025, 2)`.
7. The processed tensors are saved with `obs_phys`, `obs_full`, and `target_phys` equal to `state`.
8. Object manifests, release manifests, checksums, report tables, and logs are written after reload and diagnostic checks pass.

## Validation Commands And Results

Static parse check:

```text
julia --project=. -e 'for path in ["src/dynamics/duffing_nonlinearity_matrix_v1_systems.jl", "src/generators/duffing_nonlinearity_matrix_v1_generator.jl", "experiments/data_generation/generate_duffing_nonlinearity_matrix_v1_dataset.jl"]; code = read(path, String); Meta.parseall(code); println("parsed: ", path); end'
```

Result: all three Julia files parsed successfully.

Formal generation command:

```text
$env:JULIA_NUM_THREADS='auto'; julia --project=. experiments/data_generation/generate_duffing_nonlinearity_matrix_v1_dataset.jl
```

Result:

- `release_version = 1.1.0`
- `object_count = 56`
- `duffing_cell_count = 54`
- all tensors have shape `(512, 1025, 2)`
- split counts are `384/64/64`
- `chi_nl` range is `[0, 320]`
- maximum state absolute value is `50.27196480193124`
- maximum energy violation count is `0`
- maximum linear recurrence residual is `1.7763568394002505e-15`
- initial-condition reuse across beta passed for every fixed `Q`
- release index reports `all_passed = true`
