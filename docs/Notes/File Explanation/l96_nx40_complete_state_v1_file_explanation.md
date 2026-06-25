# l96_nx40_complete_state_v1 File Explanation

## Task Summary

This task generated the dedicated Lorenz96 complete-state dataset requested by `docs/notes/mathematical explanation/lorenz96_nx40_complete_state_v1.md`. The dataset fixes `N_x=40`, `F0=8`, RK4 internal step `dt_internal=0.005`, save stride `q_save=10`, learning interval `tau=0.05`, burn-in time `100.0`, and `M_traj=2048` one-step pairs per trajectory. It contains 40 independent burn-in trajectories split by trajectory into 24 train, 8 validation, and 8 test trajectories.

The generated learning object is the full physical state with `z_m = y_m = x_m`. No observation noise, partial observation, control input, delay embedding, spatial patching, data augmentation, model training, kernel selection, or spectrum estimation was added.

## Run Entry Points and Scripts

- `experiments/data_generation/generate_l96_nx40_complete_state_v1_dataset.jl`: formal data-generation entry point used for the completed run.
- `src/data/l96_nx40_complete_state_v1_generation.jl`: reusable implementation for seed spawning, Lorenz96 RK4 integration, split tensor writing, normalization statistics, diagnostics, report tables, and report generation.
- `test/unit/test_l96_nx40_complete_state_v1_generation.jl`: lightweight contract test for fixed constants, periodic boundary indexing, split counts, and window counts.

The formal generation command was:

```powershell
julia --project=. experiments/data_generation/generate_l96_nx40_complete_state_v1_dataset.jl
```

The direct unit contract check was:

```powershell
julia --project=. test/unit/test_l96_nx40_complete_state_v1_generation.jl
```

## Core Source, Configs, and Docs Changed

- `src/data/l96_nx40_complete_state_v1_generation.jl` implements a preallocated Float64 RK4 kernel for Lorenz96 with periodic indexing, deterministic trajectory seed spawning from master seed `20260624`, train-only global space-shared normalization, and formal acceptance checks.
- `configs/systems/v1_core/l96_nx40_complete_state_v1.json` records the fixed dynamical-system and integration settings.
- `configs/splits/v1_core/l96_nx40_complete_state_v1_split_i.json` records the trajectory-level Split-I counts and deterministic ordered assignment policy.
- `configs/windows/v1_core/l96_nx40_complete_state_v1_windows.json` records one-step and rollout-window settings with `h_max=64` and horizons `{1,2,4,8,16,32,64}`.
- `configs/tasks/v1_core/l96_nx40_complete_state_v1_tasks.json` records downstream one-step and rollout task identities.
- `configs/releases/l96_nx40_complete_state_v1_release.json` records the release identity and output root.

The split assignment is a minimal engineering choice because the mathematical explanation fixes split counts but does not prescribe a shuffle seed for assigning trajectories to splits. The implementation uses deterministic ordered trajectory blocks: trajectories 1-24 train, 25-32 validation, and 33-40 test. All trajectory seeds are recorded in `splits.json` and `metadata.json`.

## Generated Data, Artifacts, Reports, and Logs

The formal dataset root is:

- `data/releases/l96_nx40_complete_state_v1/`

Its main generated files are:

- `metadata.json`: system, integration, seed, array-layout, acceptance, and generated-file metadata.
- `normalization.json`: train-only shared spatial statistics with `mu_sp=2.344406409823796`, `sigma_sp=3.6410135617242063`, and `epsilon_std=1.0e-8`.
- `splits.json`: all trajectory IDs, split labels, and per-trajectory seeds.
- `train/trajectories.jld2`: Float64 tensor with shape `(24, 2049, 40)`.
- `val/trajectories.jld2`: Float64 tensor with shape `(8, 2049, 40)`.
- `test/trajectories.jld2`: Float64 tensor with shape `(8, 2049, 40)`.
- `diagnostics/integration_check.json`: RK4 coarse-versus-half-step consistency check.
- `diagnostics/trajectory_statistics.json`: per-trajectory and split energy statistics.
- `diagnostics/diagnostics_summary.json`: compact acceptance summary.

The human-readable report and report-local tables/log are under:

- `reports/v1_core/l96_nx40_complete_state_v1/notebooks/l96_nx40_complete_state_v1_report.md`
- `reports/v1_core/l96_nx40_complete_state_v1/tables/trajectory_energy_statistics.csv`
- `reports/v1_core/l96_nx40_complete_state_v1/tables/diagnostics_summary.csv`
- `reports/v1_core/l96_nx40_complete_state_v1/logs/generate_l96_nx40_complete_state_v1.log`

Generated `data/` and `reports/` outputs remain local ignored outputs under the project `.gitignore` policy.

## Script-to-Script Data Flow

The experiment entry point includes `src/data/l96_nx40_complete_state_v1_generation.jl` and calls `generate_l96_nx40_complete_state_v1(PROJECT_ROOT)`. The generator builds independent trajectory seeds, integrates each pre-burn-in initial condition for 20,000 internal RK4 steps, records 2049 snapshots at stride 10 internal steps, partitions the trajectory tensor into split-level JLD2 files, computes train-only normalization statistics, runs acceptance diagnostics, and writes JSON/CSV/Markdown outputs.

Downstream loaders should consume split tensors with layout `trajectory_by_time_by_state`. One-step samples and rollout windows should be constructed by index within each split, not materialized as duplicated tensors.

## Validation Commands and Results

The lightweight contract test passed:

```text
Test Summary:                        | Pass  Total  Time
l96_nx40_complete_state_v1 contracts |   18     18  0.8s
```

The formal generation passed with these key results:

| Metric | Result |
| --- | ---: |
| Full tensor shape before split | `(40, 2049, 40)` |
| Train / val / test tensor shapes | `(24,2049,40)` / `(8,2049,40)` / `(8,2049,40)` |
| One-step pairs train / val / test | `49152` / `16384` / `16384` |
| Valid `h_max=64` windows train / val / test | `47640` / `15880` / `15880` |
| State range | `[-10.605407105349045, 16.18972475599717]` |
| Train `mu_sp` | `2.344406409823796` |
| Train `sigma_sp` | `3.6410135617242063` |
| Mean relative RK difference `epsilon_RK` | `1.1232081782017235e-8` |
| Max relative RK difference | `3.2749707295168676e-8` |
| Acceptance threshold | `1.0e-6` |
| Mean trajectory energy mean | `9.371498808398595` |
| Overall acceptance | `true` |

An independent readback check loaded the three JLD2 split files and verified their shapes and `diagnostics_summary.json["all_passed"] == true`.
