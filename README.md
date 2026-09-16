# ODEs_dataset

Julia generation and qualification of the Standard ODE v2 full-state datasets.

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

Only Standard ODE v2 and its generation, validation, and reproduction materials
remain in the active checkout. Legacy code, configurations, tests, notes, reports,
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
