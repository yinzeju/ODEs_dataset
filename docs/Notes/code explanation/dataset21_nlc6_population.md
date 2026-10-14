# NACA-NLC6 accepted population

The accepted release is `dataset21_nlc6_f4096_144_v1_r4`:144 unique clean trajectories,
96 Train/24 Validation/24 Test,12 families with8/2/2 each. The worker exited0
after complete saved-state readback. A separate final audit rechecked every
HDF5 hash, all saved states and port identities, exact initial states, runtime
receipts, model/source bindings and133 immutable parent hardlinks.
The active pointer is `data/dataset21_active.json`. Never restart parent releases.

## Frozen model and data contract

- 14,922 displacement DOFs;29,844 physical states; no modal truncation or new connector states.
- Fixed clamped wingbox mesh, local lumped shell mass, six fixed-direction passive patch connectors.
- Cubic springs and smooth saturating velocity-dependent dampers; all physical parameters fixed.
- Rayleigh aM=0.5879008847043158/s,aK=1.6378470960752408e-6s; mode1/4 targets1%/0.12%.
- 4096 Float64 frames,dt0.0005s,T2.0475s;zero initial velocities and no continuing force, gravity,rotation or noise.
- HDF5 `x` is state/time in Julia and time/state in h5py; all q followed by all v.
- Auxiliary fields store energy, linear/connector dissipation, six port coordinates/velocities, connector potential and recovered strain.

## Initialization and engineering revisions

Four single-mode,six pair-mode,one four-mode mixture and one nonlinear static-release
family share the original144-member SHA-derived seed namespace20261012.
Nominal low/middle/high allocation is24/60/60 with ratios0.025/0.1/0.25 and frozen10% jitter.
The actual ratio is connector quartic potential/original quadratic strain energy.
Mode shapes initialize complete physical states only.

Five family3 physical-admissibility failures use displacement0.8 and ratio0.64
relative to their original recipes; their original nominal tier remains identifiable.
Five separate energy-failed cases preserve exactly their original initial-state SHA
and use internal Radau substeps4 rather than2. All other cases use2.
Startup refinement32 over0.05s,Newton1e-13,20 iterations,chord10 and bisections6 remain.
Static releases solve the full nonlinear force and energy-ratio constraint after
a sqrt(new_ratio/previous_actual_ratio) nonzero-branch predictor. No static
force/correction/ratio/strain gate was weakened.

## Runtime gates and final audit

Every accepted file passed Newton convergence,finite complete states,strain<=0.001,
relative energy balance<=1e-4,terminal energy fraction<=0.4,all-frame saved-port
identity,initial-state equality,time grid and file SHA256 checks. The generator's
`integrated_pending_readback` solver-receipt status describes the integration stage;
the matching passed readback receipt and final release manifest establish acceptance.

Independent time/grid/sampling qualification and new smoke/ablation experiments
were waived. Preserve `user_waived_independent_qualification`; runtime energy
acceptance is not a reference-solution full-state accuracy certificate.
Validation/Test labels describe future learning partitions, not independent qualification runs.

Read-only verification (choose a new output path):

```powershell
python -X utf8 experiments/postprocessing/audit_dataset21_nlc6_release.py --config configs/releases/dataset21_nlc6_v1_r4.json --worker-receipt runs/dataset21_nlc6_f4096_144_v1_r4/worker_05.json --output runs/naca_campaign_control/repeated_integrity_audit.json
```

## Provenance and storage

The final source/config/environment capsule is `runs/dataset21_nlc6_f4096_144_v1_r4/source_snapshot/`;
`input_fingerprint.json` binds20 inputs. Accepted parent HDF5 files are immutable
hardlinks with source-lineage receipts; r4 repeats their complete readback before
counting reuse. There are133 parent files and11 new static releases. Each final
trajectory directory retains initial-condition metadata,solver/progress/readback
receipts and `trajectory.h5`. The root manifest has144 ordered members.

Preserve r1 `interruption_02.json`,stale locks/receipts and partial file;
r2 energy/static failure capsules; r3 `pause_20261014.json`,exit130 and the original
interrupted NLC6_test_023 partial. r4 reran that case from its exact original initial
condition. All prior launch failures and native PowerShell quoting/UTF8/exit-handle
repairs remain recorded. Never overwrite accepted HDF5 or remove historical evidence.

The separate exploratory trial remains outside the formal144. Old NACA/QUAL HDF5
were deleted by user request; do not recreate them. Shared models/meshes and pinned
upstream source/license remain required local dependencies. Git publishes source,
configuration,small evidence and reports,not these large local data artifacts.

## Reports and visualizations

The formal Chinese report is `reports/Dataset21_NLC6_v1_nonlinear_wing/Dataset21_NLC6_v1_nonlinear_wing.md`; its sibling is `NLC6_numerical_appendix.md`.
Final audit: `reports/Dataset21_NLC6_v1_nonlinear_wing/evidence/campaign_integrity_04.json`. All adjustments,qualification limits and provenance are
included. The unique summary is `reports/Dataset21_NLC6_v1_nonlinear_wing/tables/index.html`; it connects the formal
result to four illustrative population examples and a separately labeled trial.
Animations remain10x/six seconds; numeric histories use all4096 frames.
Maintained postprocessing entry points live under `experiments/postprocessing/`.
Never recreate removed old plotting folders. Read control state for publication
and explicitly authorized conditional shutdown receipts.
