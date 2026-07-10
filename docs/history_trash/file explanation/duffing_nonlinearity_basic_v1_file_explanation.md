# Duffing Nonlinearity Basic v1 File Explanation

## Task Summary

This task created `duffing_nonlinearity_basic_v1`, a compact Duffing hardening
release for quick downstream testing. The release contains two linear
health-check objects and five nonlinear Duffing objects ordered by
`\chi_nl = beta * Q^2`: `0.05`, `1.0`, `5.0`, `40.0`, and `320.0`.

The data were generated independently from new configuration and generation
entry points. No tensors were copied or split from `duffing_nonlinearity_matrix_v1`.

## Run Entry Points And Scripts

| Purpose | Entry point |
| --- | --- |
| Smoke validation | `experiments/smoke_tests/run_duffing_nonlinearity_basic_v1_smoke.jl` |
| Formal generation | `experiments/data_generation/generate_duffing_nonlinearity_basic_v1_dataset.jl` |
| Basic release generator | `src/generators/duffing_nonlinearity_basic_v1_generator.jl` |
| Shared Duffing integration and tensor helpers | `src/dynamics/duffing_nonlinearity_matrix_v1_systems.jl`; `src/generators/duffing_nonlinearity_matrix_v1_generator.jl` |

Smoke command:

```powershell
julia --project=. experiments\smoke_tests\run_duffing_nonlinearity_basic_v1_smoke.jl
```

Formal command:

```powershell
julia --project=. experiments\data_generation\generate_duffing_nonlinearity_basic_v1_dataset.jl
```

## Core Source, Configs, And Docs Changed

New configuration files define the release identity, object subset, Split-I
counts, observation convention, rollout windows, tasks, benchmark pointer, and
release manifest pointer:

| Config | Purpose |
| --- | --- |
| `configs/systems/duffing_nonlinearity_basic_v1_systems.toml` | Object plan, Duffing parameters, smoke and formal profiles, solver tolerances. |
| `configs/observations/duffing_nonlinearity_basic_v1_observations.toml` | Full-state clean observation and target keys. |
| `configs/splits/duffing_nonlinearity_basic_v1_split_trajectory_I.toml` | Smoke `6/1/1` and formal `48/8/8` trajectory splits. |
| `configs/windows/duffing_nonlinearity_basic_v1_windows.toml` | One-step lag and rollout horizons. |
| `configs/tasks/duffing_nonlinearity_basic_v1_tasks.toml` | One-step, rollout, and ordered nonlinearity comparison tasks. |
| `configs/benchmarks/duffing_nonlinearity_basic_v1_benchmark.toml` | Formal benchmark metadata. |
| `configs/releases/duffing_nonlinearity_basic_v1_release.toml` | Release-level config pointers and version. |

Documentation added:

| Document | Purpose |
| --- | --- |
| `docs/notes/mathematical explanation/duffing_nonlinearity_basic_v1_math.md` | Mathematical definition, object ordering, and formal profile. |
| `reports/v1_core/duffing_nonlinearity_basic_v1/notebooks/duffing_nonlinearity_basic_v1_report.md` | Evidence-backed engineering report. |
| `docs/notes/file explanation/duffing_nonlinearity_basic_v1_file_explanation.md` | File, data-flow, and validation summary. |

## Generated Data, Artifacts, Reports, And Logs

The formal run generated local ignored dataset files under:

| Output group | Path |
| --- | --- |
| Raw tensors | `data/raw/duffing_nonlinearity_basic_v1/<object_id>/raw_trajectories.jld2` |
| Processed tensors | `data/processed/duffing_nonlinearity_basic_v1/<object_id>/processed_tensors.jld2` |
| Object manifests | `data/manifests/duffing_nonlinearity_basic_v1/<object_id>_manifest.toml` |
| Release manifest | `data/releases/duffing_nonlinearity_basic_v1/duffing_nonlinearity_basic_v1_manifest.toml` |
| Release index | `data/releases/duffing_nonlinearity_basic_v1/release_index.toml` |
| Checksums | `data/releases/duffing_nonlinearity_basic_v1/checksums.toml` |
| Summary tables | `reports/v1_core/duffing_nonlinearity_basic_v1/tables/` |
| Generation log | `reports/v1_core/duffing_nonlinearity_basic_v1/logs/duffing_nonlinearity_basic_v1_generation.log` |

The formal release generated 7 objects. Each object has shape `(64, 513, 2)`,
clean `obs_phys=obs_full=target_phys`, and Split-I counts `48/8/8`.

## Script-To-Script Data Flow

1. The smoke and formal entry points include the existing Duffing matrix
   dynamics and helper generator files, then include the new basic-release
   generator.
2. The basic generator reads the new TOML configs, builds two linear specs and
   five Duffing specs sorted by `chi_nl`, and samples initial-condition
   libraries by amplitude level `Q`.
3. The generator integrates each object, constructs clean full-state
   observations and targets, assigns Split-I trajectory roles, writes raw and
   processed JLD2 tensors, writes object manifests, and reload-verifies raw and
   processed tensors.
4. After every object passes diagnostics, the generator writes report tables,
   release manifest, release index, checksums, and a generation log.

## Validation Commands And Results

Smoke validation passed:

| Check | Result |
| --- | --- |
| Command | `julia --project=. experiments\smoke_tests\run_duffing_nonlinearity_basic_v1_smoke.jl` |
| Object count | 7 |
| Duffing object count | 5 |
| Shape per object | `(8, 129, 2)` |
| Split counts | `6/1/1` |
| `chi_nl` sequence | `0.05, 1.0, 5.0, 40.0, 320.0` |
| All diagnostics passed | `true` |

Formal validation passed:

| Check | Result |
| --- | --- |
| Command | `julia --project=. experiments\data_generation\generate_duffing_nonlinearity_basic_v1_dataset.jl` |
| Object count | 7 |
| Duffing object count | 5 |
| Shape per object | `(64, 513, 2)` |
| Split counts | `48/8/8` |
| All diagnostics passed | `true` |
| Initial-condition reuse check | `true` |
| Maximum state absolute value | `49.200843043780296` |
| Maximum final energy violation count | `0` |

The formal object summaries are stored in
`reports/v1_core/duffing_nonlinearity_basic_v1/tables/duffing_nonlinearity_basic_v1_object_summary.csv`.
