# Dataset-2.1 NACA generation

Status (2026-10-11): execution is authorized and independent qualification is
running. No formal 144-trajectory population is accepted yet. Smoke was explicitly
waived by the user; focused numerical checks and scientific qualification remain
mandatory. Inspect `runs/naca_campaign_control/state.json` and `supervisor.json`
before starting any process; an active supervisor already advances successful
qualification to generation and readback.

## Mathematical and resource contract

The source is the supplied
[Dataset-2.1 note](../../Notes/mathematical%20explanation/Dataset-2.1-Wing%20and%20Blade%20Structural%20Dynamics.md).
Conversation overrides for NACA are 0.006 damping in the first two modes, 4096
frames including the initial state, and a hard maximum of 30,000 physical states.
The output interval candidate is 0.0008 s, giving 4095 intervals and 3.276 s.
Effective-band qualification remains required. The COMSOL object is outside this
Julia generation scope.

The current [v2 configuration](../../../configs/releases/dataset21_naca_v2.json)
has 14,922 independent displacements and 29,844 complete q/v states, with 6,596
triangular shell elements. All 25 physical ribs, geometric groups, root constraints,
materials and six nodal mechanical components are retained. Its spanwise layer
counts are 3 in the first 23 rib intervals and 2 in the last; a1=a2=3. Reference
meshes have 50,688 and 133,920 mechanical DOFs. They are qualification resources,
not learning datasets.

Formal counts are 96 Train / 24 Validation / 24 Test, all with zero initial velocity,
zero continuing external force, no gravity/rotation and no added noise. Float64
physical q/v is stored as state component by time. The strain screen 0.001 is a
conservative engineering bound, not a measured alloy yield limit.

## Source correspondence and numerical repair

The upstream commit is `de6cbc71427d23827feb9efd313cb63a1fc52ff8`. Eleven pinned
files are recorded in [naca_sources.json](../../../configs/references/naca_sources.json).

| Source operation | Julia implementation | Preserved contract |
| --- | --- | --- |
| WING.geo / AIRFOIL.geo | mesh.jl | L=5, n=25, topology and groups; only mesh subdivision changes; source SF remains unused |
| read_msh / root BC | mesh.jl | ASCII MSH 2, deduplication, connectivity, all six clamped root components |
| TriShellElement | allman.jl | Source Allman membrane/bending/stabilization, mass and reference rotations |
| Assembly | mechanics.jl | Sparse full M/K/C; low modes only for initialization, damping and diagnostics |
| Internal force / tangent | mechanics.jl and gpu.jl | Source geometric nonlinear terms and consistent derivative |
| Time stepping | newmark.jl and radau.jl | Complete physical states; independently checked implicit integration |
| Qualification / release | response_diagnostics.jl, qualification.jl, campaign.jl | Independent QUAL, complete population, Train-only normalization and full readback |

Average-acceleration Newmark was implemented and tested, but its initial velocity
layer failed the required full-state refinement at practical trial steps. The
current solver is fifth-order L-stable Radau IIA, with extra internal refinement
during the first 0.0512 s. Its 3x3 complex transform acts only across time stages;
there is no POD, SSM or mechanical modal truncation. Nonlinear chord iteration
checks the exact mechanical residual and can rebuild the coupled consistent
stage tangent. No full dense mechanical basis or inverse global mass matrix is
formed. See the [qualification decision record](dataset21_naca_qualification_decisions.md)
for evidence, thresholds and the explicit limits of spatial agreement.

## CPU/GPU ownership

CPU owns geometry, sparse matrices, eigensolves, nonlinear control, sparse real
and complex solves, independent strain/energy diagnostics and HDF5 output. GPU
owns Float64 nonlinear element force/tangent evaluation. Host column views use a
dense reusable staging buffer; scalar GPU indexing remains disabled. Frames stream
to disk rather than accumulating the entire trajectory on the GPU.

Auto selection requires force/tangent parity and a warmed eight-step comparison,
including transfers and CPU solves. The v2 benchmark selected GPU; the measured
CPU/GPU times were 5.174/1.434 s, with trajectory relative difference 6.04e-12.
This short benchmark does not establish whole-campaign runtime or memory peaks.
The first complete QUAL case also compares CPU and GPU trajectories.

## Qualification and population

1. Freeze source/configuration hashes; assemble the candidate and two finer grids.
   Check original reference DOFs, frequencies, constraints and matrix properties.
2. Check frequency, MAC and static compliance at common physical points. Match
   reference initial shapes by physical modal coefficients or consistent static
   release, with explicit initial-shape checks.
3. Screen offered amplitudes .001/.003/.006 m across all 12 IC families. Run five
   independent cases: small/finite first mode, finite fourth mode, mixed first-four
   modes and static release. All undergo time, energy, strain and output-band checks.
4. The finite fourth-mode and mixed cases additionally run on both finer grids,
   including their linear references. Report raw same-clock differences and
   cumulative phase drift; separately test phase rate, q-v envelopes, energy decay
   and resolved nonlinear energy transfer. A coarse resource is not a claim of
   5% pointwise agreement with the fine model.
5. Freeze the qualified amplitude, internal steps and backend. Twelve families
   each contribute 8/2/2 trajectories. The three amplitude levels and predeclared
   jitter use deterministic independent seeds. No IC hash may repeat across
   population splits or QUAL.
6. Every formal trajectory must pass strain and energy checks, including final
   mechanical energy <=40% of its initial value. Recompute the normalizer using
   Train only, read back the entire population, and publish hashes and manifests.

Time refinement is performed on independent QUAL, not by double-integrating every
formal trajectory. Raw full-state temporal error remains limited to 1e-4. The
windowed spectrum and tail convention are explicit in the frozen configuration.

## Execution and monitoring

The isolated environment now contains Project.toml and Manifest.toml. Gmsh 4.14.1
is cached locally; MATLAB is not required. Pinned sources can be fetched/verified by
`prepare_dataset21_naca_sources.py`. Each Julia stage still requires `--execute`.
For a future manually controlled invocation, supply the intended frozen config:

```powershell
julia --startup-file=no --threads=1 --project=configs/environments/dataset21_naca experiments/data_generation/run_dataset21_naca.jl --execute --stage verify --config configs/releases/dataset21_naca_v2.json
```

The current campaign uses `run_dataset21_naca_stage.ps1` for durable process receipts,
`continue_dataset21_naca_campaign.py` for successful-stage transitions, and
`monitor_dataset21_naca.py` for sampled resources. The thread heartbeat diagnoses
failures and completes reporting, scoped Git publication and the authorized final
shutdown. Never start a duplicate worker or supervisor.

Model/QUAL output stays under `runs/<release_id>/`; formal HDF5 goes under
`data/releases/<release_id>/`. Source, mechanical model and IC evidence are in the
audit view. The active NACA pointer is written only after complete readback and
publication. Existing Dataset-1/2 releases are preserved. Failed receipts and
`.partial.h5` files remain for diagnosis; source/configuration changes require a
new release identity and explicit lineage.

## Evidence boundary

Fifty focused checks passed for the current implementation. An independent
full-duration Radau diagnostic passed, and the first v2 29,844-state time pair
passed with state error 1.29e-7 and energy balance 1.03e-8. Remaining qualification,
formal population, final verification, report and publication are pending. This
implementation guide is not a completed experimental report.
