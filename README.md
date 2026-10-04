# ODEs_dataset

Julia generation and qualification of Standard ODE v2 and TestSub2 nonlinear vibration datasets.

## TestSub2 Nonlinear Vibration

The clean-only release is configured in `configs/releases/testsub2_nv_20261004.json`.
Its mathematical source is the user-supplied **TestSub-2-ODE-FE-HV Nonlinear Vibration Dataset**
note, frozen with each release. All states are complete Float64 mechanical states
in physical coordinates, stored as `state_component × time`, with all displacements
followed by all velocities. Each trajectory starts at release, has zero initial
velocity and zero dynamic forcing, and contains 4,097 snapshots over 32 reference
periods at an output interval of `P*/128`.

| Configuration | Displacement DOFs | Train | Validation | Test |
| --- | ---: | ---: | ---: | ---: |
| OSC-DUFFING8 / BASE | 8 | 12 | 4 | 4 |
| VK-BEAM-CC / FE12 | 33 | 3 | 1 | 2 |
| VK-SHELL-SHALLOW / NR | 1320 | 3 | 1 | 2 |
| VK-SHELL-SHALLOW / IR12 | 1320 | 9 | 3 | 3 |
| VK-PLATE-SQUARE / FE200 | 606 | 9 | 3 | 3 |

See the [compact data report](reports/TestSub_2_nonlinear_vibration/TestSub_2_nonlinear_vibration.md)
and its [numerical appendix](reports/TestSub_2_nonlinear_vibration/2_numerical_appendix.md)
for the completed release, storage breakdown, qualification results and solver adjustments.

```powershell
./experiments/data_generation/run_testsub2_nv.ps1
```

The wrapper assembles and validates the complete models, generates the formal
population, and performs complete readback before publishing
`data/testsub2_nv_active.json`. The dataset root is
`data/releases/testsub2_nv_20261004/TestSub2/`. A missing active pointer means that
the complete release has not yet passed its final verification. Individual model
generation can be selected with `-Models beam,shell_nr,shell_ir12,plate`.

The CPU environment is `configs/environments/testsub2_nv/`; the CUDA environment
is `configs/environments/testsub2_nv_gpu/`. ODE and beam trajectories use sparse,
full-state Rodas5P integration with an analytic Jacobian. Shell and plate trajectories
use ninth-order Vern9 integration on the GPU in a scaled, invertible basis containing
every mechanical mode, with Float64 nonlinear element forces. This is a coordinate
change for the complete equations; the stored states use the original physical DOFs.
Small batches use checked Float64 CUDA dot-product kernels for the full basis
transforms; larger batches use cuBLAS. Neither path removes mechanical modes.
Every canonical trajectory has a baseline/fine comparison with tighter tolerances and
half the maximum internal step. Independent QUAL initial conditions are separate
from the canonical population. State differences and energy-balance errors must
both be at most `1e-7`. Source identities, physical matrices, modes, initialization
parameters and energy records are evaluator-only artifacts.

The GPU implementation is checked against CPU forces, accelerations, damping power,
and the published FE linear matrices. Fixed-step ETDRK4 remains available only as
an integration comparison candidate; its coarse candidates failed qualification
and are not released as training data. GPU element-force accumulation uses Float64
atomics, so regeneration is numerically reproducible rather than guaranteed to be
bitwise identical. Published files are immutable and individually checksummed.
The GPU tolerance pair is selected using independent QUAL data and remains subject
to the same `1e-7` full-state and energy gates for every released trajectory. The
direct physical-coordinate GPU solver is retained as a comparison implementation;
its tight-tolerance runs stalled and did not produce released data.

