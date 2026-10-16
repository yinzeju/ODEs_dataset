# Dataset resource reorganization

## Task summary

Updated the explicitly supplied Dataset-2 mathematical note, retained both 144-mother
Beam resources and NACA 144, and retired every other current local dataset population.
BASE keeps 8193 snapshots. TRANSIENT is a 4096-frame exact prefix; its 4097-frame originals
remain provenance. ShellNR/IR12 and plateFE200 keep their physical definitions with
new 96/24/24 budgets but have no current population. No integration or learning ran.

## Entry points and scripts

`experiments/postprocessing/copy_dataset2_prefix.jl` accepts an explicit request JSON,
refuses overwrite, checks source SHA, writes a new JLD2, and compares every saved element.
`experiments/smoke_tests/dataset2_prefix.jl` exercises preservation and rejection contracts.
`experiments/data_generation/verify_dataset2.jl` scans all current 288 Beam trajectories.
The catalog and NACA auditors use active pointers; visualization resolution uses the
explicit historical path map without rewriting frozen source analysis.

## Sources, configurations and documentation

`configs/releases/dataset2_structural_v2.json` declares active and pending configurations;
`configs/dataset_catalog.json` defines current names. `src/data/skdm9_beam_extension.jl`
uses the byte-verified published source capsule relocated to `artifacts/source_capsules/`.
The old TestSub2NV module identity remains serialization-compatible. Frozen NACA inputs
are unchanged. The user-supplied external note is edited locally; its before/afterSHA
and snapshots remain evidence. No external learning configuration was modified.

## Data, reports and logs

Current roots: `data/Dataset-2/` and `data/Dataset-2.1/`. NACA 144 files each have one NTFS
link; old release and extension containers are absent. `data/dataset_relocations.json`
preserves old-to-current identities and verified parent hardlink retirement. Parent
metadata and 13 failed/paused prefixes are under `artifacts/lineage/Dataset-2.1/`.
Retired-dataset metadataZIP, protocol snapshots and deletion plans are under
`artifacts/lineage/retired_datasets_20261016/`. Detailed action receipts remain in
`runs/dataset_reorganization_20261016/`; raw data and local archives are excluded from Git.
Formal Chinese report and appendix: `reports/Dataset_2_v2_resource_reorganization/`.

## Data flow

Original manifests → checked same-volume moves → explicit TRANSIENT prefix request →
readback/SHA receipts → canonical learner and release manifests → authorized deletion
→ final current-population and NACA integrity audits. Preserved source/provenance
records do not add to current formal trajectory counts.

## Validation

Prefix contracts 6/6; naming/access contracts 11/11; published source capsule hashes pass;
current Beam 288 full readbacks; retained original 432 file hashes; NACA 144 all-state/port,
initialSHA, runtime gate and manifest checks; visualization 103 offline links and 5 source
hashes; note 44 unique equation tags with 3 resolved equation references. Package-wide
tests, new qualification and new simulations were not run. The deletion receipt
distinguishes apparent path bytes from unique NTFS allocation reclaimed.
