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
- Evidence/navigation: docs/Notes/code explanation/dataset21_nlc6_population.md; prior trial completion.json and analysis.json; current campaign_status.json and completed.json as available. No final report until the population is complete.
- Retired lineage: old dataset21_naca_zeta006 trajectory and qualification HDF5 data deleted by request; preserved shared code remains active. Historical source capsules and exact-byte ZIP: codex/abolish-naca-pre-nlc6-20261012, 9d72cce0134ce8b57fb72f043d0ecc9a50ba163c. Retirement receipt: docs/Notes/evidence/dataset21_naca_retirement_20261012.json.

### NACA-NLC6 v1_r1 runtime-gate revision (2026-10-12T09:04-07:00)

- Same physical model, 144-member initial-condition plan and integration parameters as v1; independently qualified status remains waived. New early energy/strain rejection and closed failure snapshot replace the former end-only acceptance check. Per-case quarantine continues other cases without claiming 144 successes.
- Implementation: src/data/dataset21_nlc6/Dataset21NLC6.jl and campaign.jl; config configs/releases/dataset21_nlc6_v1_r1.json. Parent 31 accepted files are immutable hardlinks with per-file source-lineage records. No amplitude changes are authorized yet.
- Active output: data/releases/dataset21_nlc6_f4096_144_v1_r1; runtime evidence and quarantined-case list under matching runs/. Parent v1 remains evidence and must not restart. Final report remains pending completion and resolution of inadmissible initial conditions.

### NACA-NLC6 v1_r2 amplitude and supervision revision (2026-10-12T22:39-07:00)

- Current status: population generation in progress, independent qualification waived. Supersedes stopped v1/r1 execution; their source capsules and failed artifacts remain identifiable.
- Configuration: configs/releases/dataset21_nlc6_v1_r2.json and hashed dataset21_nlc6_v1_r2_population.json. Explicit override-plan consumption in src/data/dataset21_nlc6/campaign.jl enforces144 ordered recipes, fixed seeds/signs/split, and amplitude-only changes for declared IDs. Five failed modal cases use scale0.8; physical parameters and gates are unchanged.
- Runtime objects: launch_dataset21_nlc6_detached.ps1 creates a WMI-service child, supervise_dataset21_nlc6.ps1 records a transcript, and start_dataset21_nlc6_campaign.ps1 receives an absolute Julia executable. This keeps the Julia worker outside the Codex terminal process tree. State/receipt PID plus creation-time verification remains mandatory before restart.
- Evidence: 8/8 no-integration plan checks;71 parent hashes verified; full reused-file readback performed by active worker. docs/Notes/evidence/dataset21_nlc6_detached_restart_02.json; active data/releases/dataset21_nlc6_f4096_144_v1_r2. No full-population completion claim.

## Dataset-2.1 NLC6 visualization report workspace

- Updated: 2026-10-12T23:55-07:00. Identity: Dataset21_NLC6_v1_nonlinear_wing, presentation layout v1; curated local examples, full population still generating.
- Capability: offline overall summary at reports/Dataset21_NLC6_v1_nonlinear_wing/tables/index.html; four accepted population examples plus the separately labeled exploratory trial. Current GIFs use 10x displacement and six-second playback; full-history metrics remain unscaled.
- Implementation/configuration: experiments/postprocessing/dataset21_nlc6_report.py, plot_dataset21_nlc6_selected.py, analyze_dataset21_nlc6_one.py, render_dataset21_nlc6_preview.py and audit_dataset21_nlc6_report.py; configs/visualizations/dataset21_nlc6_report.json. The original NACA plotting/mesh reader remains alongside these entry points.
- Inputs/dependencies: existing accepted parent/current HDF5, exact generation/readback receipts, trial reference HDF5, preserved mesh and Python scientific libraries. No new simulation or independent qualification is implied.
- Artifacts: plots/, animations/, tables/, evidence/ and archive/ under the report root. 146 original file mappings and preserved source snapshots retain historical provenance; 26 identical copies were merged only after SHA256 equality. Local images, raw per-frame CSV and archives are not restored by a Git checkout alone.
- Validation: 100 offline links, four complete metric histories, five source hashes and five current GIFs passed; all 20 frozen campaign inputs unchanged. Report evidence/audit.json and relocation.json hold exact records; the task file explanation documents data flow and unavailable browser inspection.
- Related objects: consumes the NACA-NLC6 full-state generator and separate trial. Retired NACA figures are historical only. The formal Chinese campaign report/numerical appendix remain pending and will share this report root.

