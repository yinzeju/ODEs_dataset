# ODEs_dataset

`ODEs_dataset` is a Julia data-generation repository for nonlinear dynamical
systems. The active project is intentionally limited to three complementary
dataset groups:

| Dataset group | Scope | Active release |
| --- | --- | --- |
| `standard_odes_v1_math` | Low-dimensional autonomous systems | `standard_odes_v1` |
| `duffing_aug_snr10` | Controlled forced Duffing dynamics with clean and 10 dB noisy inputs | `duffing_aug_snr10` |
| `High-Dimensional Nonlinear Dynamics Data Generation` | L96-40, KS64, and FHN64 | `high_dimensional_nonlinear_dynamics_v2` |

All active data objects are stored in raw physical coordinates. Dataset
generation does not compute or persist means, standard deviations, normalized
tensors, or normalizer objects. Any downstream preprocessing must be fitted on
the training split and applied outside this repository's data objects.

## Project Layout

- `docs/Notes/mathematical explanation/` contains the three active mathematical specifications.
- `docs/Notes/File Explanation/` documents the active generators and outputs.
- `docs/spec/` contains the current development log and dataset task list.
- `src/`, `configs/`, and `experiments/` contain only the active generators and entry points.
- `data/` contains the three local formal releases.
- `reports/` contains only reports and diagnostics for the active releases.
- `docs/history_trash/` preserves mathematical and code explanations for retired objects; their executable code, data, reports, and task traces have been removed.

## Formal Entry Points

```powershell
julia --project=. experiments/data_generation/generate_standard_odes_v1_dataset.jl
julia --threads=auto --project=. experiments/data_generation/generate_duffing_aug_snr10_dataset.jl
julia --threads=16 --project=. experiments/data_generation/generate_high_dimensional_nonlinear_dynamics_v2.jl
```

Use `docs/spec/project_task_list.md` for the current release summary and
`docs/spec/object_registry.md` for engineering history.
