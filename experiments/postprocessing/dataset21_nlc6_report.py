"""Shared report paths and an offline dashboard for existing NLC6 results."""
import csv
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = ROOT / "configs/visualizations/dataset21_nlc6_report.json"
CONFIG = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
REPORT_ROOT = ROOT / CONFIG["report_root"]


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def resolve_report_path(relative):
    """Resolve historical report namespaces while preserving original receipts."""
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError("Report path escapes project")
    if path.exists():
        return path
    catalog = read_json(ROOT / "configs/report_catalog.json")
    for row in catalog["relocations"]:
        old = ROOT / row["old_root"]
        if path == old or path.is_relative_to(old):
            return ROOT / row["new_root"] / path.relative_to(old)
    raise FileNotFoundError(relative)


def resolve_source(relative):
    """Resolve historical dataset references without rewriting frozen evidence."""
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError("Source path escapes project")
    if path.is_file():
        return path
    relocation = read_json(ROOT / "data/dataset_relocations.json")
    parent = relocation["retired_parent_links"].get(Path(relative).as_posix())
    if parent:
        return ROOT / parent["retained_path"]
    for row in relocation["moves"]:
        old = ROOT / row["old_root"]
        if path.is_relative_to(old):
            return ROOT / row["new_root"] / path.relative_to(old)
    raise FileNotFoundError(relative)


def section_path(report, section, kind, case=None):
    path = Path(report) / section / kind
    if case:
        path /= case
    path.mkdir(parents=True, exist_ok=True)
    return path