## Dataset-2.1 NACA-NLC6 accepted release v1_r4

- Updated: 2026-10-14T12:12-07:00. Stable object: `Dataset-2.1/FE-NACA-NLC6`; type: complete clean full-state dataset and reusable generator; version: v1_r4; status: `complete_user_waived_independent_qualification`. Supersedes the earlier in-progress v1/r1/r2 entries above; parent versions remain failure/source/accepted-file lineage.
- Producing task: `Dataset21_NLC6_v1_nonlinear_wing` (series Dataset21,task NLC6,release-definition v1). Purpose: fixed nonlinear structural free-decay data for future learning tasks; no trained learner is registered.
- Implementation/configuration: `src/data/dataset21_nlc6/Dataset21NLC6.jl`, `campaign.jl`,shared `src/data/dataset21_naca/`; `configs/releases/dataset21_nlc6_v1_r4.json`,hashed r2 population,isolated NACA environment. Fixed physical model,29,844 states,4096 frames,0.5ms,96/24/24.
- Engineering identity:5 recorded amplitude reductions;5 exact-IC numerical refinements; nonzero static continuation predictor with unchanged gates. WMI/native-hidden PowerShell launcher retains explicit executable,UTF8 parsing and exit receipts. Frozen source capsules preserve all producing implementations.
- Artifact/pointer: `data/releases/dataset21_nlc6_f4096_144_v1_r4/release_manifest.json`; `data/dataset21_active.json`; manifest SHA `614c4fc54c6c1cfdd92afc976d7621bfd47893acb3573653458f77d25afcc9a0`.133 reused hardlinks and11 new static releases;144 distinct initial states.
- Validation: `reports/Dataset21_NLC6_v1_nonlinear_wing/evidence/campaign_integrity_04.json`;144 complete state/port readbacks and HDF5 hashes;309 no-integration contracts,5 exact repair hashes and12 static initializations. Report/appendix: `reports/Dataset21_NLC6_v1_nonlinear_wing/Dataset21_NLC6_v1_nonlinear_wing.md` and `reports/Dataset21_NLC6_v1_nonlinear_wing/NLC6_numerical_appendix.md`; file explanation: `docs/Notes/File Explanation/dataset21_nlc6_v1_completion.md`.
- Reuse boundary: complete local binary data/model/mesh are required and not restored by Git alone. Fixed discretization; independent temporal/spatial/sampling qualification waived. Original NACA/QUAL numerical outputs remain retired and must not be regenerated. No global accuracy or arbitrary-initial-state/parameter coverage claim.

### Completed NLC6 report workspace and integrity auditor

- Updated: 2026-10-14T12:12-07:00; identity `Dataset21_NLC6_v1_nonlinear_wing`; status: formal report and complete population audit available,illustrative previews retained separately.
- Entry points: `experiments/postprocessing/audit_dataset21_nlc6_release.py`, `dataset21_nlc6_report.py`, `audit_dataset21_nlc6_report.py`; config `configs/visualizations/dataset21_nlc6_report.json`.
- Capability: read-only final full-population SHA/state/port/lineage audit plus evidence-bound dashboard. No numerical simulation or new qualification. `tables/index.html` remains the single summary; formal Chinese report and NLC6 appendix share the same root.
- Artifact/evidence: `reports/Dataset21_NLC6_v1_nonlinear_wing/evidence/campaign_integrity_04.json`, `campaign_completion_04.json`,fresh cloud Exp2 retrieval record,updated presentation audit and preserved relocation map. Existing images/GIFs/source receipts retain original hashes and local-only storage.


## Current structural resources v2 and local retirements

