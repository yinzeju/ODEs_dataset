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
| Controlled low-dimensional v1 release | 2026-07-27 | Five controlled low-dimensional bases with AUG, ADD, and BIL learner semantics | success | Fifteen clean objects; DUF-HF v3 uses 768 trajectories, Split-I `512/128/128`, 2,000 snapshots at 500 Hz, a weighted 5--80 Hz phase-locked source, matched AUG/ADD physical trajectories, and pure BIL stiffness modulation with $\rho_k=12$ | All release objects passed; DUF-HF BIL continuous-window passing fraction `0.9765625`, median minimum-window ratio `0.570557`, and state maximum `1.02295`; the trajectory report contains 30 figures | Controlled benchmark for autonomous augmentation, additive controlled learning, and future bilinear Koopman models; compare roles separately | `docs/Notes/mathematical explanation/controlled_lowdim_v1.md`; `docs/Notes/File Explanation/controlled_lowdim_v1_duffing_hf_v3_file_explanation.md`; `reports/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization.md` |

## Project Operations

| Timestamp | Operation | Scope | Status | Validation evidence | Outcome commit | Details |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-13T15:26+08:00 | Normalized active dataset codes | Renamed `standard_odes_v1` to `lowdim_nonlinear_v1` and `high_dimensional_nonlinear_dynamics_v2` to `highdim_nonlinear_v2`; retained `duffing_aug_snr10` | success | Low-dimensional and high-dimensional smoke entry points passed; high-dimensional unit test passed `27/27`; JLD2/HDF5 metadata readback passed | `cdd7d536cdd0f9f7940e6e55c4096ddc539f67cc` | `docs/Notes/File Explanation/active_dataset_code_renaming_20260713_file_explanation.md` |
| 2026-07-27T19:01+08:00 | Completed controlled low-dimensional v1 and synchronized DUF-HF v3 mathematics | Added the fifteen-object generation and visualization workflow; regenerated DUF-HF AUG/ADD/BIL data; introduced weighted 9/17.5 Hz excitation, pure BIL stiffness modulation, and continuous-window persistence gates; removed superseded smoke data and the v2 pilot | success | DUF-HF candidate pilot passed with minimum accepted $\rho_k=12$; visualization produced 30/30 figures; formal release manifest and all DUF-HF v3 metadata passed; AUG--ADD maximum physical-state difference `0.0`; documentation/configuration/metadata consistency passed | This completion commit | `docs/Notes/File Explanation/controlled_lowdim_v1_duffing_hf_v3_file_explanation.md`; `reports/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization.md` |
| 2026-09-16T01:28+10:00 | Generate and qualify Standard ODE v2; retire low-dimensional v1 | 11 CAN configurations and six COND families with independent Split-I/Split-C; 23 resources, 119 condition shards | success | Smoke tests 370/370; 195 independent probes; 34,432 formal trajectories and 357 view files passed complete readback; maximum scaled state error 5.65115e-10 and energy residual 7.92622e-10; 357-view metadata audit passed; retired 498,534,110 bytes of v1 data | This completion commit | `docs/Notes/File Explanation/standard_odes_v2_file_explanation.md`; `reports/TestSub_1_standard_odes_v2/TestSub_1_standard_odes_v2.md`; `data/releases/standard_odes_v2_20260916/release_manifest.json` |

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
| 2026-09-16T12:32+10:00 | Archive legacy resources and retain only Standard ODE v2 on main | Archive 234 legacy files and all 9 pending paths; delete 1,837 numerical/temporary files totaling 5,819,595,100 bytes; preserve the qualified release and frozen dependencies | success | Archive SHA-256 and Git blob checks passed; 370/370 focused tests; all 357 data view files passed full readback and metadata audit; one active release remains | Archive branch: archive/abolish-pre-standard-odes-v2-20260916; commit db6bc0a88a6d230fb1d4bf94b717658ee60f1566; docs/Notes/File Explanation/standard_odes_v2_cleanup.md; reports/TestSub_1_standard_odes_v2/cleanup/result.json |

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

