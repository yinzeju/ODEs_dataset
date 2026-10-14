# Dataset-2.1 NACA-NLC6 visualization workspace

Open [tables/index.html](tables/index.html) for the complete visualization summary.
It combines four accepted population examples and the separate exploratory trial.
The formal144-trajectory population is complete and passed final full-state/SHA verification.
Read [the Chinese formal report](Dataset21_NLC6_v1_nonlinear_wing.md),
[numerical appendix](NLC6_numerical_appendix.md) and
[full integrity evidence](evidence/campaign_integrity_04.json).

Current animations use 10x displacement, six-second playback, equal physical axis
units, and light-gray actual exterior contours. They show the first 0.20 s of
motion; all history metrics use the complete 4096-frame, 2.0475 s trajectory.
Colors encode actual normal displacement in mm, without the display gain.

| Location | Contents |
|---|---|
| `tables/index.html` | Main offline dashboard, metrics, figures, GIFs and downloads |
| `tables/summary.csv` | Four selected population cases and one separately labeled trial |
| `tables/selected/<id>/` | Full-history metrics CSV and source-bound analysis JSON |
| `tables/trial/` | Separate exploratory-trial metrics |
| `plots/selected/`, `plots/trial/` | Current diagnostic figures, with PDF copies where originally generated |
| `animations/selected/<id>/`, `animations/trial/` | Current 10x GIFs, representative frames and frozen render receipts |
| `evidence/` | Source receipts, artifact hashes, migration map and audit results |
| `archive/index.html` | Historical renderings, incomplete repair attempts and the retired NACA preview |
| `archive/frozen_sources/` | Exact source bytes used before this organization task |

The original simulation HDF5 files, reference arrays, models, meshes and campaign
logs remain under `data/`, `artifacts/` and `runs/`. This report consumes them;
it does not duplicate or move the full-state dataset. Selected examples retain
their actual parent-release provenance rather than claiming new generation.

Historical receipts are immutable and may contain old file paths. Resolve those
paths through [evidence/relocation.json](evidence/relocation.json). Current paths
and hashes are indexed by [evidence/report_manifest.json](evidence/report_manifest.json).
Retired NACA visualizations use a different model and are not current NLC6 evidence.

Maintained postprocessing entry points are under `experiments/postprocessing/`;
the report identity and selection live in `configs/visualizations/dataset21_nlc6_report.json`.
From the project root, the following commands use Python and existing saved data:

```powershell
python -X utf8 experiments/postprocessing/dataset21_nlc6_report.py
python -X utf8 experiments/postprocessing/audit_dataset21_nlc6_report.py
```

The first command rebuilds only the HTML summary and CSV; the second audits the
relocation, local links, saved metrics and GIF properties. To deliberately redraw
existing data, use `plot_dataset21_nlc6_selected.py`,
`analyze_dataset21_nlc6_one.py --gif`, or `render_dataset21_nlc6_preview.py` in
the same directory. Use a new versioned `--out` directory when redrawing a frozen
packet, so the original migration hashes remain reproducible. None of these
commands starts a simulation. Re-run the audit after adding report assets.
The drawing entry points reject overwriting the existing frozen packet or GIF.
The one-time organization script refuses a second
application once its migration receipt exists.

Independent time/grid qualification remains waived. Runtime checks and complete
readback support the selected files; this illustrative subset does not establish
population-wide behavior. The analytic same-initial-condition linear reference
includes phase accumulation in its differences and is not a direct percentage
measure of nonlinearity. The formal report and appendix now document the complete population.
The visual examples remain illustrative and separate from the population audit.
