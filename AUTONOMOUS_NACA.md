# Generation complete — final closeout only (2026-10-14T12:12-07:00)

All144 unique r4 trajectories passed runtime gates, worker complete readback and
the final external all-state/port/SHA integrity audit. The worker exited0 at
2026-10-14T19:00:25Z. Do not launch or restart any campaign. State.json is authoritative
for final report, publication, remote-parity and forced-shutdown receipts.
Chinese report: reports/Dataset21_NLC6_v1_nonlinear_wing/Dataset21_NLC6_v1_nonlinear_wing.md; appendix: reports/Dataset21_NLC6_v1_nonlinear_wing/NLC6_numerical_appendix.md; audit: reports/Dataset21_NLC6_v1_nonlinear_wing/evidence/campaign_integrity_04.json.
Qualification remains user_waived_independent_qualification. Preserve all data,
failure/paused partials, locks and source capsules. Finish scoped publication and
verify remote parity, then recheck unrelated active experiments before the explicitly
authorized shutdown.exe /s /f /t 60. Pause heartbeat only after successful scheduling.

# Historical authorized campaign instructions

# Authorized resumption — 2026-10-14

The human explicitly requested continuing the remaining simulations, revoking the
temporary pause. r4 is the active detached release; use current state.json paths.
All133 accepted r3 HDF5 hashes were reverified and hardlinked with lineage. The
worker repeats full readback before counting reuse. Only11 prescribed static
releases remain; the interrupted NLC6_test_023 restarts from its original initial
state. Preserve the original partial, stale r3 lock/receipts and pause evidence.
Physics, amplitudes, numerical settings and gates are unchanged. No new smoke or
independent qualification is authorized. Automation resumes with quiet healthy
checks and notifications only for milestones, failures, repairs or completion.
See docs/Notes/evidence/dataset21_nlc6_resumption_04.json and
docs/Notes/evidence/dataset21_nlc6_r4_launch.json. Do not duplicate a live worker.
Prior final shutdown authorization applies only after144 accepted, full closeout,
verified remote parity and absence of unrelated active experiments.

# Current authorized NACA-NLC6 campaign

The user approved the NLC6 model and authorized 144 trajectories (96/24/24).
Use active paths in runs/naca_campaign_control/state.json: configs/releases/dataset21_nlc6_v1_r4.json
and runs/dataset21_nlc6_f4096_144_v1_r4/worker_05.json.
The active release is dataset21_nlc6_f4096_144_v1_r4. Its separate worker receipt and
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

The r1 worker disappeared with no Julia exception, last log 2026-10-13T04:03:41Z, at planned ordinal77 NLC6_train_052 frame89. Its stale receipt/lock and partial file are preserved. The user explicitly requested detachment from Codex. r2 ran through a hidden Windows WMI-created PowerShell supervisor (attempt03), with an explicit absolute Julia executable and transcript. Verified process chain: Julia PID29068 -> PowerShell PID12916 -> WmiPrvSE PID7032; no Codex terminal ancestor. Always reverify PID plus creation time from current_receipt; these numeric IDs are historical launch evidence only.

Seventy-one accepted parent HDF5 hashes were verified and hardlinked immutably into r2 with lineage. The active Julia worker repeats complete readback before counting reuse. Parent files must never be overwritten. The r2 driver explicitly loads and hashes the frozen population override, validates the original144-member seed/recipe/split contract, and changes only five rejected family3 rows: displacement scale0.8, energy-ratio multiplier0.64. Eight no-integration contract checks passed. No new qualification simulation was run. r2 launch interlock has been cleared after implementation; state.json points to worker_03.json. Preserve the exited r2 worker; do not restart parent r2/r1/v1.

Subsequent failures may be repaired autonomously, including further recorded, versioned initial-amplitude reductions only for failed cases. Retain before/after evidence and all runtime gates; static releases must still satisfy their nonlinear equilibrium initialization. Do not count rejected cases, weaken quality limits, or shut down before all 144 accepted trajectories and closeout. The user's waiver of independent qualification remains in effect.

Derive planned ordinal from population_plan.json rather than completed+1 because quarantined cases create gaps.

## Historical queued r3 numerical repair

The live r2 worker quarantined NLC6_validation_018 at frame347 (0.173 s):
relative energy-balance defect 0.00010005571691552474 exceeded 0.0001,
while strain 0.00010419470991147046 remained below 0.001. Its closed partial
HDF5, failure state and original initial-condition receipt remain preserved;
the saved347-frame prefix is finite and its energy deficit was independently
read back. See docs/Notes/evidence/dataset21_nlc6_numerical_revision_03.json.
The exact numerical error contribution has not been isolated.

