"""Migrate explicitly scoped visualization files with verified byte preservation."""
import argparse
import datetime
import hashlib
import html
import json
import os
from pathlib import Path
import shutil

from dataset21_nlc6_report import ROOT, REPORT_ROOT, CONFIG, build_dashboard, read_json, write_json

SELECTED = ROOT / "runs/dataset21_nlc6_selected_previews_20261012"
TRIAL = ROOT / "runs/dataset21_nlc6_trial_01"
REPAIR = ROOT / "runs/naca_gif_render_fix_02"
RETIRED = ROOT / "reports/Dataset21_NACA_v3_partial_preview"
SCOPES = [SELECTED, TRIAL / "plots", REPAIR, RETIRED]
SCRIPTS = ["analyze_dataset21_nlc6_one.py", "plot_dataset21_nlc6_selected.py",
    "render_dataset21_nlc6_preview.py", "plot_dataset21_naca_completed.py"]


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require_child(path, parent):
    path = path.resolve()
    parent = parent.resolve()
    if path == parent or not path.is_relative_to(parent):
        raise ValueError(f"Path escapes its explicitly scoped parent: {path}")
    return path


def classify(source):
    if source.is_relative_to(SELECTED):
        rel = source.relative_to(SELECTED)
        if len(rel.parts) == 1:
            if rel.name.startswith("overview."):
                return Path("plots/selected") / rel.name
            if rel.name == "manifest.json":
                return Path("evidence/selected/manifest.json")
            if rel.suffix == ".html":
                return Path("archive/records/selected") / (rel.name + ".source.txt")
            return Path("archive/records/selected") / rel
        case, *tail = rel.parts
        rest = Path(*tail)
        if rest.parts[0] == "render_v3_10x":
            return Path("animations/selected") / case / rest.name
        if len(tail) == 1 and rest.name in ["initial.png", "midpoint.png", "render_metadata.json", "wing_vibration_6s_10x.gif"]:
            return Path("animations/selected") / case / rest.name
        if rest.stem in ["displacement_velocity", "energy_strain", "ports_phase_spectrum"]:
            return Path("plots/selected") / case / rest
        if rest.name in ["metrics.csv", "analysis.json"]:
            return Path("tables/selected") / case / rest
        return Path("archive/selected") / case / rest
    if source.is_relative_to(TRIAL / "plots"):
        rel = source.relative_to(TRIAL / "plots")
        if rel.parts[0] == "preview_6s_10x":
            return Path("animations/trial") / rel.name
        if len(rel.parts) == 1 and rel.stem in ["diagnostics", "ports_and_modes", "connector_laws"]:
            return Path("plots/trial") / rel.name
        return Path("archive/trial") / rel
    if source.is_relative_to(REPAIR):
        return Path("archive/render_repairs") / source.relative_to(REPAIR)
    if source.is_relative_to(RETIRED):
        return Path("archive/retired_naca_preview") / source.relative_to(RETIRED)
    raise ValueError(f"Unregistered migration source: {source}")


def inventory():
    files = [f for scope in SCOPES if scope.exists() for f in scope.rglob("*") if f.is_file()]
    files.sort(key=lambda f: (0 if "render_v3_10x" in f.parts else 1, str(f)))
    by_hash = {}
    records = []
    for source in files:
        require_child(source, ROOT)
        if source.is_symlink():
            raise ValueError(f"Symlink is outside this byte-preserving migration: {source}")
        sha = digest(source)
        target = classify(source)
        if sha in by_hash:
            target = by_hash[sha]
            operation = "merge_verified_identical_copy"
        else:
            by_hash[sha] = target
            operation = "relocate"
        destination = require_child(REPORT_ROOT / target, REPORT_ROOT)
        if destination.exists() and digest(destination) != sha:
            raise ValueError(f"Destination has different bytes: {destination}")
        records.append(dict(source=source.relative_to(ROOT).as_posix(),
            destination=destination.relative_to(ROOT).as_posix(), sha256=sha,
            bytes=source.stat().st_size, operation=operation))
    return records


def archive_page(records):
    links = []
    seen = set()
    for row in records:
        path = ROOT / row["destination"]
        if not path.is_relative_to(REPORT_ROOT / "archive") or path.suffix.lower() not in [".png", ".gif", ".pdf"]:
            continue
        relative = path.relative_to(REPORT_ROOT / "archive").as_posix()
        if relative not in seen:
            links.append(f'<li><a href="{html.escape(relative)}">{html.escape(relative)}</a></li>')
            seen.add(relative)
    (REPORT_ROOT / "archive/index.html").write_text('<!doctype html><html lang="en"><meta charset="utf-8"><title>Archived NLC6 visualization work</title>'
        '<style>body{font:16px/1.6 system-ui;max-width:1100px;margin:40px auto;padding:20px}a{color:#1b5d99}</style>'
        '<h1>Historical visualization work</h1><p><a href="../tables/index.html">Return to the current summary</a></p>'
        '<p>These superseded or incomplete renderings are retained as historical evidence. Some have incorrect clipping, geometry, magnification or playback settings. '
        'The retired NACA preview uses a different physical model, and its original trajectory data were deleted by prior user authorization. '
        'Use only the current 10x animations in the summary for presentation.</p><ul>' + ''.join(links) + '</ul></html>', encoding="utf-8")


