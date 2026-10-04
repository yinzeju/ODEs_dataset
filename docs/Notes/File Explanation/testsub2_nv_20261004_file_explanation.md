# TestSub2 Nonlinear Vibration Release: File Explanation

Task identity: `TestSub_2_nonlinear_vibration` (series `TestSub`, task `2`).
Release: `testsub2_nv_20261004`. This task defines a reusable dataset release, so its
report identity does not add a consumer reuse-code field.

## Task Summary

Retire Structural Spectral v3, preserve its implementation and pending changes on
`codex/abolish-structural-spectral-v3-20261004` at
`5c6d43b5387ef62c293ea7246b475dddf2dd1e94`, and generate the complete TestSub2 ODE/FE
CAN population. The user explicitly authorized formal execution without a smoke
gate and disabled additional noise views. HV remains an external COMSOL task.
Standard ODE v2 and its active pointer were preserved.

## Run Entry Points And Scripts

| Path under `experiments/data_generation/` | Role |
| --- | --- |
| `run_testsub2_nv.ps1` | Dispatch model preparation, CPU/GPU generation and final verification. If already published, verify without regeneration. |
| `prepare_testsub2_nv_models.jl` | Assemble five full mechanical models, check energy gradients and tangents, and compare available published linear FE matrices. |
| `generate_testsub2_nv_dataset.jl` | Formal CPU generation, independent QUAL, atomic writes and frozen source bindings. |
| `generate_testsub2_nv_gpu.jl` | Formal shell/plate GPU generation with full modal coordinates and per-trajectory qualification. |
| `verify_testsub2_nv_dataset.jl` | Complete readback, split/normalizer checks, source snapshots, artifact checksums, publication and immutable re-verification. |
| `calibrate_testsub2_nv_gpu.jl` | Select the GPU tolerance profile on independent complete QUAL data. |
| `qualify_testsub2_nv_gpu.jl` | Fixed-step ETDRK4 comparison candidate; failed candidates are not released. |
| `qualify_testsub2_nv_gpu_physical.jl` | Physical-coordinate or modal-coordinate GPU comparison/qualification entry. |
| `benchmark_testsub2_nv_gpu_transforms.jl` | Correctness and timing of complete-basis transforms. |

## Core Source, Configurations And Documentation

`src/data/testsub2_nv/TestSub2NV.jl` is the core module. `models.jl` defines full
mechanical models, force/tangent/potential evaluation and static initialization;
`triangular_shell.jl` implements the reference Allman element. `integration.jl`
provides CPU integration and qualification diagnostics. `release.jl` owns stable
initial conditions, serialization, Train-only statistics and `load_learner_view`.

`gpu_modal.jl` is the production GPU solver. `gpu_exponential.jl` provides shared
CUDA full-state mechanical operations and the rejected ETDRK4 comparison method;
`gpu_batched.jl` supplies checked small-batch transforms. `gpu_physical.jl` retains
the direct physical-coordinate comparison implementation. Keeping a comparison
implementation does not imply that it generated the released states.

`configs/releases/testsub2_nv_20261004.json` declares the release, populations,
time grid, solver profiles and gates. The isolated CPU and GPU `Project.toml` and
`Manifest.toml` files are under `configs/environments/testsub2_nv/` and
`configs/environments/testsub2_nv_gpu/`. The root Julia environment is unchanged.

The task also updates `README.md`, initializes `docs/spec/object_registry.md`,
appends to `docs/spec/project_task_list.md`, and adds the main Chinese report,
`2_numerical_appendix.md`, and a compact JSON evidence record under
`reports/TestSub_2_nonlinear_vibration/`. The `.gitignore` change allows only these
task report files; numerical data, caches and run directories remain ignored.

## Generated Data, Artifacts, Reports And Logs

The published root is `data/releases/testsub2_nv_20261004/TestSub2/`. Each
object/configuration contains `can/clean/{train,val,test}/`, a separate
`can/train_normalizer.jld2`, learner manifests, numerical qualification
certificates, independent QUAL states, and evaluator-only `audit_only/` content.
Raw state arrays have shape `(2*n_q, 4097)` with rows `[q; v]` and columns time.

The root `release_manifest.json`, `manifests/artifact_manifest.json`, and
`data/testsub2_nv_active.json` define publication. All 423 catalog entries are
checksummed; including the catalog and root release manifest gives 425 files.
The total release size is 2,952,115,920 bytes, including 2,438,551,390 bytes of CAN
trajectory files. Directory sizes exclude dependencies, local caches, run logs,
this report folder, and the separate Standard ODE v2 release.

Frozen source/environment/note snapshots under `audit_only/source_snapshots/`
bind CPU trajectories to `add4a54bd864922b9c3c7cc3374ffe9ca6611d74bed638e54061fc1244938ba8`
and GPU trajectories to `2324b2de66bd648313c920d13da3b1b8a8b6ccf6addab61ad67fe290ec5c8a98`.
The released CPU states used UMFPACK. The current CPU source contains the later
KLU choice; exact lineage reconstruction must use the corresponding snapshot,
not silently replace the producing implementation with current source.

`data/cache/testsub2_references/` holds public reference-source caches and
converted `shell_nr_linear.h5`, `shell_ir12_linear.h5`, and `plate_linear.h5`.
These are needed to repeat the published-matrix comparison. `runs/testsub2_nv/models/`
contains local full-model caches needed by the current verifier. Neither cache is
versioned. Durable mechanical data and assembly evidence also reside in the release.

Frozen `audit_only/validation/` records include the solver adjustment history,
transform benchmark, focused test logs and final GPU generation log. Development
and readback logs remain under `runs/testsub2_nv/`; `retirement/` records the exact
old-data deletion scope. No failed candidate states enter the CAN learner view.

## Script-to-Script Data Flow

Model preparation creates local mechanical caches. Formal CPU/GPU generation
loads those models and the frozen configuration, constructs CAN/QUAL initial
states, runs base/fine solves, and writes only certified fine trajectories.
Normalization reads the complete Train population. Verification reads all
configurations, validates metadata and checksums, then publishes the root manifest
and active pointer. Later verification follows an immutable read-only branch.

The report evidence was extracted from that frozen release and its actual
certificates. GPU phase timings are shared batch timings and are counted once
per configuration; CPU phase timings sum individual CAN and QUAL integrations.

## Validation Commands And Results

Run from the concrete project root with the recorded Julia 1.12.5 environments:

```powershell
julia --project=configs/environments/testsub2_nv test/unit/test_testsub2_nv.jl
julia --project=configs/environments/testsub2_nv_gpu test/unit/test_testsub2_nv_gpu.jl
julia --project=configs/environments/testsub2_nv experiments/data_generation/verify_testsub2_nv_dataset.jl
```

Completed generation-stage evidence: CPU 45/45 and GPU 46/46 focused checks;
62 CAN and 12 independent QUAL trajectories passed state and energy gates;
all five configurations passed complete readback; immutable verification printed
`FROZEN_RELEASE_VERIFIED`. Numerical source files were not changed during wrap-up,
so these focused results were reused rather than rerunning experiments or `Pkg.test()`.

Wrap-up independently rehashed every catalog entry, checked the exact release file
set and active pointer, matched the live mathematical note to both source bindings,
and checked report numbers, links and staged scope. The report evidence file
records the audit timestamp and exact release hashes.

The release is CAN rather than strict paper REPLAY. Its qualification concerns
time integration of the fixed FE discretizations; no continuum mesh convergence
or downstream learning accuracy is claimed. CUDA atomics preclude a promise of
bitwise-identical regeneration.