The beam uses `C=(1e6/E)K`. The shell and plate reproduce the published
[SSMLearn FE examples](https://github.com/haller-group/SSMLearn/tree/305581114f62239b70c1fe44bce69cbf939326ea/examples)
and the Allman element in
[YetAnotherFEcode v1.1](https://github.com/jain-shobhit/YetAnotherFEcode/tree/50bc5c5ba75f2b5b32c5753dedcbd60612444f0d).
The source's nonlinear in-plane shear terms and element mass convention are
preserved. The shell geometry is translated vertically so its supported edges
lie at zero height; this does not change its mechanical matrices. Published state
matrices provide an independent assembly check. The CAN amplitudes and random
mixtures are explicit project choices; these resources are not strict replays of
the original paper's individual trajectories. No continuum mesh-convergence claim
is made for this fixed-discretization release.

`TestSub2NV.load_learner_view(abspath(configuration_folder), trajectory_id)` reads only
allowlisted canonical state/time files. Per-channel units and the physical state
ordering are also declared in each learner manifest. Train-only channel means and population
standard deviations are stored in `can/train_normalizer.jld2`; raw physical states
are not standardized. Test initialization, matrices and modes remain under
`audit_only/`. HV resources (`MEMS-GYRO` and `TRC-JOINT`) are reserved for the user's
COMSOL generation. This release creates no additional noise views.

Focused checks can be run with:

```powershell
julia --project=configs/environments/testsub2_nv test/unit/test_testsub2_nv.jl
julia --project=configs/environments/testsub2_nv_gpu test/unit/test_testsub2_nv_gpu.jl
julia --project=configs/environments/testsub2_nv experiments/data_generation/verify_testsub2_nv_dataset.jl
```

The retired Structural Spectral v3 implementation, its formerly uncommitted
changes, frozen protocol and release evidence are preserved on local branch
`codex/abolish-structural-spectral-v3-20261004`, commit `5c6d43b`.
Its `structural_spectral_v3_20260921_r2` numerical data, old run directory and active
pointer were deleted at the user's request. The retirement inventory and result
are in `runs/testsub2_nv/retirement/`; the full inventory is also preserved in the
archive commit. Standard ODE v2 remains a separate release.

## Current Autonomous ODE Release

`Standard_ODEs_v2` replaces the retired `lowdim_nonlinear_v1` resource. The qualified
release is `data/releases/standard_odes_v2_20260916/`; `data/standard_odes_active.json`
points to its manifest.

- 10 equation families, 11 CAN configurations, and 6 COND families with independent Split-I and Split-C resources.
- 23 resources, 119 condition shards, 34,432 trajectories, and 63,559,296 state vectors.
- Clean, 5 dB, and 15 dB views: 357 JLD2 files, 10.04 GiB.
- Float64 integration, Float32 storage, `trajectory × time × state_component` axes.
- Shared condition-balanced clean-Train noise reference for each resource; clean targets remain shared references.
- Independent numerical probes, full-population energy/support checks, file hashes, and complete readback validation.

```powershell
julia --threads=12 --project=. experiments/smoke_tests/run_standard_odes_v2_smoke.jl
julia --threads=12 --project=. experiments/data_generation/generate_standard_odes_v2_dataset.jl
julia --project=. experiments/data_generation/verify_standard_odes_v2_dataset.jl
julia --project=. experiments/data_generation/audit_standard_odes_v2_metadata.jl
```

The formal generator uses the full registered population. A changed source,
dependency manifest, configuration, or protocol note requires a new release identity;
the generator refuses to overwrite an existing release with a different hash.

See [the generation guide](docs/notes/file%20explanation/standard_odes_v2_file_explanation.md),
[the frozen mathematical protocol](docs/notes/mathematical%20explanation/standard_odes_v2_math.md),
and [the Chinese qualification report](reports/TestSub_1_standard_odes_v2/TestSub_1_standard_odes_v2.md).

## Archived Resources

The September cleanup retained Standard ODE v2 and its generation, validation,
and reproduction materials. Legacy code, configurations, tests, notes, reports,
and the nine previously uncommitted legacy changes are preserved under `abolish/`
on the local branch:

```text
archive/abolish-pre-standard-odes-v2-20260916
```

Archive commit: `db6bc0a88a6d230fb1d4bf94b717658ee60f1566`.
Other numerical datasets and temporary smoke data were deleted at the user's
request, reclaiming 5,819,595,100 bytes (5.42 GiB). Numerical data is not backed up
in the archive branch; regeneration requires the archived generators.

```powershell
git show archive/abolish-pre-standard-odes-v2-20260916:abolish/ARCHIVE_README.md
git ls-tree -r --name-only archive/abolish-pre-standard-odes-v2-20260916 -- abolish
```

See [the cleanup record](docs/notes/file%20explanation/standard_odes_v2_cleanup.md).
The original dependency lock remains frozen to preserve the qualified release's
configuration identity. Running the smoke command creates fresh temporary smoke
data; the historical smoke certificate and logs are retained with the report.

Downstream normalizers must be fitted on the applicable training split outside the
raw dataset. Numerical qualification statistics and noise reference powers are not
state normalization transforms.

## Project Navigation

Reusable code lives in `src/`, declarations in `configs/`, entry points in
`experiments/`, generated data in `data/`, and disposable logs in `runs/`.
`docs/spec/project_task_list.md` records completed operations; historical entries
refer to content now held by the archive branch. The active checkout is `main`.
