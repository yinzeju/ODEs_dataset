# Current authorized NACA-NLC6 campaign

The user approved the NLC6 model and authorized 144 trajectories (96/24/24).
Use configs/releases/dataset21_nlc6_v1_r2.json and runs/naca_campaign_control/state.json.
The active release is dataset21_nlc6_f4096_144_v1_r2. Its separate worker receipt and
campaign_status.json record process identity and progress. Never duplicate a live
worker. Do not disturb unrelated processes. Resume only missing trajectories;
verify PID plus creation time and preserve failed partial files before repair.

New smoke, independent time/grid qualification and ablation runs are explicitly
waived. Keep all physical states (29844, cap 30000), 4096 frames, dt 0.0005 s,
clean-only data, accepted NLC6 damping/connector parameters and initial-condition
population. Per-trajectory Newton, energy, strain and complete readback checks
remain required. Never label this release independently or fully qualified.

Old NACA trajectory and qualification HDF5 outputs were explicitly deleted;
see runs/naca_retirement_20261012/deletion_receipt.json and the source archive
branch codex/abolish-naca-pre-nlc6-20261012. Do not regenerate them. Keep the
completed NLC6 trial as separate evidence, not one of the 144 formal cases.

After all 144 and readback, write the Chinese report and numerical appendix,
update project records, commit/push task changes and verify remote parity.
The earlier final-shutdown authorization resumes with this full campaign. Shut down only after all data, readback, reports and publication are complete, remote parity is verified, and unrelated experiments are inactive. Stay quiet for healthy unchanged progress;
report meaningful milestones, failures, repairs, or completion.

## Runtime strain failure and engineering repair

NLC6_train_022 (family 3, high tier) exceeded strain 0.001: observed 0.0011854098589346262. Original worker was stopped; preserve strain_stop_01.json and the original incomplete HDF5. The r1 driver preserves unchanged physics, initial conditions, seed population, integration settings and limits, but closes and quarantines a trajectory immediately at an energy/strain failure and continues other cases. Thirty-one accepted parent files are reused by immutable hardlink with source-lineage receipts. Do not write to or overwrite accepted reused HDF5. The rejected case is replayed only to capture a readable failure state under the new stop handler.

## Authorized amplitude revision and autonomous decisions

The user authorized reduced amplitude for failed cases and subsequently delegated future choices to the agent, requiring decision records. No amplitude question is pending. See runs/naca_campaign_control/amplitude_authorization.json and docs/Notes/evidence/dataset21_nlc6_amplitude_revision_02.json.

The r1 worker disappeared with no Julia exception, last log 2026-10-13T04:03:41Z, at planned ordinal77 NLC6_train_052 frame89. Its stale receipt/lock and partial file are preserved. The user explicitly requested detachment from Codex. r2 now runs through a hidden Windows WMI-created PowerShell supervisor (attempt03), with an explicit absolute Julia executable and transcript. Verified process chain: Julia PID29068 -> PowerShell PID12916 -> WmiPrvSE PID7032; no Codex terminal ancestor. Always reverify PID plus creation time from current_receipt; these numeric IDs are historical launch evidence only.

Seventy-one accepted parent HDF5 hashes were verified and hardlinked immutably into r2 with lineage. The active Julia worker repeats complete readback before counting reuse. Parent files must never be overwritten. The r2 driver explicitly loads and hashes the frozen population override, validates the original144-member seed/recipe/split contract, and changes only five rejected family3 rows: displacement scale0.8, energy-ratio multiplier0.64. Eight no-integration contract checks passed. No new qualification simulation was run. r2 launch interlock has been cleared after implementation; state.json points to worker_03.json. Continue this worker; do not restart parent r1/v1.

Subsequent failures may be repaired autonomously, including further recorded, versioned initial-amplitude reductions only for failed cases. Retain before/after evidence and all runtime gates; static releases must still satisfy their nonlinear equilibrium initialization. Do not count rejected cases, weaken quality limits, or shut down before all 144 accepted trajectories and closeout. The user's waiver of independent qualification remains in effect.

Derive planned ordinal from population_plan.json rather than completed+1 because quarantined cases create gaps.

## Organized visualization workspace

The current report root is reports/Dataset21_NLC6_v1_nonlinear_wing. Its single
summary is tables/index.html. Figures, current 10x/six-second animations, numeric
tables, source/hash evidence and historical renders are in plots/, animations/,
tables/, evidence/ and archive/. Maintained plotting entry points are now under
experiments/postprocessing/; use configs/visualizations/dataset21_nlc6_report.json
for the shared report identity. Old selected-preview, trial plots and repair
folders were removed only after verified relocation and identical-byte merging.
Do not recreate those old plotting folders. Simulation HDF5 files, reference data,
models, frozen campaign sources and worker files have not moved. The visualization
summary is illustrative and is not a campaign-completion claim. Write the final
Chinese report and numerical appendix in this report root after all data checks.
