# Active Dataset Code Renaming

## Task Summary

The active dataset identities were normalized without changing numerical trajectories, release versions, split definitions, observation policies, or the retained `duffing_aug_snr10` object. The canonical identifiers are now `lowdim_nonlinear_v1`, `duffing_aug_snr10`, and `highdim_nonlinear_v2`.

## Updated Entry Points

- `experiments/data_generation/generate_lowdim_nonlinear_v1_dataset.jl` generates the low-dimensional release.
- `experiments/data_generation/generate_highdim_nonlinear_v2_dataset.jl` generates the high-dimensional release.
- `experiments/smoke_tests/run_lowdim_nonlinear_v1_smoke.jl` and `experiments/smoke_tests/run_highdim_nonlinear_v2_smoke.jl` provide the minimal end-to-end checks.
- `experiments/data_generation/rename_active_dataset_codes.jl` performs the metadata migration for the existing local formal data.

## Renamed Objects

| Previous identifier | Canonical identifier | Scope |
| --- | --- | --- |
| `standard_odes_v1` | `lowdim_nonlinear_v1` | Dataset, source and experiment entry points, local data directories, reports, manifests, and mathematical/file explanations |
| `high_dimensional_nonlinear_dynamics_v2` | `highdim_nonlinear_v2` | Dataset, source and experiment entry points, configuration, local data directories, reports, certificates, and mathematical/file explanations |
| `duffing_aug_snr10` | `duffing_aug_snr10` | Unchanged |

## Data And Metadata Migration

The existing low-dimensional local release directories were renamed under `data/processed/`, `data/manifests/`, and `data/releases/`. The existing high-dimensional release directory was renamed under `data/releases/`. The migration script updates the `dataset_id` stored in every low-dimensional JLD2 object, adds or updates the `task_code` in every high-dimensional HDF5 metadata group, and rewrites local JSON, CSV, and log references. It does not regenerate trajectories or modify state tensors.

## Validation

The completed validation commands were:

```powershell
julia --project=. experiments/data_generation/rename_active_dataset_codes.jl
julia --project=. experiments/smoke_tests/run_lowdim_nonlinear_v1_smoke.jl
julia --project=. experiments/smoke_tests/run_highdim_nonlinear_v2_smoke.jl
julia --project=. test/unit/test_highdim_nonlinear_v2.jl
```

The low-dimensional smoke release completed with `all_passed=true`. The high-dimensional smoke entry point completed successfully. The high-dimensional unit suite passed all 27 checks, and direct JLD2/HDF5 readback confirmed `lowdim_nonlinear_v1` and `highdim_nonlinear_v2` metadata values.