## 2026-10-05T02:07-07:00 — Complete SKDM9 independent Beam truth extension

- Scope/status: completed skdm9_beam_h512_v1, consuming TestSub2NV fixed CPU source capsule.96 Train/24 Validation/24 Test,66 states,8193 frames each; static-release amplitude grid only. Active releases unchanged.
- Validation: independent consumer verification of144 hashes, split disjointness and exit0; maximum refinement2.2150035506378005e-11 and energy2.1969606742827447e-12. Compact receipt: reports/skdm_9_TestSub2NV_beam_extension/evidence.json. No regeneration or Pkg.test in closeout.
- Documentation: docs/Notes/File Explanation/skdm9_beam_extension.md; shared formal Chinese report and numerical appendix at ../InvSub/202609/reports/skdm/skdm_9_ssmlearn_beam_metric_comparison/. Consumer original A and A1/A2 are complete within recorded scope; B, pure MLP SKDM and PyKoopman formal runs remain not executed.
- Delivery: one scoped local producer completion commit. Large data remain local; no push, heartbeat or shutdown.

## 2026-10-10T18:05-07:00 — Complete SKDM9.6 transient Beam extension

- Completed144mothers/66states/4097frames with96Train/24Val/24Test, damping0.75 and secondmodeinitialrelease0.25. Baseline/fine and energy/transient gates passed; no regeneration atcloseout.
- Sources: src/data/skdm96_beam_extension.jl and experiments/data_generation/generate_skdm96_beam.jl/skdm96_beam_campaign.py. Artifact data/extensions/skdm96_beam_transient_h2048_v1; all data remain local.
- Fileexplanation: docs/Notes/File Explanation/skdm96_beam_extension.md. SharedChinese report/appendix in ../InvSub/202609/reports/skdm/skdm_9dot6_k32_transient_h2048. Scopedcompletioncommit/push authorized; remoteSHA receipts retained by consumercloseout.

## 2026-10-11T00:15-07:00 — Unify Dataset protocol naming and remove the Dataset-2 HV scope

- Scope/status: completed active protocol naming as Dataset-1 and Dataset-2;
  retained the ODEs_dataset repository directory as explicitly confirmed by the user.
  Cataloged both published releases and the SKDM9/SKDM9.6 Beam extensions:
  2,461 files, 14,790,502,785 bytes. Dataset-3/3.1 are note-only in this repository.
- Changed objects: configs/dataset_catalog.json, current release protocol labels
  and note paths, canonical Dataset1/Dataset2NV API aliases, verification/launcher
  aliases, data/dataset1_active.json and data/dataset2_active.json. Frozen release
  IDs, snapshots, binary types, RNG namespaces and historical task/report identities
  retain their original spelling; legacy pointers and consumers remain compatible.
- Notebook: Dataset-2-Nonlinear Structural Dynamics now includes only MECH-ODE and
  MECH-FE. Removed HV objects, budgets, special sampling, software/contact contracts
  and references; updated three directly dependent scope statements or links.
  Sections 6–9 retain identical mechanical definitions.
- Validation: read-only catalog verification passed 1,068 indexed artifact hashes;
  canonical Dataset2 API/JLD2/access compatibility passed 11/11; Dataset-2 full
  readback passed for all five configurations; Dataset-1 complete readback passed
  all 357 views / 119 shards. Note validation passed 49 unique
  equation tags, surviving equation references, links and ODE/FE-only scope.
  Existing datasets were neither regenerated nor deleted.
- Navigation/evidence: docs/Notes/dataset_inventory.md; docs/spec/object_registry.md;
  experiments/data_generation/audit_dataset_catalog.py;
  runs/dataset_naming_20261011/integrity_audit.json, alias_checks.log and
  dataset2_readback.log. This is a naming/scope update, not an experimental wrap-up;
  no new formal report, completion commit or remote push was requested.

## 2026-10-11T22:27-07:00 — Launch NACA-NLC6 population and retire old NACA numerical outputs

