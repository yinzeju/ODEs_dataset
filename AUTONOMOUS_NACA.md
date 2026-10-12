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

## Authorized amplitude revision and autonomous decisions

The user authorized reduced amplitude for failed cases and subsequently delegated future choices to the agent, requiring decision records. No amplitude question is pending. See runs/naca_campaign_control/amplitude_authorization.json and docs/Notes/evidence/dataset21_nlc6_amplitude_revision_02.json.

Keep the healthy r1 worker running to finish unchanged cases. Then transition to dataset21_nlc6_f4096_144_v1_r2, reusing accepted immutable files with lineage and complete readback. The frozen r2 population file changes only five failed family-3 high-tier rows: displacement scale 0.8, connector-energy-ratio multiplier 0.64. Preserve the failed parent files. The r2 config has a launch interlock: first implement explicit override-plan consumption in a versioned driver; the existing driver ignores this new field. Only then enable its formal launch flag. Do not launch a second worker while r1 is alive or edit its frozen inputs.

Subsequent failures may be repaired autonomously, including further recorded, versioned initial-amplitude reductions only for failed cases. Retain before/after evidence and all runtime gates; static releases must still satisfy their nonlinear equilibrium initialization. Do not count rejected cases, weaken quality limits, or shut down before all 144 accepted trajectories and closeout. The user's waiver of independent qualification remains in effect.

Derive planned ordinal from population_plan.json rather than completed+1 because quarantined cases create gaps.