def migrate():
    receipt = REPORT_ROOT / "evidence/relocation.json"
    if receipt.exists():
        raise RuntimeError("Migration already recorded. Use the report audit instead of running it again.")
    records = inventory()
    REPORT_ROOT.mkdir(parents=True, exist_ok=True)
    # Write the complete plan before moving or removing any source file.
    write_json(REPORT_ROOT / "evidence/relocation_plan.json", records)
    for row in records:
        source, destination = ROOT / row["source"], ROOT / row["destination"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists():
            shutil.copy2(source, destination)
        if digest(destination) != row["sha256"]:
            raise ValueError(f"Copied file failed its source hash: {destination}")
    # Preserve exact historical source versions before relocating maintained entry points.
    source_records = []
    for name in SCRIPTS:
        source = require_child(ROOT / "experiments/data_generation" / name, ROOT / "experiments/data_generation")
        frozen = require_child(REPORT_ROOT / "archive/frozen_sources/experiments/data_generation" / name, REPORT_ROOT)
        frozen.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, frozen)
        sha = digest(source)
        assert digest(frozen) == sha
        target = require_child(ROOT / "experiments/postprocessing" / name, ROOT / "experiments/postprocessing")
        if target.exists():
            raise ValueError(f"Maintained script destination already exists: {target}")
        source_records.append(dict(source=source.relative_to(ROOT).as_posix(),
            frozen_copy=frozen.relative_to(ROOT).as_posix(), maintained_destination=target.relative_to(ROOT).as_posix(), sha256=sha))
    for name in ["analysis.json", "analysis_manifest.json", "initial_condition.json", "completion.json", "trajectory.h5.json", "trial_summary.md"]:
        source = TRIAL / name
        folder = "tables/trial" if name == "analysis.json" else "evidence/trial"
        destination = REPORT_ROOT / folder / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        assert digest(source) == digest(destination)
    # No simulation data, model, mesh, worker, or active campaign receipt is in SCOPES.
    for row in records:
        source = ROOT / row["source"]
        allowed = next(scope for scope in SCOPES if source.is_relative_to(scope))
        require_child(source, allowed)
        assert digest(source) == digest(ROOT / row["destination"]) == row["sha256"]
        source.unlink()
    for scope in SCOPES:
        if scope.exists():
            for directory in sorted((p for p in scope.rglob("*") if p.is_dir()), key=lambda p: len(p.parts), reverse=True):
                require_child(directory, scope)
                directory.rmdir()
            require_child(scope, ROOT)
            scope.rmdir()
    for row in source_records:
        source, target = ROOT / row["source"], ROOT / row["maintained_destination"]
        assert digest(source) == row["sha256"]
        source.replace(target)
    unique = {r["destination"]: r["bytes"] for r in records}
    result = dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), status="all_original_bytes_preserved_and_relocated",
        source_file_count=len(records), unique_asset_count=len(unique), duplicate_files_merged=len(records)-len(unique),
        original_bytes=sum(r["bytes"] for r in records), preserved_unique_bytes=sum(unique.values()),
        duplicate_bytes_reclaimed=sum(r["bytes"] for r in records)-sum(unique.values()),
        source_scopes=[p.relative_to(ROOT).as_posix() for p in SCOPES], files=records, source_entry_points=source_records,
        protected_scope="All trajectories, HDF5 reference data, models, meshes, active campaign inputs and worker files remain in place.",
        original_receipts="Archived receipts retain original path strings. Resolve them through files[].source to files[].destination; do not interpret them as current entry points.")
    write_json(receipt, result)
    archive_page(records)
    build_dashboard()
    write_json(REPORT_ROOT / "evidence/organization_summary.json", {k:v for k,v in result.items() if k not in ["files", "source_entry_points"]})
    print(json.dumps({k:v for k,v in result.items() if k not in ["files", "source_entry_points"]}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Apply the authorized migration after writing a source-hash plan.")
    args = parser.parse_args()
    if args.apply:
        migrate()
    else:
        rows = inventory()
        print(json.dumps(dict(files=len(rows), source_bytes=sum(r["bytes"] for r in rows),
            duplicate_files=sum(r["operation"] != "relocate" for r in rows), report_root=str(REPORT_ROOT)), indent=2))
