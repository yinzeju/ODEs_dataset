# Project Task List

This list contains only the three active dataset groups. Engineering cleanup is
recorded in `object_registry.md`.

Status values: `success`, `failed`, `blocked`.

## Active Dataset Releases

| Task | Execution time | Scope | Status | Configuration summary | Key result | Reuse note | Details |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Low-dimensional nonlinear v1 raw-coordinate release | 2026-07-10 | Low-dimensional autonomous nonlinear systems | success | Eight clean systems with 5 dB and 15 dB noisy observation variants; 512 trajectories per object except 8,192 pendulum trajectories; trajectory-level splits; raw physical coordinates; no standardization | All eight formal objects passed; 9,821,696 state vectors; 7,357,440 training one-step pairs per observation mode; approximately 475 MiB JLD2 data | Common source for compact forecasting, denoising, rollout, and operator-learning tasks. Fit downstream preprocessing on training data only | `docs/Notes/mathematical explanation/lowdim_nonlinear_v1_math.md`; `docs/Notes/File Explanation/lowdim_nonlinear_v1_file_explanation.md` |
| Duffing augmented SNR10 raw-coordinate release | 2026-07-10 | Controlled forced nonlinear dynamics | success | 768 trajectories; Split-I `512/128/128`; 2,000 snapshots at 500 Hz; clean and 10 dB noisy physical-state inputs; shared sparse multisine forcing; no standardization | Formal generation and reload passed; clean/noisy state shapes `[768,2000,2]`; train SNR `9.99336/9.99278 dB`; phase and forcing checks passed | Controlled-system source for KDSM-MP and clean/noisy-input supervised learning. Apply downstream preprocessing outside the data object | `docs/Notes/mathematical explanation/duffing_aug_snr10.md`; `docs/Notes/File Explanation/duffing_aug_snr10_file_explanation.md` |
| High-dimensional nonlinear v2 release | 2026-07-10 | High-dimensional complete-state L96-40, KS64, and FHN64 dynamics | success | Fresh raw Float64 integration; 480 trajectories per system; Split-I `320/80/80`; L96 shape per trajectory `(2049,40)`, KS `(5121,64)`, FHN `(5121,128)`; no normalization | Formal generation and HDF5 readback passed; time errors `2.40e-16/1.23e-9/1.60e-14`; KS/FHN space errors `1.91e-8/1.38e-3`; positive L96/KS largest Lyapunov exponents | Common high-dimensional source for SPDL, KEDMD, KDSM, and MDKK work. Construct stride views and preprocessing only after split | `docs/Notes/mathematical explanation/highdim_nonlinear_v2_math.md`; `docs/Notes/File Explanation/highdim_nonlinear_v2_file_explanation.md` |

## Project Operations

| Timestamp | Operation | Scope | Status | Validation evidence | Outcome commit | Details |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-13T15:26+08:00 | Normalized active dataset codes | Renamed `standard_odes_v1` to `lowdim_nonlinear_v1` and `high_dimensional_nonlinear_dynamics_v2` to `highdim_nonlinear_v2`; retained `duffing_aug_snr10` | success | Low-dimensional and high-dimensional smoke entry points passed; high-dimensional unit test passed `27/27`; JLD2/HDF5 metadata readback passed | `cdd7d536cdd0f9f7940e6e55c4096ddc539f67cc` | `docs/Notes/File Explanation/active_dataset_code_renaming_20260713_file_explanation.md` |