- Scope/status: user authorized 144 clean trajectories (96/24/24) with the accepted NLC6 connectors and explicitly waived new smoke and independent numerical qualification. Generation is running; this is not population completion.
- Implementation: src/data/dataset21_nlc6/campaign.jl, run_dataset21_nlc6_campaign.jl, start_dataset21_nlc6_campaign.ps1 and configs/releases/dataset21_nlc6_v1.json. Shared original shell source, all earlier configs and diagnostics are preserved.
- Retirement completed: 22 old NACA trajectory/qualification HDF5 files, 19,422,102,598 bytes. Protected model/mesh and NLC6 trial hashes remained unchanged. Old source capsules, small receipts and exact-byte ZIP are retained on codex/abolish-naca-pre-nlc6-20261012, tip 9d72cce0134ce8b57fb72f043d0ecc9a50ba163c.
- Checks: syntax/load and frozen allocation checks occurred during launch; no new validation simulation was run. The worker is advancing the first formal trajectory with runtime physics/readback checks enabled. Prior single-trial evidence is separate and is not counted in the 144.
- Navigation: docs/Notes/code explanation/dataset21_nlc6_population.md; docs/Notes/evidence/dataset21_naca_retirement_20261012.json; runs/dataset21_nlc6_f4096_144_v1/. Current shutdown hold remains. Code/archive publication is requested; final population report remains pending generation.

- Completion policy clarification: the full-population resumption preserves the earlier user request for reporting, publication and final shutdown. Shutdown is blocked during generation and until all completion checks pass and unrelated experiments are inactive; the single-trial hold no longer prevents authorized full-campaign closeout.

## 2026-10-12T09:04-07:00 — Contain NLC6 runtime strain failure without relaxing physics gates

- Observed: v1 NLC6_train_022 initial strain 0.0006807823 passed, but dynamic maximum 0.0011854099 exceeded the unchanged 0.001 limit. The verified own worker was terminated; 31 completed cases remain accepted. Original truncated partial file and logs are preserved.
- Engineering repair: v1_r1 closes/rejects trajectories immediately on energy/strain gate violation, writes failure state, quarantines them, and continues other unchanged planned cases. Population equality across all144 plans was checked; physics, amplitude targets, RNG, time steps and thresholds are unchanged.
- Reuse: 31 immutable parent HDF5 hardlinks preserve original source lineage via reused_from.json; full readback occurs before reuse is counted in r1. Same failing initial condition is replayed for readable failure-state capture, not independent qualification. No smoke/time/grid qualification was added.
- Status: repair running; any amplitude change awaits the pending user decision. Quarantined/missing cases block full completion and shutdown. Evidence: docs/Notes/evidence/dataset21_nlc6_runtime_repair_01.json and runs/dataset21_nlc6_f4096_144_v1_r1/.

## 2026-10-12T22:39-07:00 — Resume NLC6 with authorized amplitudes and detached supervision

- Observed: r1 disappeared with no Julia exception, last log 2026-10-13T04:03:41Z at planned ordinal77/frame89. Cause is undetermined; the user's terminal-coupling hypothesis motivates independent process supervision. Parent partial files, stale receipt/lock and interruption_02.json remain evidence.
- Authorization/decision: user allowed reduced failed-case amplitudes and delegated subsequent choices with records. r2 explicitly loads/hashes its population plan, changes five failed family3 displacements by0.8 (ratios by0.64), and preserves all other recipes, physical parameters, solver settings and quality limits.
- Validation: 8/8 no-integration population contract checks passed. All71 accepted parent file hashes were reverified; immutable hardlinks retain lineage. The active Julia worker repeats full readback before counting reuse. No new smoke or independent qualification simulation ran.
- Runtime: native Windows WMI-created hidden PowerShell supervisor and explicit Julia executable remove the Codex terminal ancestor. Verified launch chain Julia29068 -> PowerShell12916 -> WmiPrvSE7032. Earlier unsuccessful launcher attempts are recorded. Generation and final reporting remain incomplete; shutdown is blocked.
- Navigation: configs/releases/dataset21_nlc6_v1_r2.json; docs/Notes/evidence/dataset21_nlc6_detached_restart_02.json; runs/dataset21_nlc6_f4096_144_v1_r2/. Four CPU-only trajectory previews are available separately in runs/dataset21_nlc6_selected_previews_20261012/ with source/output hashes and verified 6s GIFs.

