# Archived reports — 2026-10-16

These report packets are historical records and are not current data reports.
They were moved byte-for-byte from their original `reports/` locations, with
local ignored logs and tables preserved alongside formerly tracked documents.

| Original report packet | Archive | Reason |
|---|---|---|
| Dataset-1 Standard ODE v2 | [Report](reports/TestSub_1_standard_odes_v2/TestSub_1_standard_odes_v2.md) | Numerical dataset retired locally |
| Original TestSub_2 nonlinear vibration | [Report](reports/TestSub_2_nonlinear_vibration/TestSub_2_nonlinear_vibration.md) | Old small populations and retired Duffing scope |
| Dataset-2 resource reorganization | [Report](reports/Dataset_2_v2_resource_reorganization/Dataset_2_v2_resource_reorganization.md) | Operation report; current data reports live under Dataset-2/2.1 |

The [manifest](manifest.json) records every original/destination path, byte size
and SHA256. Original relative references inside frozen historical reports retain
their original report context; use `configs/report_catalog.json` for relocations.
An archive Git branch `codex/archive-reports-before-abolish-20261016` preserves
the pre-operation tracked checkout at `95a1043`.

No report file or numerical dataset was deleted in this operation. Large local
media and ignored historical logs are not newly forced into Git. Only formerly
tracked archive material and this navigation/manifest are published.
