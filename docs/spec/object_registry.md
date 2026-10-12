# Project Object Registry

This registry was initialized during the TestSub2 wrap-up. Existing historical
ledger rows remain unchanged. The entries below cover the reusable objects created
or retired by this task; they are not an exhaustive migration of earlier releases.
Standard ODE v2 remains active through `data/standard_odes_active.json`.

## Dataset-2 Nonlinear Vibration Generator

- Updated: `2026-10-11T00:15-07:00`.
- Identity: `Dataset2NV` (serialization-compatible alias of `TestSub2NV`); type: reusable Julia mechanical dataset generator;
  version: `20261004` (canonical naming updated 2026-10-11); status: active, formally validated.
- Purpose: generate complete clean ODE/FE free-decay populations with independent
  qualification, Train-only normalization and protected learner access.
- Implementation: canonical API `src/data/dataset2_nv/Dataset2NV.jl`, backed by `src/data/testsub2_nv/TestSub2NV.jl`; `MechanicalModel`,
  `duffing_model`, `beam_model`, `shell_model`, `initial_conditions`,
  `solve_certified`, `train_normalizer`, and `load_learner_view`; GPU integration
  in `src/data/testsub2_nv/gpu_modal.jl` with complete, invertible modal coordinates.
- Configuration and entry: `configs/releases/testsub2_nv_20261004.json` and
  `experiments/data_generation/run_testsub2_nv.ps1`; isolated CPU/GPU dependency
  manifests under `configs/environments/testsub2_nv/` and
  `configs/environments/testsub2_nv_gpu/`.
- Producing task: `TestSub_2_nonlinear_vibration`, series `TestSub`, task `2`.
  Consumers: future system-identification/model-learning tasks; no learned model
  or consumer result is registered by this task.
- Validation: `test/unit/test_testsub2_nv.jl` (45/45) and
  `test/unit/test_testsub2_nv_gpu.jl` (46/46); frozen logs under the release's
  `audit_only/validation/`; published FE linear-matrix comparisons passed.
- Reuse boundary: no mass or modal truncation; no dynamic forcing; public reference
  caches are required to repeat reference-matrix comparisons. Exact producing
  implementations are preserved by the release source bindings.
- Details: `docs/Notes/File Explanation/testsub2_nv_20261004_file_explanation.md`.

## Dataset-2 Clean CAN Release

- Updated: `2026-10-11T00:15-07:00`.
- Protocol identity: `Dataset-2`; frozen artifact identity: `testsub2_nv_20261004`; type: frozen dataset artifact;
  status: `dataset-qualified`.
- Artifact: `data/releases/testsub2_nv_20261004/TestSub2/release_manifest.json`;
  canonical active pointer: `data/dataset2_active.json`; legacy pointer remains valid.
- Population: Duffing8/BASE, Beam/FE12, Shell/NR, Shell/IR12, and Plate/FE200;
  62 CAN trajectories plus 12 independent QUAL trajectories; each has 4097
  Float64 full-state snapshots over 32 reference periods.
- Producing task and dependencies: `TestSub_2_nonlinear_vibration`; `TestSub2NV`;
  CPU source binding `add4a54bd864922b9c3c7cc3374ffe9ca6611d74bed638e54061fc1244938ba8`
  and GPU source binding `2324b2de66bd648313c920d13da3b1b8a8b6ccf6addab61ad67fe290ec5c8a98`.
- Validation: `experiments/data_generation/verify_testsub2_nv_dataset.jl`;
  all populations passed complete readback and refinement/energy gates;
  423 artifact hashes and the exact release file set passed wrap-up verification.
- Integrity: root manifest SHA-256
  `9069e4f8c0d215a879cd2eb66a3b910b279f5750dd41c08d2fcab675ab9d1756`.
- Report: `reports/TestSub_2_nonlinear_vibration/TestSub_2_nonlinear_vibration.md`;
  appendix: `reports/TestSub_2_nonlinear_vibration/2_numerical_appendix.md`;
  evidence: `reports/TestSub_2_nonlinear_vibration/TestSub_2_nonlinear_vibration_evidence.json`.
- Limits: CAN, not strict REPLAY; fixed FE mesh, no continuum mesh-convergence
  claim. Noise views are disabled. MEMS-GYRO and TRC-JOINT are removed from the current Dataset-2 scope as of 2026-10-11; they were never qualified objects in this release.

## Retired Structural Spectral v3

- Updated: `2026-10-04T07:07-07:00`.
- Identity: `structural_spectral_v3_20260921_r2`; type: retired dataset and
  archived implementation; status: retired, numerical data deleted.
- Archival implementation: branch `codex/abolish-structural-spectral-v3-20261004`,
  commit `5c6d43b5387ef62c293ea7246b475dddf2dd1e94`, paths
  `src/data/structural_spectral_v3/`, `experiments/data_generation/`, and the
  associated archived configurations and release metadata.
- Retiring task: `TestSub_2_nonlinear_vibration`; no current learner dependency
  remains on the removed release or active pointer.
- Evidence: `runs/testsub2_nv/retirement/{archive,inventory,result}.json` and the
  retirement inventory preserved in the archive commit. Deleted numerical and
  run files totaled 60,701,383,344 bytes. The archive preserves code and evidence,
  not the removed numerical dataset.
- Historical identity remains distinct from the new TestSub2 CAN release.

The report evidence separately records the time of its read-only integrity audit.

## SKDM9 Beam H512 truth extension

