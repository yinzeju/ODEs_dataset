# Project Object Registry

This registry was initialized during the TestSub2 wrap-up. Existing historical
ledger rows remain unchanged. The entries below cover the reusable objects created
or retired by this task; they are not an exhaustive migration of earlier releases.
Standard ODE v2 remains active through `data/standard_odes_active.json`.

## TestSub2 Nonlinear Vibration Generator

- Updated: `2026-10-04T07:07-07:00`.
- Identity: `TestSub2NV`; type: reusable Julia mechanical dataset generator;
  version: `20261004`; status: active, formally validated.
- Purpose: generate complete clean ODE/FE free-decay populations with independent
  qualification, Train-only normalization and protected learner access.
- Implementation: `src/data/testsub2_nv/TestSub2NV.jl`; `MechanicalModel`,
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

## TestSub2 Clean CAN Release

- Updated: `2026-10-04T07:07-07:00`.
- Identity: `testsub2_nv_20261004`; type: frozen dataset artifact;
  status: `dataset-qualified`.
- Artifact: `data/releases/testsub2_nv_20261004/TestSub2/release_manifest.json`;
  active pointer: `data/testsub2_nv_active.json`.
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
  claim. Noise views are disabled. MEMS-GYRO and TRC-JOINT are external COMSOL
  work pending the user; they are not qualified objects in this release.

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