## 2026-10-12T23:55-07:00 — Consolidate NLC6 visualizations into the report workspace

- Scope/outcome: completed presentation organization only; formal population generation remains active. Current report identity is Dataset21_NLC6_v1_nonlinear_wing, with the single summary at reports/Dataset21_NLC6_v1_nonlinear_wing/tables/index.html.
- Assets: 146 original files preserved as 120 unique assets; 26 identical copies merged, reclaiming 41,571,995 bytes. Current 10x/six-second GIFs, full-history figures and numeric tables are separate from superseded renders and the retired original NACA model. Full old-to-new SHA256 mapping is retained.
- Code/navigation: four plotting/analysis entry points moved to experiments/postprocessing/; shared report config, dashboard builder, migration and audit added. README, population guide, autonomous handoff, control state and heartbeat now point to the report. Simulation data and all 20 frozen campaign inputs remain unchanged; the verified detached worker was not interrupted.
- Validation: byte preservation, 100 offline links, 16,384 selected-history rows, five source trajectory hashes and five 150-frame/6000ms/10x GIFs passed. Python syntax and active CLI imports passed. Browser automation blocks file URLs; browser visual inspection/tab switching was unavailable.
- Evidence/navigation: reports/Dataset21_NLC6_v1_nonlinear_wing/evidence/relocation.json, audit.json and report_manifest.json; docs/Notes/File Explanation/dataset21_nlc6_visualization_organization.md. Large local media/archives remain outside Git. Final scientific report and numerical appendix are pending full campaign completion.

## 2026-10-14T12:12-07:00 — Complete NACA-NLC6 full population and final data audit

- Outcome:144 accepted unique full-state trajectories in `dataset21_nlc6_f4096_144_v1_r4`,96/24/24 and12x12 families;133 immutable parent files reread,11 new static releases,worker exit0. Final external audit passed all saved states/ports,exact initial hashes,all HDF5 SHA and20 frozen inputs.
- Engineering: five physical failures retain0.8 displacement/0.64 ratio; five numerical energy failures preserve exact original initial states with substeps2→4; static nonzero-branch prediction repairs the zero-root continuation without weakening force/correction/ratio/strain gates. All309 focused no-integration contracts and12 static initializations passed. Explicit user pause/resume and all original failure/partial/lock evidence remain preserved.
- Evidence limits: `user_waived_independent_qualification`; no new smoke,time/grid/sampling qualification,ablation or learner Test scoring. Worst final energy balance9.761689157330619e-5,strain0.0006969655975785179,terminal energy fraction0.2975764670814523;these are runtime acceptance diagnostics.
- Records/navigation: `reports/Dataset21_NLC6_v1_nonlinear_wing/Dataset21_NLC6_v1_nonlinear_wing.md`; `reports/Dataset21_NLC6_v1_nonlinear_wing/NLC6_numerical_appendix.md`; `reports/Dataset21_NLC6_v1_nonlinear_wing/evidence/campaign_integrity_04.json`; `docs/Notes/File Explanation/dataset21_nlc6_v1_completion.md`; `data/dataset21_active.json` and catalog. Scoped completion publication/remote parity and the separately authorized conditional forced shutdown are tracked in control receipts; no countdown precedes those checks.
- Focused closeout validation: `docs/Notes/evidence/dataset21_nlc6_closeout_validation_04.json`; 144 numeric rows, 14 report links, 16 Markdown tables and 20 unchanged numerical inputs passed. Presentation audit rechecked 103 offline links, five source hashes and unchanged GIF/relocation evidence; catalog metadata and Python compilation passed.
