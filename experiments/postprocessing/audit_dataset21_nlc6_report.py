"""Audit relocated visualization bytes, offline links, metrics and GIF settings."""
import datetime
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import unquote, urlsplit

from PIL import Image
import numpy as np
from dataset21_nlc6_report import ROOT, REPORT_ROOT, CONFIG, read_json, write_json, resolve_source, resolve_report_path


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.references = []
        self.ids = set()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.references.extend(attrs[k] for k in ("href", "src") if k in attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])


def audit(report=REPORT_ROOT):
    report = Path(report).resolve()
    if not (report / "evidence/report_manifest.json").exists():
        write_json(report / "evidence/report_manifest.json", {"status": "audit_in_progress"})
    relocation = read_json(report / "evidence/relocation.json")
    for record in relocation["files"]:
        path = resolve_report_path(record["destination"])
        assert path.is_relative_to(report) and path.is_file()
        assert sha256(path) == record["sha256"], path
        assert not (ROOT / record["source"]).exists(), record["source"]
    for record in relocation["source_entry_points"]:
        assert sha256(resolve_report_path(record["frozen_copy"])) == record["sha256"]
        assert (ROOT / record["maintained_destination"]).is_file()
    linked = 0
    for name in ["tables/index.html", "archive/index.html"]:
        page = report / name
        parser = Links()
        parser.feed(page.read_text(encoding="utf-8"))
        for ref in parser.references:
            parsed = urlsplit(ref)
            assert not parsed.scheme and not parsed.netloc, f"Expected offline link: {ref}"
            if not parsed.path:
                assert parsed.fragment in parser.ids, ref
            else:
                target = (page.parent / unquote(parsed.path)).resolve()
                assert target.is_relative_to(report) and target.is_file(), (page, ref)
            linked += 1
    animation_records = []
    for metadata_path in sorted((report / "animations").rglob("render_metadata.json")):
        data = read_json(metadata_path)
        path = metadata_path.parent / "wing_vibration_6s_10x.gif"
        with Image.open(path) as animation:
            durations = []
            for frame in range(animation.n_frames):
                animation.seek(frame)
                durations.append(animation.info.get("duration", 0))
        assert len(durations) == data["frames"] == 150
        assert sum(durations) == data["playback_duration_ms"] == 6000
        assert data["displacement_gain"] == 10 and data["equal_axis_units"] and data["closed_exterior"]
        assert data["all_exterior_faces_rendered"]
        assert min(data["all_frame_projected_clearance_px"]) >= data["minimum_required_clearance_px"] >= 16
        animation_records.append(dict(path=path.relative_to(report).as_posix(), sha256=sha256(path),
            frames=len(durations), playback_duration_ms=sum(durations), displacement_gain=10))
    assert len(animation_records) == 5
    selected = read_json(report / "evidence/selected/manifest.json")["trajectories"]
    assert [row["id"] for row in selected] == CONFIG["selected_ids"]
    for row in selected:
        folder = report / "tables/selected" / row["id"]
        metrics = np.genfromtxt(folder / "metrics.csv", delimiter=",", names=True)
        assert len(metrics) == 4096 and np.allclose(metrics["time_s"], np.arange(4096)*.0005, rtol=0, atol=1e-14)
        assert np.isclose(metrics["energy_J"][-1]/metrics["energy_J"][0], row["terminal_energy_fraction"])
        assert np.isclose(metrics["max_translation_m"].max()*1000, row["maximum_translation_mm"])
        assert np.isclose(metrics["strain_max"].max(), row["max_strain"])
        assert np.isclose(metrics["energy_balance_relative"].max(), row["max_energy_balance_relative"])
        assert read_json(folder / "analysis.json") == row
        source = resolve_source(row["source"])
        assert source.is_file() and read_json(source.with_name("readback.json"))["sha256"] == row["source_sha256"]
        assert sha256(source) == row["source_sha256"]
    trial = read_json(report / "tables/trial/analysis.json")
    assert sha256(ROOT / "runs/dataset21_nlc6_trial_01/trajectory.h5") == trial["source_sha256"]
    artifacts = [dict(path=p.relative_to(report).as_posix(), bytes=p.stat().st_size, sha256=sha256(p))
        for p in sorted(report.rglob("*")) if p.is_file() and p.name not in ["report_manifest.json", "audit.json"]]
    completion_path = report / "evidence/campaign_completion_04.json"
    completed = read_json(completion_path) if completion_path.exists() else None
    if completed:
        integrity = read_json(report / "evidence/campaign_integrity_04.json")
        assert completed["accepted"] == integrity["accepted"] == 144 and integrity["status"] == "passed"
        assert completed["manifest_sha256"] == integrity["manifest_sha256"]
    manifest = dict(report_identity=CONFIG["report_identity"], dashboard="tables/index.html",
        qualification_status=CONFIG["qualification_status"], population_completion_claim=bool(completed),
        population_completion_evidence="evidence/campaign_completion_04.json" if completed else None,
        selected_sources=[{k:row[k] for k in ["id", "source", "source_sha256"]} for row in selected],
        separate_trial_source="runs/dataset21_nlc6_trial_01/trajectory.h5", artifacts=artifacts)
    write_json(report / "evidence/report_manifest.json", manifest)
    result = dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), status="passed",
        preserved_source_records=len(relocation["files"]), unique_relocated_assets=relocation["unique_asset_count"],
        duplicate_files_merged=relocation["duplicate_files_merged"], duplicate_bytes_reclaimed=relocation["duplicate_bytes_reclaimed"],
        offline_links_checked=linked, current_animations=animation_records, full_history_metric_rows_checked=4*4096,
        artifact_count=len(artifacts), artifact_bytes=sum(a["bytes"] for a in artifacts),
        source_trajectory_hashes_verified=5, simulation_executed=False, independent_qualification_executed=False)
    write_json(report / "evidence/audit.json", result)
    print(json.dumps(result, indent=2))
    return result


if __name__ == "__main__":
    audit()
