# Project Task List

This list contains only the four active dataset groups. Engineering cleanup is
recorded in `object_registry.md`.

Status values: `success`, `failed`, `blocked`.

## Active Dataset Releases

| Task | Execution time | Scope | Status | Configuration summary | Key result | Reuse note | Details |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Low-dimensional nonlinear v1 raw-coordinate release | 2026-07-10 | Low-dimensional autonomous nonlinear systems | success | Eight clean systems with 5 dB and 15 dB noisy observation variants; 512 trajectories per object except 8,192 pendulum trajectories; trajectory-level splits; raw physical coordinates; no standardization | All eight formal objects passed; 9,821,696 state vectors; 7,357,440 training one-step pairs per observation mode; approximately 475 MiB JLD2 data | Common source for compact forecasting, denoising, rollout, and operator-learning tasks. Fit downstream preprocessing on training data only | `docs/Notes/mathematical explanation/lowdim_nonlinear_v1_math.md`; `docs/Notes/File Explanation/lowdim_nonlinear_v1_file_explanation.md` |
| Duffing augmented SNR10 raw-coordinate release | 2026-07-10 | Controlled forced nonlinear dynamics | success | 768 trajectories; Split-I `512/128/128`; 2,000 snapshots at 500 Hz; clean and 10 dB noisy physical-state inputs; shared sparse multisine forcing; no standardization | Formal generation and reload passed; clean/noisy state shapes `[768,2000,2]`; train SNR `9.99336/9.99278 dB`; phase and forcing checks passed | Controlled-system source for KDSM-MP and clean/noisy-input supervised learning. Apply downstream preprocessing outside the data object | `docs/Notes/mathematical explanation/duffing_aug_snr10.md`; `docs/Notes/File Explanation/duffing_aug_snr10_file_explanation.md` |
| High-dimensional nonlinear v2 release | 2026-07-10 | High-dimensional complete-state L96-40, KS64, and FHN64 dynamics | success | Fresh raw Float64 integration; 480 trajectories per system; Split-I `320/80/80`; L96 shape per trajectory `(2049,40)`, KS `(5121,64)`, FHN `(5121,128)`; no normalization | Formal generation and HDF5 readback passed; time errors `2.40e-16/1.23e-9/1.60e-14`; KS/FHN space errors `1.91e-8/1.38e-3`; positive L96/KS largest Lyapunov exponents | Common high-dimensional source for SPDL, KEDMD, KDSM, and MDKK work. Construct stride views and preprocessing only after split | `docs/Notes/mathematical explanation/highdim_nonlinear_v2_math.md`; `docs/Notes/File Explanation/highdim_nonlinear_v2_file_explanation.md` |
| Controlled low-dimensional v1 release | 2026-07-27 | Five controlled low-dimensional bases with AUG, ADD, and BIL learner semantics | success | Fifteen clean objects; DUF-HF v3 uses 768 trajectories, Split-I `512/128/128`, 2,000 snapshots at 500 Hz, a weighted 5--80 Hz phase-locked source, matched AUG/ADD physical trajectories, and pure BIL stiffness modulation with $\rho_k=12$ | All release objects passed; DUF-HF BIL continuous-window passing fraction `0.9765625`, median minimum-window ratio `0.570557`, and state maximum `1.02295`; the trajectory report contains 30 figures | Controlled benchmark for autonomous augmentation, additive controlled learning, and future bilinear Koopman models; compare roles separately | `docs/notes/mathematical explanation/controlled_lowdim_v1.md`; `docs/notes/file explanation/controlled_lowdim_v1_duffing_hf_v3_file_explanation.md`; `reports/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization.md` |

## Project Operations

