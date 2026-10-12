# Current authorized NACA-NLC6 campaign

The user approved the NLC6 model and authorized 144 trajectories (96/24/24).
Use configs/releases/dataset21_nlc6_v1_r1.json and runs/naca_campaign_control/state.json.
The active release is dataset21_nlc6_f4096_144_v1_r1. Its separate worker receipt and
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

A user question about reducing only inadmissible initial amplitudes is pending. Until answered, do not change amplitudes or replace those population members. Quarantined cases are never counted complete, and shutdown remains forbidden while any of the 144 is missing or rejected. Read the active release path from state.json; do not restart the stopped v1 worker.

Reporting: quarantined cases create gaps. Derive the current planned ordinal from population_plan.json, not completed+1. The unapproved concrete proposal is amplitude_proposal.json (multiply initial displacement by 0.8 and connector-energy ratio by 0.64 for the five rejected family-3 high-tier cases). Do not apply until the user authorizes it.