- Updated: `2026-10-16T02:32-07:00`. This entry supersedes the active-data claims of the earlier
  Dataset-1, original TestSub2 CAN and SKDM extension registrations above; their
  producing identities remain historical evidence.
- Stable objects: `Dataset-2/VK-BEAM-CC/BASE` and `Dataset-2/VK-BEAM-CC/TRANSIENT`;
  type: complete current clean full-state populations, v2 organization. Each has
  144 mothers, 96/24/24, 66 states. BASE keeps 8193 snapshots; TRANSIENT has 4096 exact
  prefix snapshots, with original 4097-frame source files retained as provenance.
- Implementation/entries: `src/data/dataset2_nv/Dataset2NV.jl` retains TestSub2NV
  serialization identity; `experiments/postprocessing/copy_dataset2_prefix.jl`;
  `experiments/data_generation/verify_dataset2.jl`. Configuration/catalog:
  `configs/releases/dataset2_structural_v2.json`, `configs/dataset_catalog.json`.
  Artifacts: `data/Dataset-2/`; pointer: `data/dataset2_active.json`.
- Dataset-2.1/FE-NACA-NLC6 retains its original completed v1_r4 scientific identity,
 144 trajectories, 29844 states and 4096 frames, now solely at `data/Dataset-2.1/`.
  All 144 have one NTFS link. Frozen sources/manifest/runtime gates and the independent
  qualification waiver remain unchanged. Old parent metadata and 13 failed/paused
  prefixes remain lineage; `data/dataset_relocations.json` records retired links.
- Retired locally: Dataset-1 numerical data and old TestSub2 small CAN/QUAL/model
  outputs, with active pointers removed. OSC-DUFFING8 is outside the current protocol.
  Shell NR/IR12 and plate FE200 remain registered physics; new 144-mother populations
  are planned, not generated. Formal generation is unauthorized.
- Producing task: `Dataset_2_v2_resource_reorganization`; consumers must use the new
  active pointers. External InvSub historical configs were inspected but not edited.
- Validation/evidence: prefix 6/6,naming 11/11; 288 Beam readbacks; 432 original SHA;
  NACA 144 complete state/port/initial/hash/runtime checks; 103 visualization links.
  `docs/Notes/evidence/dataset_reorganization_20261016.json`;
  `reports/Dataset_2_v2_resource_reorganization/`; file explanation:
  `docs/Notes/File Explanation/dataset_reorganization_20261016.md`.


## Current Dataset-2 / Dataset-2.1 data reports

- Updated: `2026-10-16T02:50-07:00`. Stable report groups: `Dataset-2` and `Dataset-2.1`;
  type: current data-report catalog and reusable read-only report validation.
  This navigation supersedes earlier active report-root paths while preserving
  historical producing identities, scientific reports and original evidence.
- Dataset-2: `reports/Dataset-2/Dataset_2_v2_nonlinear_beams.md` and
  `2_numerical_appendix.md`; covers BASE144/8193 snapshots and TRANSIENT144/4096
  snapshots with original numerical evidence and exact-prefix boundaries.
  Shell/plate populations remain planned, not generated.
- Dataset-2.1: `reports/Dataset-2.1/`; original NACA formal report/appendix,
  144-member integrity evidence and illustrative dashboard/media are preserved.
  Independent qualification remains user-waived.
- Implementation: `configs/report_catalog.json`, current dataset/report pointers,
  `experiments/postprocessing/audit_report_catalog.py`, `dataset21_nlc6_report.py`
  and `audit_dataset21_nlc6_report.py`; producing task `reports_organization_20261016`.
- Retired report packets: Dataset-1, original TestSub_2 and the resource-organization
  report now at `abolish/reports_20261016/`; 23 original files preserved by SHA.
  Historical SKDM9 Beam evidence remains part of the current Dataset-2 report.
- Validation: 168 byte-preserving moves, 39 active Markdown links,
  103 NACA offline links, five source hashes, three unchanged data-manifest bindings.
  `docs/Notes/evidence/reports_organization_20261016.json`; explanation:
  `docs/Notes/File Explanation/reports_organization_20261016.md`.