- Updated: 2026-10-05T02:07-07:00.
- Identity/type/status: skdm9_beam_h512_v1; version1, completed reusable TestSub2NV extension; consumes fixed published CPU capsule add4a54bd864922b9c3c7cc3374ffe9ca6611d74bed638e54061fc1244938ba8.
- Purpose: independent long full-state Beam truth for SKDM9 window learning;96/24/24 disjoint static-release amplitudes,32 periods at256 intervals per period. No claim of broad initial-velocity or phase coverage.
- Implementation: src/data/skdm9_beam_extension.jl (configuration, initial_conditions, generate); experiments/data_generation/generate_skdm9_beam.jl and skdm9_beam_campaign.py; experiments/smoke_tests/skdm9_beam_extension.jl. Frozen generation configuration lives with the produced extension.
- Artifact/dependencies: data/extensions/skdm9_beam_h512_v1; original active release remains unchanged.
- Authoritative learner manifest SHA: bc5a9b8cc971da3b3459412d02b0a6f83150231c4fdbc7fdf447613327bcf46e.
- Validation/report: reports/skdm_9_TestSub2NV_beam_extension/evidence.json; docs/Notes/File Explanation/skdm9_beam_extension.md; task-level report and9_numerical_appendix.md in ../InvSub/202609/reports/skdm/skdm_9_ssmlearn_beam_metric_comparison/. Producer completion is separate from model Test evaluation.

## skdm96-beam-transient-extension

- Type/version/status: Full66-stateBeam truthgenerator and qualified144-motherextension,v1complete.
- Implementation: src/data/skdm96_beam_extension.jl; experiments/data_generation/generate_skdm96_beam.jl/skdm96_beam_campaign.py; consumes existingTestSub2NV/Beam kernel.
- Producer/consumer: SKDM9.6; output data/extensions/skdm96_beam_transient_h2048_v1,manifest9642b59859887e0348d57ecaf7d264330ed0f24c3063d35e4675f06341475e1c.
- Qualification: maximumscaledstateerror1.0812213617120557e-10 andenergyerror6.589052342545405e-12; complete144trajectories and independentconsumer verification.
- Docs: docs/Notes/File Explanation/skdm96_beam_extension.md and sharedconsumer9.6report/appendix. Updated2026-10-10T18:05-07:00.

## Canonical Dataset Catalog (2026-10-11)

- Updated: 2026-10-11T00:15-07:00.
- Identity/type: `Dataset`; current protocol catalog, schema `dataset.catalog.v1`.
- Implementation: `configs/dataset_catalog.json`; inventory and read-only integrity
  audit: `experiments/data_generation/audit_dataset_catalog.py`.
- Dataset-1: `standard_odes_v2_20260916`, canonical pointer
  `data/dataset1_active.json`, API `src/data/dataset1/Dataset1.jl`.
- Dataset-2: `testsub2_nv_20261004`, canonical pointer
  `data/dataset2_active.json`, API `src/data/dataset2_nv/Dataset2NV.jl`.
- Dataset-2 extensions: `Dataset-2/SKDM9-Beam-H512` and
  `Dataset-2/SKDM9.6-Beam-Transient-H2048`, preserving their existing SKDM task IDs,
  artifact directories, frozen parent capsules and learner-manifest checksums.
- Source registration: Dataset-3 and Dataset-3.1 are note-only; no corresponding
  local release was found. HV is removed from the current Dataset-2 scope.
- Existing historical task identities, source bindings and retirement entries
  remain identifiable. Protocol renaming does not recertify or rewrite their data.
- Validation pointers: `test/unit/test_dataset_protocol_names.jl`;
  `experiments/data_generation/verify_dataset1.jl` and `verify_dataset2.jl`;
  audit receipts under `runs/dataset_naming_20261011/`.
- Navigation: `docs/Notes/dataset_inventory.md`.

## Dataset-2.1 NACA-NLC6 full-state generator

- Updated: 2026-10-11T22:27-07:00. Identity: Dataset-2.1/FE-NACA-NLC6; implementation v1, population in progress, independent qualification waived by user.
- Capability: 29,844-state nonlinear wing with six cubic spring/smooth velocity-damper patch ports; 4096 frames, 0.5 ms interval, 96/24/24 clean split. No reduced physical dynamics.
- Source: src/data/dataset21_nlc6/Dataset21NLC6.jl and campaign.jl; depends on src/data/dataset21_naca/. Entry and config: experiments/data_generation/run_dataset21_nlc6_campaign.jl and configs/releases/dataset21_nlc6_v1.json.
- Dependencies: pinned upstream source/NOTICE and isolated configs/environments/dataset21_naca; local base model artifacts/dataset21_nlc6/base_model.jld2. All initial-condition recipes, seeds, ratio tiers and allocation are frozen in the release input capsule.
- Output: data/releases/dataset21_nlc6_f4096_144_v1; completed single trial remains runs/dataset21_nlc6_trial_01, separate from the population. No current dataset-completion or independent-qualification claim.
- Numerical methods: FP64 GPU shell forces, CPU sparse Radau solves, analytic rank-18 connector stage tangent, and nonlinear constrained static release initialization. Runtime convergence, energy, strain, state-finiteness, saved-port identity and hash/readback checks remain enabled.
- Evidence/navigation: docs/notes/code explanation/dataset21_nlc6_population.md; prior trial completion.json and analysis.json; current campaign_status.json and completed.json as available. No final report until the population is complete.
- Retired lineage: old dataset21_naca_zeta006 trajectory and qualification HDF5 data deleted by request; preserved shared code remains active. Historical source capsules and exact-byte ZIP: codex/abolish-naca-pre-nlc6-20261012, 9d72cce0134ce8b57fb72f043d0ecc9a50ba163c. Retirement receipt: docs/notes/evidence/dataset21_naca_retirement_20261012.json.
