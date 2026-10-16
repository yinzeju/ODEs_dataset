# Current Dataset Inventory

Updated: 2026-10-16. Current local dataset groups are Dataset-2 and Dataset-2.1.
The authoritative catalog is [configs/dataset_catalog.json](../../configs/dataset_catalog.json).

| Protocol object | States | Train / Val / Test | Snapshots including initial state | Trajectory file bytes | Status |
|---|---:|---|---:|---:|---|
| Dataset-2 / VK-BEAM-CC / BASE | 66 | 96 / 24 / 24 | 8193 | 632561472 | Preserved original SKDM9 truth |
| Dataset-2 / VK-BEAM-CC / TRANSIENT | 66 | 96 / 24 / 24 | 4096 | 316372248 | Exact saved prefix; original 4097-frame source preserved |
| Dataset-2.1 / FE-NACA-NLC6 | 29844 | 96 / 24 / 24 | 4096 | 140940259488 | Complete; independent qualification waived by user |

There are 432 current formal trajectories, 288 Beam and 144 NACA. Source/provenance
copies and qualification records are excluded from these counts. No simulation ran.
All state counts represent full physical coordinates, not modal-reduced dynamics.

| Protocol-defined pending configuration | States | Required Train / Val / Test | Required snapshots | Current local population |
|---|---:|---|---:|---:|
| Dataset-2 / VK-SHELL-SHALLOW / NR | 2640 | 96 / 24 / 24 | 4096 | 0 |
| Dataset-2 / VK-SHELL-SHALLOW / IR12 | 2640 | 96 / 24 / 24 | 4096 | 0 |
| Dataset-2 / VK-PLATE-SQUARE / FE200 | 1212 | 96 / 24 / 24 | 4096 | 0 |

The supplied Dataset-2 mathematical note removes OSC-DUFFING8, adds the explicitly
modified transient Beam model, and preserves shell/plate physics. Pending population
recipes require a future frozen generation configuration and explicit execution request.

Current roots are `data/Dataset-2/` and `data/Dataset-2.1/`. The former release and
extension containers were removed. Dataset-1 and the TestSub_2 small CAN/QUAL
populations are locally retired; their old active pointers are removed. Frozen source
capsules, original metadata, reports and failed/paused NACA prefixes remain identifiable.
See [relocations](../../data/dataset_relocations.json) and the
[organization report](../../reports/Dataset_2_v2_resource_reorganization/Dataset_2_v2_resource_reorganization.md).

Dataset-3 and Dataset-3.1 remain note-only. Previous Structural Spectral v3 and
pre-NLC6 NACA numerical releases remain retired and were not recreated.
