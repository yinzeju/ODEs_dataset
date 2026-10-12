# Current authorized NACA-NLC6 campaign

The user approved the NLC6 model and authorized 144 trajectories (96/24/24).
Use configs/releases/dataset21_nlc6_v1.json and runs/naca_campaign_control/state.json.
The active release is dataset21_nlc6_f4096_144_v1. Its separate worker receipt and
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
