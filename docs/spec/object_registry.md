# Development Log

This registry records the current engineering history of `ODEs_dataset`.
Dataset-facing release summaries are maintained in `project_task_list.md`.

Status values: `success`, `failed`, `blocked`.

## Chronological Development History

| Date | Task | Status | Main object(s) | Key settings | Validation result | Details |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-10 | Active dataset consolidation and raw-coordinate regeneration | success | `lowdim_nonlinear_v1`; `duffing_aug_snr10`; `highdim_nonlinear_v2` | Retained the low-dimensional, controlled, and high-dimensional dataset groups; removed dataset-level standardization from Duffing and the low-dimensional nonlinear suite; archived 58 retired mathematical/code/file explanations; deleted retired configs, source, experiments, tests, data, runs, reports, and obsolete specs | Duffing and the low-dimensional nonlinear suite were regenerated from their active generators; raw-coordinate metadata and JLD2 readback passed; old storage cleanup reclaimed approximately 5.19 GiB | `docs/Notes/File Explanation/dataset_consolidation_20260710_file_explanation.md` |
| 2026-07-10 | Duffing augmented SNR10 raw release | success | `duffing_aug_snr10` | 768 trajectories; Split-I `512/128/128`; 2,000 snapshots; clean and 10 dB noisy physical-state inputs; shared sparse multisine; `normalization_policy=none_raw_physical_coordinates` | Formal generation passed; shapes `[768,2000,2]`; train SNR `x=9.99336 dB`, `v=9.99278 dB`; phase and forcing consistency checks passed | `docs/Notes/File Explanation/duffing_aug_snr10_file_explanation.md` |
| 2026-07-10 | Low-dimensional nonlinear v1 raw-coordinate regeneration | success | `lowdim_nonlinear_v1` | Eight objects; clean, 5 dB, and 15 dB observation modes; Float32 persistence; raw physical coordinates; no stored standardization resources | Formal generation produced all eight objects with `all_passed=true`; 9,821,696 state vectors and 7,357,440 training one-step pairs per observation mode | `docs/Notes/File Explanation/lowdim_nonlinear_v1_file_explanation.md` |
| 2026-07-10 | High-dimensional nonlinear v2 release | success | `l96_nx40_raw_v2`; `ks64_raw_v2`; `fhn64_raw_v2` | Fresh independent integration; 480 trajectories per system; Split-I `320/80/80`; raw Float64; no normalization | Unit tests `27/27`, smoke, formal generation, HDF5 readback, numerical certificates, split checks, and duplicate checks passed | `docs/Notes/File Explanation/highdim_nonlinear_v2_file_explanation.md` |
