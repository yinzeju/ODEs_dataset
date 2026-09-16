# ODEs_dataset

Julia generators for full-state dynamical-system datasets in raw physical coordinates.

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
```

The formal generator uses the full registered population. A changed source,
dependency manifest, configuration, or protocol note requires a new release identity;
the generator refuses to overwrite an existing release with a different hash.

See [the generation guide](docs/notes/file%20explanation/standard_odes_v2_file_explanation.md),
[the frozen mathematical protocol](docs/notes/mathematical%20explanation/standard_odes_v2_math.md),
and [the Chinese qualification report](reports/TestSub_1_standard_odes_v2/TestSub_1_standard_odes_v2.md).

## Other Dataset Groups

The controlled and high-dimensional resources have their own generation protocols:

| Group | Scope |
| --- | --- |
| `duffing_aug_snr10` | Controlled forced Duffing, clean and 10 dB observations |
| `controlled_lowdim_v1` | Controlled low-dimensional AUG, ADD, and BIL resources |
| `highdim_nonlinear_v2` | L96-40, KS64, and FHN64 |

Existing additional releases and ongoing work remain separate from Standard ODE v2.
Downstream normalizers must be fitted on the applicable training split outside the
raw dataset. Numerical qualification statistics and noise reference powers are not
state normalization transforms.

## Project Navigation

Reusable code lives in `src/`, declarations in `configs/`, entry points in
`experiments/`, generated data in `data/`, and disposable logs in `runs/`.
`docs/spec/project_task_list.md` records completed operations. Older documentation
is historical; the v1 numerical files and obsolete v1 generation entry points were
retired after v2 passed qualification.
