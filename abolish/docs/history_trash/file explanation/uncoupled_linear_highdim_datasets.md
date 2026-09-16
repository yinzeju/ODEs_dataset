# Uncoupled Linear High-Dimensional Dataset Generation

## Task summary

This task generated high-dimensional uncoupled variants of three existing linear baseline systems at state dimensions 4, 8, and 16:

- `linear_diagonal`: the baseline 4D diagonal spectrum `[-1.0, -0.3, 0.1, 0.5]` is repeated to fill the requested dimension.
- `linear_rotation_contraction_uncoupled`: independent 2D rotation-contraction blocks reuse the baseline `gamma=0.15`, `omega=2pi`, `dt=0.01`, length 500, and 64 trajectories.
- `linear_oscillator`: independent 2D damped oscillator blocks reuse the baseline `gamma=0.05`, `omega0=1.0`, `dt=0.02`, length 3000, and 256 trajectories.

No off-block coupling terms were added. Each generated manifest records the `dimension_lift_policy` used for the dataset.

## Run entry points and scripts

- `experiments/data_generation/generate_uncoupled_linear_highdim_datasets.jl`

Run command:

```powershell
julia --project=. experiments/data_generation/generate_uncoupled_linear_highdim_datasets.jl
```

The script derives the required high-dimensional configs, generates all nine datasets, writes manifests and local diagnostics, and prints one summary row per dataset.

## Core source, configs, and docs changed

Generated system configs:

- `configs/systems/unit_internal/linear_diagonal_uncoupled_d4.json`
- `configs/systems/unit_internal/linear_diagonal_uncoupled_d8.json`
- `configs/systems/unit_internal/linear_diagonal_uncoupled_d16.json`
- `configs/systems/unit_internal/linear_rotation_contraction_uncoupled_d4.json`
- `configs/systems/unit_internal/linear_rotation_contraction_uncoupled_d8.json`
- `configs/systems/unit_internal/linear_rotation_contraction_uncoupled_d16.json`
- `configs/systems/v1_core/linear_oscillator_uncoupled_d4.json`
- `configs/systems/v1_core/linear_oscillator_uncoupled_d8.json`
- `configs/systems/v1_core/linear_oscillator_uncoupled_d16.json`

Generated observation configs:

- `configs/observations/unit_internal/full_state_identity_clean_d4.json`
- `configs/observations/unit_internal/full_state_identity_clean_d8.json`
- `configs/observations/unit_internal/full_state_identity_clean_d16.json`
- `configs/observations/full_state_4d_clean.json`
- `configs/observations/full_state_8d_clean.json`
- `configs/observations/full_state_16d_clean.json`

## Generated data, artifacts, reports, and logs

Data and report outputs are intentionally local generated artifacts under ignored project directories.

Raw and processed data:

- `data/raw/unit_internal/linear_diagonal/uncoupled_d*/raw_trajectories.jld2`
- `data/processed/unit_internal/linear_diagonal/full_state_clean_d*/uncoupled_d*/observed_trajectories.jld2`
- `data/raw/unit_internal/linear_rotation_contraction_uncoupled/uncoupled_d*/raw_trajectories.jld2`
- `data/processed/unit_internal/linear_rotation_contraction_uncoupled/full_state_clean_d*/uncoupled_d*/observed_trajectories.jld2`
- `data/raw/v1_core/linear_oscillator/uncoupled_d*/raw_trajectories.jld2`
- `data/processed/v1_core/linear_oscillator/full_state_*d_clean/uncoupled_d*/observed_trajectories.jld2`

Manifests:

- `data/manifests/unit_internal/linear_diagonal/uncoupled_d*/manifest.json`
- `data/manifests/unit_internal/linear_rotation_contraction_uncoupled/uncoupled_d*/manifest.json`
- `data/manifests/v1_core/linear_oscillator/uncoupled_d*/manifest.json`

Report and diagnostics:

- `reports/highdim_uncoupled_linear/generation_summary.json`
- `reports/highdim_uncoupled_linear/notebooks/highdim_uncoupled_linear_report.md`
- per-dataset `reports/<scope>/<system>_<variant>/tables/diagnostics.csv`
- per-dataset `reports/<scope>/<system>_<variant>/logs/generation.log`

## Script-to-script data flow

The generation script reads the baseline configs, derives high-dimensional configs, samples initial conditions, propagates exact uncoupled linear dynamics, writes raw tensors, copies full-state observations into processed tensors, builds trajectory-level Split-I, writes one-step and rollout window summaries, and records diagnostics in each manifest.

Array layout is always:

```text
state_dim_by_time_by_trajectory
```

Each single-trajectory state matrix has shape:

```text
state_dim x (trajectory_length + 1)
```

## Validation commands and results

Command:

```powershell
julia --project=. experiments/data_generation/generate_uncoupled_linear_highdim_datasets.jl
```

Result: all 9 datasets passed the generator diagnostics. The largest reported one-step residual was about `1.519e-13`, the largest sampled rollout residual was about `1.521e-13`, and the largest spectrum error was about `2.247e-16`.