Keep the healthy r2 worker and its frozen inputs unchanged. Queued
configs/releases/dataset21_nlc6_v1_r3.json preserves the exact population and
initial states, including the existing five amplitude revisions. It requests
case_solver_overrides only for documented energy-failed cases listed in
state.json quarantined_case_ids and numerical_revision_records. Radau substeps2 to4, with
startup refinement32, output grid, Newton tolerance, physics and gates unchanged.
The current driver does not consume case_solver_overrides. Do not launch r3
until r2 exits, strict override handling is implemented and no-integration
contracts pass; its formal-launch interlock is intentionally false. Reuse
accepted immutable r2 files with lineage and complete readback. Preserve the
failed case's initial-state hash in its replacement and record actual before/after
results. No amplitude reduction was selected for this numerical energy failure.
Rejected cases never count accepted, and any missing replacement blocks shutdown.

The two added family10 cases failed energy balance at frames202 and149,
respectively; their strains remain admissible. Exact finite saved-prefix audits,
original hashes and the previous queued-r3 config are preserved in
runs/dataset21_nlc6_f4096_144_v1_r2/energy_gate_failure_02/ and
docs/Notes/evidence/dataset21_nlc6_numerical_revision_03_addendum_01.json.
The queued config's case_initial_state_sha256 binds every listed replacement.
Implement and check that binding together with the solver overrides before launch.

NLC6_validation_020 subsequently exceeded energy balance at frame194 (0.0965 s),
with defect0.00010036921724564053 and admissible strain0.00013143745174922907.
Its finite saved-prefix audit and prior queued config are preserved under
energy_gate_failure_03/ and
docs/Notes/evidence/dataset21_nlc6_numerical_revision_03_addendum_02.json.

NLC6_test_020 was subsequently quarantined at frame128 (0.0635 s), with energy
defect0.00010027987013917643 and admissible strain0.0004292851187867575.
Its finite-prefix audit and previous queued config are preserved under
energy_gate_failure_04/ and
docs/Notes/evidence/dataset21_nlc6_numerical_revision_03_addendum_03.json.
Use the state and queued config for the current complete repair list.

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

## Historical r3 recovery

r2 exited with a recorded Julia static-equilibrium initialization error at planned
ordinal133 NLC6_train_089 after127 accepted cases. Its worker, stdout/stderr,
supervisor transcript, failure receipt and frozen inputs are preserved in
static_initialization_failure_01/. The old algorithm was reproduced: the second
continuation stage approached the zero-displacement root and failed its required
energy ratio. r3 predicts the next nonzero state by sqrt(new_ratio/previous_ratio)
amplitude scaling, then solves the same nonlinear equilibrium and energy constraint.
All12 static initializations passed the original force/correction/ratio/strain gates.
See docs/Notes/evidence/dataset21_nlc6_static_revision_03.json.

The driver now strictly validates and consumes the five substeps4 overrides and
their exact initial-state SHA256 bindings, verifies actual solver receipts and
rejects unknown settings, missing bindings or weakening changes. All309 focused
no-integration contracts passed; all five original initial-state hashes matched.
The launch interlock is cleared. No independent qualification was added.

All127 accepted r2 HDF5 hashes were reverified and hardlinked into r3 with lineage.
Never overwrite them. The r3 worker repeats full reread before counting reuse.
Seventeen members remain to integrate: five energy repairs and twelve static
releases. Numerical settings, physics, amplitudes, output grid and quality gates
remain unchanged except the five explicit substeps2-to4 refinements and static
continuation predictor. Do not claim repaired dynamic accuracy before results.

r3 started through Windows WMI with a hidden native PowerShell supervisor and an
absolute Julia executable. Launch chain Julia48284 -> PowerShell35688 -> WmiPrvSE7032
is historical evidence; verify current receipt PID and creation time every check.
See docs/Notes/evidence/dataset21_nlc6_r3_launch.json and the current state paths.
Keep active source/config inputs frozen; preserve failures and use a new release
for any further repair. Keep the heartbeat active until144 accepted and closeout.

## Explicit forced-shutdown authorization — 2026-10-14

The human explicitly requested forced shutdown after the entire experiment is
finished. This selects Windows forced application closure, not an immediate or
fixed-time shutdown. After144 accepted trajectories, complete integrity/readback,
formal Chinese report/appendix, required records, scoped commit/push and verified
remote parity, and with unrelated experiments inactive, notify the user and execute
shutdown.exe /s /f /t 60. Ordinary idle applications may be force-closed. Do not
schedule shutdown while any required case or closeout item is missing. Preserve
the scheduling receipt and pause the heartbeat after successful scheduling.
See runs/naca_campaign_control/force_shutdown_authorization_20261014.json.