| Timestamp | Operation | Scope | Status | Validation evidence | Outcome commit | Details |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-13T15:26+08:00 | Normalized active dataset codes | Renamed `standard_odes_v1` to `lowdim_nonlinear_v1` and `high_dimensional_nonlinear_dynamics_v2` to `highdim_nonlinear_v2`; retained `duffing_aug_snr10` | success | Low-dimensional and high-dimensional smoke entry points passed; high-dimensional unit test passed `27/27`; JLD2/HDF5 metadata readback passed | `cdd7d536cdd0f9f7940e6e55c4096ddc539f67cc` | `docs/Notes/File Explanation/active_dataset_code_renaming_20260713_file_explanation.md` |
| 2026-07-27T19:01+08:00 | Completed controlled low-dimensional v1 and synchronized DUF-HF v3 mathematics | Added the fifteen-object generation and visualization workflow; regenerated DUF-HF AUG/ADD/BIL data; introduced weighted 9/17.5 Hz excitation, pure BIL stiffness modulation, and continuous-window persistence gates; removed superseded smoke data and the v2 pilot | success | DUF-HF candidate pilot passed with minimum accepted $\rho_k=12$; visualization produced 30/30 figures; formal release manifest and all DUF-HF v3 metadata passed; AUG--ADD maximum physical-state difference `0.0`; documentation/configuration/metadata consistency passed | This completion commit | `docs/notes/file explanation/controlled_lowdim_v1_duffing_hf_v3_file_explanation.md`; `reports/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization.md` |
| 2026-09-16T01:28+10:00 | Generate and qualify Standard ODE v2; retire low-dimensional v1 | 11 CAN configurations and six COND families with independent Split-I/Split-C; 23 resources, 119 condition shards | success | Smoke tests 370/370; 195 independent probes; 34,432 formal trajectories and 357 view files passed complete readback; maximum scaled state error 5.65115e-10 and energy residual 7.92622e-10; 357-view metadata audit passed; retired 498,534,110 bytes of v1 data | This completion commit | `docs/notes/file explanation/standard_odes_v2_file_explanation.md`; `reports/TestSub_1_standard_odes_v2/TestSub_1_standard_odes_v2.md`; `data/releases/standard_odes_v2_20260916/release_manifest.json` |

## Current Autonomous Release (2026-09-16)

`standard_odes_v2_20260916` supersedes the historical `lowdim_nonlinear_v1` release
listed above. It contains 34,432 trajectories, 63,559,296 state vectors, 357 clean/noisy
view files, and 10.04 GiB of JLD2 data. Read `data/standard_odes_active.json` for the
current manifest. Earlier rows are preserved as historical evidence. Controlled and
high-dimensional releases keep their existing independent protocols.

## Repository Cleanup (2026-09-16T12:32+10:00)

Historical entries above retain their original evidence. Their legacy file paths now refer to the archive branch's abolish/ directory; only Standard ODE v2 is active on main.

| Timestamp | Operation | Scope | Status | Validation evidence | Details |
| --- | --- | --- | --- | --- | --- |
| 2026-09-16T12:32+10:00 | Archive legacy resources and retain only Standard ODE v2 on main | Archive 234 legacy files and all 9 pending paths; delete 1,837 numerical/temporary files totaling 5,819,595,100 bytes; preserve the qualified release and frozen dependencies | success | Archive SHA-256 and Git blob checks passed; 370/370 focused tests; all 357 data view files passed full readback and metadata audit; one active release remains | Archive branch: archive/abolish-pre-standard-odes-v2-20260916; commit db6bc0a88a6d230fb1d4bf94b717658ee60f1566; docs/notes/file explanation/standard_odes_v2_cleanup.md; reports/TestSub_1_standard_odes_v2/cleanup/result.json |

## TestSub2 Nonlinear Vibration Completion (2026-10-04T07:07-07:00)

Historical entries above retain their original scope and evidence. The active
releases on `main` are now Standard ODE v2 and TestSub2 clean ODE/FE CAN.
Task series: `TestSub`; task code: `2`; identity: `TestSub_2_nonlinear_vibration`.
This is a release-definition task; it does not consume a separate registered
reuse-code object.

| Timestamp | Operation | Scope and principal objects | Status and outcome | Validation evidence | Outcome commit | Details |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-04T07:07-07:00 | Retire Structural Spectral v3 and generate, qualify and document TestSub2 nonlinear vibration data | `TestSub2NV`; `testsub2_nv_20261004`; retire `structural_spectral_v3_20260921_r2`; user authorized formal execution without smoke and disabled noise | success; 62 CAN plus 12 independent QUAL trajectories across five configurations, 4097 Float64 full-state snapshots each; 2,952,115,920 release bytes; HV external COMSOL pending | CPU 45/45 and GPU 46/46 focused checks; all five configurations passed full readback; maximum state error 8.476424e-10 and energy error 2.049008e-10; immutable verification and wrap-up SHA/file-set audit passed for 423 cataloged files; no package-wide tests | This completion commit | `docs/Notes/File Explanation/testsub2_nv_20261004_file_explanation.md`; `docs/spec/object_registry.md`; `reports/TestSub_2_nonlinear_vibration/TestSub_2_nonlinear_vibration.md`; `reports/TestSub_2_nonlinear_vibration/2_numerical_appendix.md`; `reports/TestSub_2_nonlinear_vibration/TestSub_2_nonlinear_vibration_evidence.json`; `data/testsub2_nv_active.json` |

The retired implementation and pending changes are preserved on
`codex/abolish-structural-spectral-v3-20261004` at
`5c6d43b5387ef62c293ea7246b475dddf2dd1e94`. Explicitly requested cleanup removed
60,701,383,344 bytes of old data and run outputs; Standard ODE v2 was preserved.
No remote push is part of this wrap-up.
