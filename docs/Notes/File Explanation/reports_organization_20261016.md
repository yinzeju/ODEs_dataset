# Dataset report organization

## Task summary

The user requested only Dataset-2 and Dataset-2.1 data reports in `reports/`,
with other report packets preserved under `abolish/`, followed by commit/push.
Current report groups are `reports/Dataset-2/` and `reports/Dataset-2.1/`.
The former contains a Chinese report/appendix covering both current Beam datasets;
the latter preserves the NACA formal report, appendix, illustrative metrics and media.
No numerical data or simulation settings were changed.

## Entry points and scripts

`experiments/postprocessing/audit_report_catalog.py` validates current report roots,
Markdown navigation, preserved archive hashes, pointer consistency and current
dataset-manifest bindings. `dataset21_nlc6_report.py` uses the current report root
and resolves historical report namespaces through `configs/report_catalog.json`.
`audit_dataset21_nlc6_report.py` preserves frozen relocation receipts and checks
their bytes at the new location. The retained old NACA plotting entry point now
uses the new report namespace.

## Source, configuration and documentation changes

`configs/report_catalog.json` records active reports and exact old/new paths.
Dataset active pointers and `configs/dataset_catalog.json` now identify the current
report paths. README, report inventory and autonomous handoff navigation were updated.
The original NACA scientific main report/appendix and frozen relocation/source
evidence are byte-identical; only current navigation/audit manifests were refreshed.
The new Dataset-2 report cites the explicitly supplied mathematical note and the
authenticated current Exp2 protocol, and distinguishes source numerical qualification
from the existing4096-frame prefix and from ungenerated shell/plate populations.

## Report and archive artifacts

`reports/README.md` is the current index. The complete old Dataset-1 packet,
original TestSub_2 mixed-object report and previous resource-operation report are
under `abolish/reports_20261016/reports/`. The old SKDM9 Beam evidence belongs to
Dataset-2 and is retained at `reports/Dataset-2/evidence/source_skdm9_beam_extension.json`.
Archive manifest: `abolish/reports_20261016/manifest.json`; pre-operation branch:
`codex/archive-reports-before-abolish-20261016` at `95a10435c94a1fb9fdb8c260b730e1c198db507e`.
Ignored logs/media remain local and are not newly force-added to Git.

## Data flow

Old report inventory and exact hashes → same-volume directory moves → current
report catalog → Beam data-report consolidation → pointer and dashboard refresh
→ active-link/archive-hash checks → scoped publication. Detailed movement receipt
is in `runs/reports_organization_20261016/`; compact evidence is
`docs/Notes/evidence/reports_organization_20261016.json`.

## Validation

All168 original files passed exact-byte checks immediately after movement;23 archived
files still match their original hashes. Final active Markdown navigation checked
39 links. NACA retained103 offline links, five
source trajectory hashes and unchanged current GIF bytes/settings. Current three
dataset manifests and the two Beam learner manifests match their SHA bindings.
No simulation, independent qualification, model scoring or package-wide test ran.
