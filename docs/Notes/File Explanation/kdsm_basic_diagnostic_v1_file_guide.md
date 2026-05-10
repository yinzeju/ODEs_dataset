# KDSM Basic Diagnostic v1 File Guide

## Task Summary

This task implemented and generated the `kdsm_basic_diagnostic_v1` release for the `ODEs_dataset` project. The release is a data-side diagnostic ladder for downstream KDSM checks, not a training task. It contains eight unforced 2D objects:

- `kdsm_basic__L0_discrete_damped_rotation`
- `kdsm_basic__L1_continuous_linear_oscillator`
- `kdsm_basic__BETA_0000_linear_duffing`
- `kdsm_basic__BETA_0001_weak_duffing`
- `kdsm_basic__BETA_0010_weak_duffing`
- `kdsm_basic__BETA_0050_weak_duffing`
- `kdsm_basic__BETA_0100_weak_duffing`
- `kdsm_basic__D0_reference_near_linear_damped`

The final object supplies the `beta=0.02` endpoint from the mathematical guide, so no separate `BETA_0200` object is used.

## Run Entry Points And Scripts

- `experiments/smoke_tests/run_kdsm_basic_diagnostic_v1_smoke.jl` generates a bounded smoke release with `R=12`, `M=32`, and `tau=0.05`.
- `experiments/baseline_forecasting/run_kdsm_basic_diagnostic_v1_data_checks.jl` generates the formal release with `R=64`, `M=256`, and `tau=0.05`.

Both scripts include the task-specific source files directly and call `kbasic_run_release_generation`.

## Core Source, Configs, And Docs Changed

- System, observation, split, window, task, benchmark, and release configs were added under `configs/`.
- Reusable source was added under `src/dynamics/`, `src/observations/`, `src/splits/`, `src/windows/`, `src/datasets/`, `src/io/`, `src/manifests/`, `src/registries/`, `src/diagnostics/`, and `src/generators/`.
- Tests were added under `test/unit/`, `test/integration/`, and `test/regression/`.
- Registry entries were added to `docs/spec/object_registry.md` and `docs/spec/project_task_list.md`.

## Generated Data, Artifacts, Reports, And Logs

The formal run generated local ignored outputs under:

- `data/raw/kdsm_basic_diagnostic_v1/`
- `data/processed/kdsm_basic_diagnostic_v1/`
- `data/manifests/kdsm_basic_diagnostic_v1/`
- `data/releases/kdsm_basic_diagnostic_v1/`
- `reports/unit_internal/kdsm_basic_diagnostic_v1/`

Each object has one raw JLD2 file, one processed JLD2 file, and one TOML manifest. The release folder contains `release_index.toml`, `kdsm_basic_diagnostic_v1_manifest.toml`, and `checksums.toml`.

## Script-To-Script Data Flow

The entry scripts load frozen TOML configs, build the fixed diagnostic ladder, sample deterministic amplitude-stratified initial conditions, generate raw state tensors, build identity observations and targets, assign trajectory-level split roles, attach one-step and rollout window metadata, run diagnostics, save raw and processed JLD2 files, write object manifests, and assemble release-level manifests and CSV report tables.

The tensor layout is `trajectory_by_time_by_channel`, so formal tensors have shape `(64, 257, 2)`. `obs_phys`, `obs_aug_full`, and `target_phys` are exact copies of the raw state tensor for every object.

## Validation Commands And Results

- `julia --project=. experiments/smoke_tests/run_kdsm_basic_diagnostic_v1_smoke.jl` passed for all 8 objects with smoke shape `(12, 33, 2)` and split `8/2/2`.
- `julia --project=. experiments/baseline_forecasting/run_kdsm_basic_diagnostic_v1_data_checks.jl` passed for all 8 objects with formal shape `(64, 257, 2)` and split `48/8/8`.
- `julia --project=. test/unit/test_kdsm_basic_diagnostic_system_specs.jl` passed.
- `julia --project=. test/unit/test_kdsm_basic_diagnostic_observations.jl` passed.
- `julia --project=. test/unit/test_kdsm_basic_diagnostic_splits.jl` passed.
- `julia --project=. test/unit/test_kdsm_basic_diagnostic_windows.jl` passed.
- `julia --project=. test/integration/test_kdsm_basic_diagnostic_generation.jl` passed.
- `julia --project=. test/regression/test_kdsm_basic_diagnostic_reference_stats.jl` passed.

The formal release diagnostics report `all_passed=true`; all objects have finite values, identity observation/target tensors, nonempty small/mid/large amplitude groups, and the requested trajectory-level split counts.