def build_dashboard(report=REPORT_ROOT):
    """Rebuild the summary using saved metrics; never integrate or rerender data."""
    report = Path(report).resolve()
    manifest = read_json(report / "evidence/selected/manifest.json")
    rows = manifest["trajectories"]
    trial_path = report / "tables/trial/analysis.json"
    trial = read_json(trial_path) if trial_path.exists() else None
    trial_ic_path = report / "evidence/trial/initial_condition.json"
    trial_ic = read_json(trial_ic_path) if trial_ic_path.exists() else {}
    records = [dict(id=r["id"], scope="population_selection", modes=str(r["modes"]),
        connector_energy_ratio=r["connector_energy_ratio"],
        maximum_translation_mm=r["maximum_translation_mm"],
        terminal_energy_fraction=r["terminal_energy_fraction"],
        max_strain=r["max_strain"], max_energy_balance_relative=r["max_energy_balance_relative"],
        displacement_relative_L2=r["translation_displacement_L2_difference_from_linear"],
        velocity_relative_L2=r["translation_velocity_L2_difference_from_linear"],
        source=resolve_source(r["source"]).relative_to(ROOT).as_posix(), source_sha256=r["source_sha256"]) for r in rows]
    if trial:
        records.append(dict(id=CONFIG["trial_id"], scope="separate_exploratory_trial",
            modes=str(trial_ic["modes"]), connector_energy_ratio=trial_ic["connector_energy_ratio"],
            maximum_translation_mm=trial["max_translation_mm"],
            terminal_energy_fraction=trial["terminal_energy_fraction"],
            max_strain=trial["max_strain_component"],
            max_energy_balance_relative=trial["max_energy_balance_relative"],
            displacement_relative_L2=trial["translation_displacement_L2_difference_from_linear"],
            velocity_relative_L2=trial["translation_velocity_L2_difference_from_linear"],
            source=f"runs/{CONFIG['trial_id']}/trajectory.h5", source_sha256=trial["source_sha256"]))
    tables = section_path(report, "tables", "")
    with (tables / "summary.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(records[0]))
        writer.writeheader()
        writer.writerows(records)
    esc = html.escape
    table = "".join(f'<tr><td><a href="#{esc(r["id"])}">{esc(r["id"])}</a></td>'
        f'<td>{esc(r["modes"])}</td><td>{r["connector_energy_ratio"]:.4f}</td>'
        f'<td>{r["maximum_translation_mm"]:.4f}</td><td>{100*r["terminal_energy_fraction"]:.2f}%</td>'
        f'<td>{r["max_strain"]:.3e}</td><td>{r["max_energy_balance_relative"]:.3e}</td></tr>' for r in records)
    sections = []
    for row in rows:
        case = row["id"]
        plots = f"../plots/selected/{case}"
        animation = f"../animations/selected/{case}"
        details = "".join(f'<details><summary>{title}</summary><img loading="lazy" src="{plots}/{name}.png" alt="{title}">'
            f'<p><a href="{plots}/{name}.pdf">Download PDF</a></p></details>' for name, title in [
                ("displacement_velocity", "Displacement and velocity histories"),
                ("ports_phase_spectrum", "Connectors, phase portrait, modal projections and spectrum"),
                ("energy_strain", "Energy, strain and numerical balance")])
        sections.append(f'<section id="{case}"><h2>{case}</h2>'
            f'<p>Original modes {row["modes"]}; initial amplitude {row["initial_amplitude_mm"]:.4f} mm. '
            f'<a href="selected/{case}/metrics.csv">Full-history CSV</a> · '
            f'<a href="selected/{case}/analysis.json">Metrics and provenance</a></p>'
            f'<img class="animation" src="{animation}/wing_vibration_6s_10x.gif" alt="{case}: displacement 10x, six-second playback">'
            f'<p><a href="{animation}/render_metadata.json">Frozen render receipt</a></p>{details}</section>')
    if trial:
        case = CONFIG["trial_id"]
        details = "".join(f'<details><summary>{title}</summary><img loading="lazy" src="../plots/trial/{name}.png" alt="{title}"></details>'
            for name, title in [("diagnostics", "Trial response and energy diagnostics"),
                ("ports_and_modes", "Trial ports, modal projections and spectrum"), ("connector_laws", "Visited spring and damper force ranges")])
        sections.append(f'<section id="{case}"><h2>Separate exploratory trial</h2><p>This trial is excluded from the 144 formal trajectories. '
            '<a href="trial/analysis.json">Complete trial metrics</a></p>'
            '<img class="animation" src="../animations/trial/wing_vibration_6s_10x.gif" alt="Trial: displacement 10x, six-second playback">'
            f'{details}</section>')
    css = """body{font:16px/1.65 system-ui,sans-serif;background:#f3f6fa;color:#192c42;max-width:1200px;margin:32px auto;padding:0 22px}h1,h2{line-height:1.25}section,.panel{background:#fff;border:1px solid #dbe3ed;border-radius:12px;padding:24px;margin:24px 0}a{color:#1b5d99}img{display:block;max-width:100%;height:auto;margin:12px auto}.animation{width:1000px}summary{cursor:pointer;background:#edf3f9;padding:12px;margin-top:10px}table{border-collapse:collapse;width:100%;font-size:14px}th,td{text-align:left;padding:10px;border-bottom:1px solid #dbe3ed;white-space:nowrap}.scroll{overflow:auto}.status{background:#e9f2fc;border-left:4px solid #3974ad;padding:16px}.muted{color:#536779}nav a{margin-right:14px}code{font-size:13px}footer{margin:30px 0} """
    trial_nav = f'<a href="#{CONFIG["trial_id"]}">Separate trial</a>' if trial else ""
    archive_nav = '<a href="../archive/index.html">Historical visualizations</a>' if (report/"archive/index.html").exists() else ""
    guide_nav = '<a href="../README.md">Report guide</a>' if (report/"README.md").exists() else ""
    evidence_links = "".join(f' · <a href="../{path}">{label}</a>' for path,label in [
        ("evidence/report_manifest.json", "Artifact and source manifest"), ("evidence/relocation.json", "Migration and deduplication record")]
        if (report/path).exists())
    scope_label = "four accepted population trajectories and one separate trial" if trial else "four accepted population trajectories"
    status_text = ("This page summarizes completed examples; it is not a live progress counter. "
        "Independent numerical qualification was waived; selected files passed runtime checks and full readback.")
    completion_path = report / "evidence/campaign_completion_04.json"
    if completion_path.exists():
        completion = read_json(completion_path)
        integrity = read_json(report / "evidence/campaign_integrity_04.json")
        if (completion["accepted"] != 144 or integrity["status"] != "passed"
                or completion["manifest_sha256"] != integrity["manifest_sha256"]):
            raise ValueError("Campaign completion evidence does not match its final audit")
        status_text = ("Formal population completed: 144/144 unique trajectories (96 Train / 24 Validation / 24 Test). "
            "All files passed runtime gates, complete saved-state readback and SHA256 verification. "
            "Qualification status: user_waived_independent_qualification. "
            '<a href="../Dataset21_NLC6_v1_nonlinear_wing.md">Chinese formal report</a> · '
            '<a href="../NLC6_numerical_appendix.md">Numerical appendix</a> · '
            '<a href="../evidence/campaign_integrity_04.json">Full-population integrity evidence</a>. '
            "The plots below remain illustrative selected examples.")
    page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dataset-2.1 NLC6 — visualization summary</title><style>{css}</style></head><body>
<h1>Dataset-2.1 NACA-NLC6</h1><p class="muted">Visualization summary · {scope_label}</p>
<p class="status">{status_text}</p>
<nav><a href="#summary">Metrics</a><a href="#overview">Overview</a>{trial_nav}{archive_nav}{guide_nav}</nav>
<div class="panel"><p>29,844 physical states · 4,096 saved frames · 0.5 ms sampling · 2.0475 s per full trajectory.</p><p>Current animations show the first 0.20 s with <strong>10x displacement and 6.00 s playback</strong>. Geometry remains at its actual scale, all axis units are equal, light-gray lines mark the physical exterior, and colors show actual normal displacement in mm. Histories and metrics use all 4,096 frames.</p><p>The same-initial-condition linear tangent reference is analytic. Relative response differences include phase accumulation and integration error; they are not a percentage of nonlinearity. The four examples are illustrative and do not characterize the whole population.</p></div>
<section id="summary"><h2>Completed-example metrics</h2><p><a href="summary.csv">Download summary CSV</a>{evidence_links}</p><div class="scroll"><table><thead><tr><th>Trajectory</th><th>Original modes</th><th>Initial ratio R</th><th>Peak translation (mm)</th><th>Final energy / E0</th><th>Maximum strain</th><th>Energy-balance error</th></tr></thead><tbody>{table}</tbody></table></div></section>
<section id="overview"><h2>Full-history comparison</h2><img src="../plots/selected/overview.png" alt="Four selected displacement, velocity and energy histories"><a href="../plots/selected/overview.pdf">Download overview PDF</a></section>
{''.join(sections)}<footer>All assets are local. Historical render receipts retain their original paths; the relocation record resolves them to their current locations.</footer></body></html>'''
    (tables / "index.html").write_text(page, encoding="utf-8")
    return records


if __name__ == "__main__":
    build_dashboard()
