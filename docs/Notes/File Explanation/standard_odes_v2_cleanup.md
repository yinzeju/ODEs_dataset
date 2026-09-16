# Standard ODE v2 Project Cleanup

## Task Summary

On 2026-09-16 the user requested that the project retain only the newly qualified
Standard ODE v2 dataset and its supporting materials. Legacy source and reports
were moved under `abolish/` on a dedicated local Git branch, and the active checkout
was returned to `main` with the legacy resources removed.

## Archive and Recovery

- Branch: `archive/abolish-pre-standard-odes-v2-20260916`.
- Archive commit: `db6bc0a88a6d230fb1d4bf94b717658ee60f1566`.
- 234 retired files were preserved with their original relative paths under `abolish/`.
- All nine previously modified/untracked legacy paths were included.
- Five original root/environment/ledger snapshots, an archive README, and an inventory
  bring the archive directory to 241 Git-tracked files.
- Every retired file's SHA-256 was verified before and after moving; the staged Git
  blob was then verified against the committed archive tree.

```powershell
git show archive/abolish-pre-standard-odes-v2-20260916:abolish/ARCHIVE_README.md
git ls-tree -r --name-only archive/abolish-pre-standard-odes-v2-20260916 -- abolish
git show archive/abolish-pre-standard-odes-v2-20260916:abolish/src/data/highdim_nonlinear_v2/l96.jl
```

Inspect the archive with `git show` without switching the active project. No remote
push was requested or performed. Numerical datasets are not stored in this branch.

## Retained Source, Configurations, and Data

- `src/data/standard_odes_v2/`: the four unchanged generation-module files.
- `configs/releases/standard_odes_v2.json`: the unchanged formal protocol config.
- `experiments/data_generation/`: the Standard ODE generator, verifier, and metadata auditor.
- `experiments/smoke_tests/run_standard_odes_v2_smoke.jl` and its focused test file.
- `data/releases/standard_odes_v2_20260916/` and `data/standard_odes_active.json`.
- Standard ODE mathematical/file explanations, the operation ledger, current report,
  reproduction snapshots, certificates, and logs.
- The original `Project.toml` and `Manifest.toml`; dependency removal would change
  the qualified release's frozen identity, so they were retained unchanged.

## Deleted Numerical Resources

Removed the controlled low-dimensional, Duffing augmented, high-dimensional,
and L96-10 releases; the separate Duffing processed/manifests folders; and all
temporary smoke tensors, including Standard ODE smoke tensors. Empty legacy
directory scaffolding was also removed.

The deleted-data inventory contains 1,837 files totaling **5,819,595,100 bytes**
(5.42 GiB). Their paths, byte counts, and SHA-256 hashes are preserved in
`reports/TestSub_1_standard_odes_v2/cleanup/inventory.json`. This inventory is an
audit record, not a recoverable copy of the numerical data. Regenerate retired
datasets from the archived code if they are needed later.

The successful historical smoke certificate was copied to
`reports/TestSub_1_standard_odes_v2/cleanup/smoke_verification_before_cleanup.json`.
The retained smoke script can generate fresh temporary data when explicitly run.

## Validation Commands and Evidence

```powershell
julia --project=. experiments/data_generation/verify_standard_odes_v2_dataset.jl
julia --project=. experiments/data_generation/audit_standard_odes_v2_metadata.jl
julia --project=. -e 'include("src/data/standard_odes_v2/StandardODEsV2.jl"); include("test/unit/test_standard_odes_v2.jl")'
```

Cleanup validation logs are in `reports/TestSub_1_standard_odes_v2/cleanup/`.
The 370 focused assertions passed; the metadata audit checked 357 views and 42
required fields with zero overlap between the 34,432 IC seeds and 195 probe seeds.
The complete verifier checks all 357 file hashes, finite values, tensor layouts,
time grids, split identities, and clean-target alignment. The dataset remains
34,432 trajectories and 63,559,296 state vectors.

No dataset regeneration, model training, dependency updates, or package-wide tests
were required for this cleanup. Archive creation and the final main-branch cleanup
are separate commits so the retired materials remain accessible independently.
