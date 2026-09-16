# HSKL Baseline ODE v1 Release File Explanation

## Task Summary

This task created the `hskl_baseline_ode_v1` full-state clean ODE release for downstream HSKL baseline tests. The release fixes `observation_mode = full_state` and `noise_level = clean`, so every processed object stores

```math
\mathcal Z = \mathcal X,
\qquad
\mathcal Y = \mathcal X.
```

The formal generation run produced the `medium` profile for 11 ODE systems and 28 named parameter-regime objects.

## Run Entry Points and Scripts

- `experiments/data_generation/generate_hskl_baseline_ode_v1_formal_dataset.jl`: formal generation entry point.
- `src/data/hskl_baseline_ode_v1_generation.jl`: registry, ODE right-hand sides, fixed-step RK4 integration, initial-condition sampling, split metadata, release IO, validation tables, plots, manifest writing, and report writing.
- `test/unit/test_hskl_baseline_ode_v1_registry.jl`: registry invariant test for fixed release identity, allowed system ids, and medium window feasibility.

## Core Source, Configs, and Docs Changed

- `configs/data/hskl_baseline_ode_v1_release.yaml`: release identity and fixed observation/noise fields.
- `configs/data/hskl_baseline_ode_v1_systems.yaml`: system list, layers, dimensions, sampling intervals, burn-in times, and parameter-regime names.
- `configs/data/hskl_baseline_ode_v1_parameter_regimes.yaml`: named parameter regimes and Split-P roles.
- `configs/data/hskl_baseline_ode_v1_splits.yaml`: trajectory-level Split-I and parameter-regime Split-P protocol.
- `configs/data/hskl_baseline_ode_v1_observation_full_state_clean.yaml`: full-state clean observation contract.
- `configs/windows/hskl_baseline_ode_v1_windows.yaml`: small, medium, and large HSKL window profiles.
- `configs/experiments/hskl_baseline_ode_v1_generation_formal.json`: formal generation declaration.
- `configs/experiments/hskl_baseline_ode_v1_generation_smoke.json`: smoke-profile declaration for later manual reuse.
- `docs/spec/hskl_baseline_ode_v1_registry.md`: top-level release registry.
- `docs/spec/hskl_baseline_ode_v1_system_registry.md`: system registry table.
- `docs/spec/hskl_baseline_ode_v1_observation_protocol.md`: full-state clean observation protocol.
- `docs/spec/hskl_baseline_ode_v1_release_manifest_schema.md`: manifest schema.

## Generated Data, Artifacts, Reports, and Logs

Generated data is local output and remains ignored by git according to the project `.gitignore`.

- `data/releases/hskl_baseline_ode_v1/processed/`: 28 processed JLD2 trajectory objects.
- `data/releases/hskl_baseline_ode_v1/raw/`: raw state tensor mirrors for the same 28 objects.
- `data/releases/hskl_baseline_ode_v1/metadata/release_manifest.json`: global release manifest.
- `data/releases/hskl_baseline_ode_v1/metadata/systems.csv`: system metadata table.
- `data/releases/hskl_baseline_ode_v1/metadata/parameter_regimes.csv`: parameter-regime metadata table.
- `data/releases/hskl_baseline_ode_v1/metadata/splits.csv`: Split-I count table.
- `data/releases/hskl_baseline_ode_v1/metadata/window_profiles.csv`: HSKL window feasibility table.
- `reports/hskl_baseline_ode_v1/tables/`: five human-readable validation and summary CSV files.
- `reports/hskl_baseline_ode_v1/plots/`: 22 diagnostic trajectory and phase or coordinate-summary PNG files.
- `reports/hskl_baseline_ode_v1/logs/`: generation and validation logs.
- `reports/hskl_baseline_ode_v1/notebooks/hskl_baseline_ode_v1_release_report.md`: mathematical release report using generated validation data.

## Script-to-Script Data Flow

1. The formal entry point includes `src/data/hskl_baseline_ode_v1_generation.jl`.
2. The generator freezes release constants, difficulty profiles, systems, parameter regimes, observation rules, and split metadata.
3. For each `system_id`, `parameter_regime`, and `medium` difficulty object, the generator samples trajectory-level initial conditions, applies burn-in when declared, integrates with fixed-step RK4, and stacks trajectories into `state_tensor`.
4. The processed tensors are saved as `state_tensor`, `input_tensor`, and `target_tensor`, with `input_tensor == state_tensor` and `target_tensor == state_tensor`.
5. The generator writes object metadata, global metadata tables, validation rows, plots, logs, and the final release manifest.

## Validation Commands and Results

Formal generation command:

```powershell
julia --project=. experiments/data_generation/generate_hskl_baseline_ode_v1_formal_dataset.jl
```

Result:

- Generated objects: 28.
- Passed objects: 28.
- Failure counters: all zero.
- Representative Lorenz96 shape check: `(40, 1025, 48)`.
- Representative full-state checks: `max|Z-X| = 0.0`, `max|Y-X| = 0.0`.

Registry test command:

```powershell
julia --project=. test/unit/test_hskl_baseline_ode_v1_registry.jl
```

Result:

- `52/52` assertions passed.
