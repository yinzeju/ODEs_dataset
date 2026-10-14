# NACA-NLC6 complete-population implementation and files

## Task summary

Completed the authorized144-member full-state NLC6 population through versioned
repairs and explicit pause/resumption. r4 contains133 immutable reused files and11
new static releases. All144 passed unchanged runtime gates and final all-state/port
readback and SHA256 checks. Independent time/grid/sampling qualification remains
user-waived; no new smoke or qualification trajectories were added at closeout.

## Run entry points and scripts

- `experiments/data_generation/run_dataset21_nlc6_campaign.jl`: full-state population driver entry.
- `launch_dataset21_nlc6_detached.ps1`, `supervise_dataset21_nlc6.ps1`, `start_dataset21_nlc6_campaign.ps1` in the same directory: hidden WMI supervision, explicit Julia executable, UTF8 JSON and retained child handle/exit code.
- `check_dataset21_nlc6_revision.jl`: targeted initialization checks, without time integration.
- `experiments/postprocessing/audit_dataset21_nlc6_release.py`: read-only final144-file audit, explicit config/worker receipt/new output.
- `dataset21_nlc6_report.py` and `audit_dataset21_nlc6_report.py` in postprocessing: deterministic dashboard and presentation/source checks; no simulation.

Do not repeat historical launch attempts or restart parent releases. A future numerical
change requires a new version,decision record and preserved before/after evidence.

## Core source, configurations and documents

`src/data/dataset21_nlc6/campaign.jl` strictly validates per-case solver overrides
and exact initial-state SHA bindings, checks actual solver receipts, and predicts
the nonzero static equilibrium branch before the unchanged coupled solve.
The 5 energy-failed cases use substeps4; other139 use2. Existing5 physical strain
failures retain the previously authorized0.8 displacement/0.64 ratio change.
Configs r3/r4 preserve the explicit r2 population hash and original seed identity.
Never edit the20 frozen numerical inputs after acceptance.

The catalog and `data/dataset21_active.json` register the completed artifact with
its qualification boundary. Catalog audit maps NLC6 `relative_path` entries to
files without changing the existing Dataset1/2 contracts. README, population guide,
autonomous handoff and report guide now point to final data and reports.

## Generated data, artifacts, reports and logs

- `data/releases/dataset21_nlc6_f4096_144_v1_r4/`: final model,144 trajectories,initialization/runtime/readback/lineage receipts and root manifest.
- `runs/dataset21_nlc6_f4096_144_v1_r4/`: worker/supervisor transcripts,plan,completed list and20-input source capsule; worker05 exit0.
- `reports/Dataset21_NLC6_v1_nonlinear_wing/Dataset21_NLC6_v1_nonlinear_wing.md` and `reports/Dataset21_NLC6_v1_nonlinear_wing/NLC6_numerical_appendix.md`: paired Chinese formal report/full numeric record.
- `reports/Dataset21_NLC6_v1_nonlinear_wing/evidence/campaign_integrity_04.json`: final all-file integrity and complete runtime/initial-state metadata; manifest SHA `614c4fc54c6c1cfdd92afc976d7621bfd47893acb3573653458f77d25afcc9a0`.
- `docs/Notes/evidence/dataset21_nlc6_*revision_03*.json`,resumption/r4 launch and paused-case completion: decision/failure/replacement provenance.
- Original r1 unexplained interruption,r2 finite energy-failure prefixes/static exception and r3 paused partial remain in their original folders; no old data was regenerated or removed.

Large HDF5,model/mesh,raw full histories and archived media remain local/ignored.
Only source/configuration/compact evidence/reports are in the completion commit.

## Script data flow

Frozen config and explicit population plan -> NACA base model plus fixed NLC6
ports -> complete initial states -> GPU shell/CPU sparse Radau integration ->
runtime gates -> complete saved-state readback/SHA -> accepted release manifest.
Versioned reuse checks exact hashes and preserves hardlinks/source lineage before
the active driver repeats readback. The final Python audit reads that frozen
manifest,model and every saved frame; report generation consumes only its passed
evidence and retained revision records. Dashboard rebuilding uses existing saved
analysis; it does not rerender or alter data.

## Validation commands and results

The r3 focused no-integration checks passed309/309 (301 solver/hash bindings and8
population-plan checks). The initialization checker passed all5 exact modal hashes
and12 static equilibria with original gates. Their frozen results/sources remain
bound in `dataset21_nlc6_static_revision_03.json`; no repeat integration was run.

```powershell
python -X utf8 experiments/postprocessing/audit_dataset21_nlc6_release.py --config configs/releases/dataset21_nlc6_v1_r4.json --worker-receipt runs/dataset21_nlc6_f4096_144_v1_r4/worker_05.json --output reports/Dataset21_NLC6_v1_nonlinear_wing/evidence/campaign_integrity_04.json
```

The one-shot final audit passed144/144,including every complete saved-state matrix,
all-frame port identities,exact initial state,SHA,root/source/model bindings and133
parent hardlinks. To repeat,use a new output filename rather than overwriting evidence.
Source Python compilation,final catalog metadata,presentation/offline links and
report numerical/cross-link checks are recorded in the closeout validation receipt.
No Pkg.test(),new smoke,learning,QUAL or independent accuracy qualification ran.
