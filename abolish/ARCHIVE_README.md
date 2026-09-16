# Abolished Dataset Resources

This branch archives the resources retired when the project was narrowed to
Standard_ODEs_v2 on 2026-09-16. Original relative paths are preserved under `abolish/`.
The archive includes legacy source, configurations, tests, notes, reports/figures,
and all nine modified or untracked legacy paths present before cleanup.

The numerical datasets are intentionally deleted at the user's request and are not
stored in Git. `cleanup_inventory.json` records their paths, sizes, and SHA-256 hashes.
Original root dependency manifests, README, ignore rules, and the operation ledger
are preserved alongside the code. Some archived scripts require regenerating data.

To inspect this archive without switching the working project, use:

```powershell
git ls-tree -r --name-only archive/abolish-pre-standard-odes-v2-20260916 -- abolish
git show archive/abolish-pre-standard-odes-v2-20260916:abolish/src/data/highdim_nonlinear_v2/l96.jl
```

The active project remains on `main` after cleanup. This is a local archive branch;
no remote publication was requested.
