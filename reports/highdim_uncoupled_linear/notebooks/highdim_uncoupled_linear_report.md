# Uncoupled Linear High-Dimensional Dataset Report

## Summary

The high-dimensional uncoupled linear dataset task generated 4D, 8D, and 16D variants for the existing diagonal, rotation-contraction, and damped oscillator baselines.

The construction preserves all baseline settings except state dimension. No coupling was introduced:

- diagonal systems repeat the 4D baseline eigenvalue list;
- rotation-contraction systems repeat independent 2D spiral blocks;
- oscillator systems repeat independent 2D damped oscillator blocks.

## Generated datasets

| System kind | Variant | State dim | Trajectories | Length | Status |
| --- | --- | ---: | ---: | ---: | --- |
| linear diagonal | `uncoupled_d4` | 4 | 64 | 200 | passed |
| linear diagonal | `uncoupled_d8` | 8 | 64 | 200 | passed |
| linear diagonal | `uncoupled_d16` | 16 | 64 | 200 | passed |
| rotation-contraction | `uncoupled_d4` | 4 | 64 | 500 | passed |
| rotation-contraction | `uncoupled_d8` | 8 | 64 | 500 | passed |
| rotation-contraction | `uncoupled_d16` | 16 | 64 | 500 | passed |
| damped oscillator | `uncoupled_d4` | 4 | 256 | 3000 | passed |
| damped oscillator | `uncoupled_d8` | 8 | 256 | 3000 | passed |
| damped oscillator | `uncoupled_d16` | 16 | 256 | 3000 | passed |

## Validation

Executed:

```powershell
julia --project=. experiments/data_generation/generate_uncoupled_linear_highdim_datasets.jl
```

All datasets passed exact-dynamics checks. Maximum reported diagnostics across the run:

- one-step residual: approximately `1.519e-13`
- sampled rollout residual: approximately `1.521e-13`
- discrete spectrum error: approximately `2.247e-16`

## Output locations

Primary manifests are under:

- `data/manifests/unit_internal/linear_diagonal/uncoupled_d*/manifest.json`
- `data/manifests/unit_internal/linear_rotation_contraction_uncoupled/uncoupled_d*/manifest.json`
- `data/manifests/v1_core/linear_oscillator/uncoupled_d*/manifest.json`

Raw and processed tensors are under the matching `data/raw/` and `data/processed/` paths named in each manifest.

## Next manual step

Downstream learners can consume the generated JLD2 tensors directly using the manifest `array_layout = state_dim_by_time_by_trajectory` and the split/window summary JSON files for each variant.
