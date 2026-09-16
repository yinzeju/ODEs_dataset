# Standard ODE v2 Generation and Qualification

## Task Summary

Implemented the user-supplied TestSub-1 protocol dated 2026-09-15 as
`Standard_ODEs_v2`. The concrete project is `D:/MyVault/Projects/Julia/ODEs_dataset`.
The qualified release replaces the eight-object low-dimensional v1 data and adds
the six independent physical-parameter families. Other dataset generators and
pre-existing uncommitted changes were preserved.

## Entry Points

Run from the project root:

```powershell
julia --threads=12 --project=. experiments/smoke_tests/run_standard_odes_v2_smoke.jl
julia --threads=12 --project=. experiments/data_generation/generate_standard_odes_v2_dataset.jl
julia --project=. experiments/data_generation/verify_standard_odes_v2_dataset.jl
julia --project=. experiments/data_generation/audit_standard_odes_v2_metadata.jl
```

The verifier optionally accepts another release directory as its first argument.
The smoke command runs the focused mathematical tests and the complete small-data
generation/qualification/write/readback pipeline. Formal generation was explicitly
authorized by the user after smoke, and has been executed successfully.

## Core Source, Configuration, and Documentation

- `src/data/standard_odes_v2/StandardODEsV2.jl`: isolated module and dependencies.
- `models.jl`: all vector fields, physical energies, signed energy rates, initial-state laws, and modal basis.
- `solvers.jl`: initial-state analytic propagation, augmented DP5 integration, Yoshida4, independent numerical probes, and trajectory diagnostics.
- `generation.jl`: CAN/COND resource compiler, seed namespaces, splits, noise calibration, JLD2/JSON persistence, and release verifier.
- `configs/releases/standard_odes_v2.json`: populations, physical coefficients, exact condition-grid coordinates, time grids, and qualification thresholds.
- `test/unit/test_standard_odes_v2.jl`: 370 assertions covering physics, exact linear propagation, symplectic reversibility, sampling, split populations, and tensor layout.
- `docs/notes/mathematical explanation/standard_odes_v2_math.md`: exact snapshot of the supplied protocol.

`OrdinaryDiffEqLowOrderRK` 2.2.0 was added with `Pkg.PRESERVE_ALL`; other package
versions were retained. This repository is operated through scripts. The existing
root package entry-file warning during automatic Pkg precompilation did not prevent
the dependency installation or the successful script runs.

## Generated Data and Evidence

The formal root is `data/releases/standard_odes_v2_20260916/`:

- `release_manifest.json`: 119 condition shards and every clean/noisy file checksum.
- `verification.json`: complete readback result and aggregate counts.
- `metadata_audit.json`: 42 required fields across 357 views, physical parameter/condition/split/noise contract agreement, and disjoint probe/data seed pools.
- `numerical_probes.json`: 195 independent probes across 65 distinct configurations/conditions.
- `fput_refinement_history.json`: accepted, globally shared FPUT substep count of 8.
- `frozen_config.json`, `Julia_Manifest.toml`, `protocol_note_snapshot.md`, and `generator_source/`: reproduction inputs.
- `<resource_id>/noise_reference.json`: frozen clean-Train powers and condition weights.
- `<resource_id>/<condition_id>/clean.jld2`: `state`, `time`, `metadata`, and per-trajectory `diagnostics`.
- Each condition folder also contains `noise_5db.jld2`, `noise_15db.jld2`, JSON metadata, and `qualification.json`.
- `retirement_record.json` and `retired_v1_release_manifest.json`: inventory and hashes of the deleted v1 data. Reclaimed 498,534,110 bytes from the three v1 data directories.

Formal log: `runs/standard_odes_v2_formal.log`. Successful smoke log:
`runs/standard_odes_v2_smoke.log`. The final smoke artifacts originally lived in
`runs/smoke_tests/standard_odes_v2/338a0f38ca77/` and were explicitly marked `smoke`.
The later 2026-09-16 cleanup removed these temporary tensors. Their certificate is
preserved at `reports/TestSub_1_standard_odes_v2/cleanup/smoke_verification_before_cleanup.json`.

Formal Chinese report:
`reports/TestSub_1_standard_odes_v2/TestSub_1_standard_odes_v2.md`.

## Data Flow and Reading

Config and note snapshot → independent qualification probes → fixed solver settings
→ trajectory-level initial conditions and splits → clean raw states → condition-balanced
Train powers → frozen noise views → hash and complete readback qualification.

```julia
using JLD2
condition_dir = joinpath("data", "releases", "standard_odes_v2_20260916",
    "duffing__COND__duffing_cond_beta__Split-C", "r0_8")
clean = load(joinpath(condition_dir, "clean.jld2"))
X = clean["state"]                 # trajectory × time × component
meta = clean["metadata"]
Z = load(joinpath(condition_dir, "noise_5db.jld2"), "observation")
Y = X                              # clean full-state target
train_indices = findall(==("train"), meta["split_roles"])
column_snapshots = permutedims(X[1, :, :])  # component × time
```

The complete physical parameter record is shared by all trajectories in a condition
shard; active condition values, IC seeds, split roles, initial states, trajectory IDs,
and parent IDs are saved with explicit bindings. Noise views reference the clean
file as their target instead of duplicating target arrays. The clean power reference
uses the published Float32 clean samples, with second moments accumulated in
Float64. This storage binding is recorded in every noise reference.

For a history of `qH` snapshots and maximum horizon `hmax`, each trajectory has
`max(0, M-qH-hmax+1)` legal windows. Never cross trajectories, conditions, or splits.
Physical labels, complete trajectories, future information, and qualification
diagnostics are offline resources, not hidden-parameter deployment inputs.

## Validation Results and Engineering Adjustments

- Focused mathematical/data tests: **370/370 passed**.
- Smoke: **23 resources, 119 shards, 2,752 trajectories, 357 view files**, all passed.
- Formal: **34,432 trajectories, 63,559,296 state vectors, 10,783,728,301 bytes**, all passed.
- Independent probe maximum scaled state error: **5.65115e-10**, threshold **1e-7**.
- Full-resource maximum normalized energy residual: **7.92622e-10**, threshold **1e-8**.
- All formal integrations, support checks, split checks, and file readbacks passed.
- The separate metadata audit passed all 357 views; 34,432 IC seeds and 195 probe seeds had zero overlap.
- Relative to the shared reference, 5 dB views measured **4.94443–5.06544 dB**;
  15 dB views measured **14.95538–15.03932 dB** across shard/components.

The first smoke noise audit used only two held-out trajectories, yielding 66 noise
samples per channel. A FPUT channel deviated by 2.75935 dB from nominal and exceeded
the 2.5 dB smoke gate. Smoke counts were increased to 16/8/8 for visible-condition
resources and 16 or 8 for whole-condition holdouts. This raises the smallest channel
sample count to 264; the rerun passed. The formal populations, random-noise law,
formal 0.15 dB noise gate, and numerical thresholds were not changed.

The user-authorized old numerical directories and three obsolete v1 source/entry
files were removed after full v2 qualification. Historical notes and reports remain
available in the archive branch after the later project cleanup, and source history
remains in Git. See `standard_odes_v2_cleanup.md` for the current checkout scope.
No package-wide `Pkg.test()` was run.
