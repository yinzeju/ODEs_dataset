# Dataset Inventory

Inventory timestamp: `2026-10-11T00:08-07:00`. Canonical protocol codes use
`Dataset-N`; the repository directory remains `ODEs_dataset`.

## Published Local Data

| Canonical code | Population | State dimensions | Snapshots per trajectory | Files | Bytes | GB |
| --- | --- | --- | --- | ---: | ---: | ---: |
| Dataset-1 | 34432 trajectories; 23 CAN/COND resources, 119 condition shards, 3 views | 2, 3, 4, 64 | 51, 1001, 1025, 2001, 2049, 3001, 4097, 5001, 8193 | 872 | 10,845,350,414 | 10.845350 |
| Dataset-2 | 62 trajectories CAN + 12 QUAL; 5 configurations | 16, 66, 1212, 2640 | 4097 | 425 | 2,952,115,920 | 2.952116 |
| Dataset-2/SKDM9-Beam-H512 | 144 trajectories; 96/24/24 splits | 66 | 8193 | 581 | 661,426,350 | 0.661426 |
| Dataset-2/SKDM9.6-Beam-Transient-H2048 | 144 trajectories; 96/24/24 splits | 66 | 4097 | 583 | 331,610,101 | 0.331610 |

Total: **2,461 files, 14,790,502,785 bytes (14.790503 GB)**.
GB is decimal. Sizes include each published artifact directory's numerical data,
qualification and audit files. Dataset-1 counts physical trajectories once, not
once per clean/noisy view. The two Beam extensions are separate configurations;
their SKDM task identities and numerical contracts are not renamed to Dataset task numbers.

## Canonical And Frozen Identities

The machine-readable [catalog](../../configs/dataset_catalog.json) maps every current
code to its exact artifact root, manifest checksum, legacy aliases and current note.
The current note is a protocol reference; its hash is not substituted for the
frozen note hash that produced an existing release.

| Canonical code | Preserved artifact identity | Canonical entry |
| --- | --- | --- |
| Dataset-1 | `standard_odes_v2_20260916` / `Standard_ODEs_v2` | `data/dataset1_active.json`; `src/data/dataset1/Dataset1.jl` |
| Dataset-2 | `testsub2_nv_20261004` / `TestSub2` | `data/dataset2_active.json`; `src/data/dataset2_nv/Dataset2NV.jl` |
| Dataset-2/SKDM9-Beam-H512 | `skdm9_beam_h512_v1` | catalog learner-manifest entry |
| Dataset-2/SKDM9.6-Beam-Transient-H2048 | `skdm96_beam_transient_h2048_v1` | catalog learner-manifest entry |

The `testsub2_nv` source/environment directories, Julia producing module name, RNG
namespace, frozen source bindings and historical report/task identities are compatibility
identifiers. They deliberately retain their original spelling. No frozen binary,
manifest, certificate or note snapshot is relabeled or rewritten. Old pointers and
entry points remain usable. The new API aliases preserve JLD2 type identity.

Dataset-2 now contains only `MECH-ODE` and `MECH-FE`: Duffing8, Beam FE12, Shell NR,
Shell IR12 and Plate FE200. The removed HV objects never had local generated data.
The old release manifest and source snapshots still truthfully record their former
pending-HV metadata; the current catalog and note define the reduced active scope.

Dataset-3 and Dataset-3.1 exist as notebook protocols, but no local release was found.
The retired Structural Spectral v3 release is absent; its code remains on the
existing archival branch. This operation does not delete any data.

## Auxiliary Storage

These folders are not additional published datasets. Their sizes are a point-in-time
inventory and may grow as validation logs or compiled caches are written.

| Directory | Files | Bytes | GB |
| --- | ---: | ---: | ---: |
| `data/cache` | 32 | 12,637,564 | 0.012638 |
| `data/.julia_depot` | 700 | 778,019,175 | 0.778019 |
| `runs` | 136 | 659,713,781 | 0.659714 |

The published-data total excludes these folders, the Git object database, source
files and reports. No cleanup of auxiliary storage was requested.

## Verification And Naming Migration

```powershell
python -X utf8 experiments/data_generation/audit_dataset_catalog.py --verify-data
julia --project=configs/environments/testsub2_nv test/unit/test_dataset_protocol_names.jl
julia --project=configs/environments/testsub2_nv experiments/data_generation/verify_dataset2.jl
julia --project=. experiments/data_generation/verify_dataset1.jl
```

The catalog audit checks the four recorded manifest hashes and, with `--verify-data`,
all 357 Dataset-1 data views, 423 Dataset-2 cataloged artifacts and 288 Beam-extension
trajectory files. It reports current file sizes and does not modify the data.
The canonical Dataset verifiers also use read-only validation paths. Existing
generation settings still refuse overwriting an incompatible frozen release.

The Dataset-2 notebook revision removes HV objects, their budgets, sampling and
COMSOL/contact-specific requirements, and renumbers the surviving later sections.
The ODE/FE mechanics in sections 6 through 9 are byte-for-byte unchanged. Three
directly dependent notes receive only a scope-description or obsolete-link correction.

Validation receipts are under `runs/dataset_naming_20261011/`. This task changes
naming/navigation and protocol scope; it does not claim a new numerical experiment.

Validation completed: 1,068 indexed artifact hashes passed; Dataset2 naming/type/access
checks passed 11/11; Dataset-1 complete readback passed 357 views across 119 shards;
Dataset-2 complete readback passed all five configurations. The note has 49 unique
equation tags with surviving references resolved. No numerical regeneration occurred.
