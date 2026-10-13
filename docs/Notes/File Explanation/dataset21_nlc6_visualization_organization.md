# NLC6 visualization organization

## Task summary

The user requested a single organized report workspace for the prior NACA-NLC6
plotting work, then specified that the HTML page belong in `tables/` as the overall
summary. The concrete report identity is `Dataset21_NLC6_v1_nonlinear_wing`.
This operation organizes existing evidence; the 144-trajectory campaign is still
running, and its final Chinese scientific report and numerical appendix are pending.

## Entry points

- `experiments/postprocessing/dataset21_nlc6_report.py`: rebuild the HTML summary
  and five-row summary CSV from saved analysis, without simulation or rendering.
- `plot_dataset21_nlc6_selected.py`: four declared population examples, full-history
  diagnostics and current 10x animation; accepts a report-root `--out` argument.
- `analyze_dataset21_nlc6_one.py`: separate exploratory-trial diagnostics; optional
  `--gif` now uses the shared corrected 10x/six-second renderer.
- `render_dataset21_nlc6_preview.py`: corrected closed-exterior geometry, equal axis
  units, shallow outlines and a projected viewport check over every animation frame.
- `audit_dataset21_nlc6_report.py`: verify relocation hashes, local links, source
  trajectory hashes, saved metrics and animation duration/scale/viewport receipts.
- `organize_dataset21_nlc6_visuals.py`: recorded one-time migration; refuses repeat
  application when its relocation receipt exists.

The four original analysis/rendering entry points moved from `data_generation/`
to `postprocessing/`, including the preserved original NACA plotting/mesh reader.
Exact pre-organization source bytes remain in the report's `archive/frozen_sources/`.
Use a distinct versioned output directory when redrawing a frozen packet.

## Core configuration and documents

`configs/visualizations/dataset21_nlc6_report.json` declares the report identity,
four selected IDs, separate trial and accepted animation settings. It is a
presentation configuration, not a simulation input. Project README, population
guide, autonomous handoff, ledger and object registry point to the new workspace.
The heartbeat prompt and ignored runtime control state also use the new paths.

## Generated outputs and historical preservation

`reports/Dataset21_NLC6_v1_nonlinear_wing/tables/index.html` is the single current
summary. It includes the overview, five GIFs, response/velocity/phase/spectrum/
energy/strain figures, source-aware metrics, CSV downloads and historical links.
Current figures, animations and numeric tables are separated into `plots/`,
`animations/` and `tables/`; source receipts and hashes are under `evidence/`.

The migration covered 146 original files, preserving 120 unique assets and merging
26 identical copies. It reclaimed 41,571,995 bytes. The full old-to-new map and
each original SHA256 are in `evidence/relocation.json`; every original byte remains
recoverable from its mapped file. Historical HTML source is archived as plain text
to avoid confusing its stale relative links with the current dashboard.
Retired NACA figures, superseded25x/35x/three-second animations and incomplete
render-repair diagnostics remain in `archive/`. The retired model's original
trajectory data were previously deleted by separate authorization; these figures
do not establish current NLC6 results.

Original simulation HDF5 files, the trial reference HDF5, base models, meshes,
active frozen Julia sources/configuration and worker records remain in place.
The four accepted population sources retain their original parent provenance.
Original trial analysis and completion records remain in `runs/`, with compact
copies in the report. Historical receipts keep their exact original path strings;
resolve those strings through the relocation map.

Git tracks the maintained scripts, configuration, navigation HTML/README, compact
summary and audit records. Large media, per-frame CSV files and local archives stay
ignored. A source checkout alone does not restore the locally curated images/data.

## Data flow

Existing accepted HDF5 plus generation/readback receipts feed CPU analysis.
Saved analysis JSON and metrics CSV feed the summary builder; the corrected
renderer reads the unchanged physical displacement snapshots. The migration only
classifies, copies, hashes and relocates existing presentation files. It removes
source files after destination equality is verified and merges only equal hashes.
The auditor then reads all current GIFs, the four complete CSV histories and the
five source trajectory hashes, and writes the current artifact manifest.

## Validation

- One-time migration completed with all 146 source records preserved.
- Python syntax checks and all three active entry-point `--help` imports passed.
- Dashboard rebuild passed without starting a simulation.
- Offline link audit passed 100 links across the summary and archive navigation.
- Four histories passed 4096-row sampling and saved-metric agreement checks.
- Five source trajectory SHA256 values were independently reverified.
- Five current GIFs passed 150-frame, 6000 ms, 10x and projected-clearance checks.
- The active Julia PID and creation time were verified before/after organization;
  all 20 frozen campaign input hashes remain unchanged.

The browser automation policy blocked `file://` access, so browser-based visual
inspection and automatic tab navigation were unavailable. Static HTML/link checks
and direct image/GIF verification support the files; the user can open the new
dashboard directly. No new smoke, simulation or independent qualification ran.
