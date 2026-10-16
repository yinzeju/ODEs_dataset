# ODEs_dataset

Julia structural dataset generation, numerical evidence, and data-only access.
Current local dataset codes are **Dataset-2** and **Dataset-2.1**. The 2026-10-16
organization retains three 144-trajectory resources; no new dynamics were integrated.

| Dataset / object | State dimension | Train / Val / Test | Saved snapshots, including initial state | Current root |
|---|---:|---|---:|---|
| Dataset-2 / VK-BEAM-CC / BASE | 66 | 96 / 24 / 24 | 8193 | `data/Dataset-2/VK-BEAM-CC/BASE` |
| Dataset-2 / VK-BEAM-CC / TRANSIENT | 66 | 96 / 24 / 24 | 4096 | `data/Dataset-2/VK-BEAM-CC/TRANSIENT` |
| Dataset-2.1 / FE-NACA-NLC6 | 29844 | 96 / 24 / 24 | 4096 | `data/Dataset-2.1` |

Use [the catalog](configs/dataset_catalog.json), [Dataset-2 pointer](data/dataset2_active.json),
[Dataset-2.1 pointer](data/dataset21_active.json), and [inventory](docs/Notes/dataset_inventory.md).
A record with M snapshots has M-1 time intervals. BASE retains the complete original
SKDM9 history. TRANSIENT is an exact 4096-frame prefix of the original 4097-frame
SKDM9.6 record; original 144 files, certificates and source metadata remain in its
`provenance/source_release/`. Existing source IDs remain immutable lineage.

The Dataset-2 protocol also retains shallow-shell NR/IR12 and square-plate FE200
models, each targeting 96/24/24 and4096 snapshots. Their former small populations
were deleted, and no new population has been generated. OSC-DUFFING8 is removed
from the active protocol. Formal generation remains unauthorized.

Dataset-1 numerical files and the original TestSub_2 small populations were
explicitly retired locally. Their source, configurations, reports and metadata
remain historical; an archive branch preserves the pre-operation checkout:
`codex/archive-datasets-before-reorganization-20261016` at `000286d`.
The archive branch does not contain deleted numerical trajectories.

NACA's144 files are consolidated with one NTFS link per file. `data/releases/`
and `data/extensions/` are removed. Historical paths resolve through
[data/dataset_relocations.json](data/dataset_relocations.json). Failure/paused
prefixes, original worker receipts and source capsules remain evidence. All original
NACA runtime gates and `user_waived_independent_qualification` remain unchanged.

Read-only checks, without integration:

```powershell
python -X utf8 experiments/data_generation/audit_dataset_catalog.py
julia --startup-file=no --threads=1 --project=configs/environments/testsub2_nv experiments/data_generation/verify_dataset2.jl
```

The maintained `Dataset2NV` API aliases the original `TestSub2NV` module to retain
JLD2 compatibility. Each current Beam configuration has a `manifests/learner_manifest.json`;
`load_learner_view` admits only indexed clean trajectory files. Published base source
capsules remain at `artifacts/source_capsules/Dataset-2/testsub2_nv_20261004/`.
Legacy generators and frozen configurations are historical and must not be used to
recreate retired releases without a new explicit generation request.

The NACA [offline visualization](reports/Dataset-2.1/tables/index.html)
retains its four formal examples and separate exploratory trial. Its
[formal report](reports/Dataset-2.1/Dataset21_NLC6_v1_nonlinear_wing.md)
and numerical appendix describe the original completed campaign. Current data reports are indexed in [reports/README.md](reports/README.md).
Large numerical data and local archives remain outside Git.
