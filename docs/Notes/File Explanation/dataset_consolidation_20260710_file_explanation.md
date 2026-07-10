# Dataset Consolidation 2026-07-10 File Explanation

## Task Summary

This maintenance task reduced `ODEs_dataset` to three active mathematical
objects that cover low-dimensional autonomous, controlled, and high-dimensional
nonlinear dynamics:

- `standard_odes_v1_math` / `standard_odes_v1`
- `duffing_aug_snr10`
- `High-Dimensional Nonlinear Dynamics Data Generation` / `high_dimensional_nonlinear_dynamics_v2`

The Duffing and Standard ODE releases were changed to an explicit raw physical
coordinate policy and regenerated from the retained generators. The existing
high-dimensional v2 release was already raw and was retained unchanged.

## Retained Entry Points

- `experiments/data_generation/generate_standard_odes_v1_dataset.jl`
- `experiments/data_generation/generate_duffing_aug_snr10_dataset.jl`
- `experiments/data_generation/generate_high_dimensional_nonlinear_dynamics_v2.jl`

Their corresponding smoke entry points and the high-dimensional unit test are
also retained.

## Raw-Coordinate Changes

`src/generators/duffing_aug_snr10_generator.jl` no longer computes or stores
clean-training means and standard deviations. Its JLD2 files and manifests now
declare `normalization_policy = none_raw_physical_coordinates`.

`src/data/standard_odes_v1_generation.jl` already persisted physical-coordinate
tensors. It now declares the same policy in every object and release manifest,
making the no-standardization contract machine-readable. The two mathematical
notes and active configuration records were updated consistently.

## Historical Archive And Deletion Scope

Retired objects retain explanatory source material only under
`docs/history_trash/`:

- 20 mathematical explanations
- 16 code explanations
- 22 generated file explanations

For retired objects, 323 files under `configs/`, `src/`, `experiments/`, and
`test/`, 257 report files, and 32 data/run directories were removed. Four
obsolete HSKL-specific spec documents were also removed. The cleanup reclaimed
approximately 5.19 GiB while preserving the three active releases and their
reports. The retained data, reports, and run files occupy approximately
3.17 GiB.

## Validation Results

- Duffing smoke and formal generation passed; the formal release contains 768
  trajectories with raw-coordinate clean and noisy JLD2 objects.
- Standard ODEs smoke and formal generation passed for all eight objects.
- Formal JLD2 readback found `normalization_policy` in all ten regenerated files
  and found no mean, standard deviation, standardization, normalized-state, or
  normalizer fields.
- High-dimensional v2 remains a fresh raw release with 480 trajectories per
  system; its unit tests passed 27/27 and all three HDF5 files contain no
  normalization group.
- All 15 retained Julia source, experiment, and test files parsed successfully.
- Retained include targets, active documentation links, and final dataset
  directory allowlists were checked after cleanup.
