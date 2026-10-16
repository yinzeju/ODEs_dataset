"""Read-only validation of active data-report navigation and preserved archives."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def audit():
    catalog = load(ROOT / "configs/report_catalog.json")
    assert set(catalog["active"]) == {"Dataset-2", "Dataset-2.1"}
    assert {p.name for p in (ROOT / "reports").iterdir() if p.is_dir()} == {"Dataset-2", "Dataset-2.1"}
    links = 0
    documents = [ROOT / "reports/README.md"]
    for row in catalog["active"].values():
        main, appendix = ROOT / row["main_report"], ROOT / row["numerical_appendix"]
        assert main.is_file() and appendix.is_file() and main.parent == appendix.parent
        documents.extend(sorted((ROOT / row["root"]).glob("*.md")))
    for document in documents:
        for target in re.findall(r"\]\(([^)]+)\)", document.read_text(encoding="utf-8-sig")):
            target = target.strip("<>")
            if re.match(r"^[A-Za-z]:[/\\]", target):
                assert Path(unquote(target)).is_file(), (document, target)
                links += 1
                continue
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            destination = (document.parent / unquote(parsed.path)).resolve()
            assert destination.is_relative_to(ROOT) and destination.is_file(), (document, target)
            links += 1
    archive = load(ROOT / catalog["archive"] / "manifest.json")
    for row in archive["files"]:
        old, new = ROOT / row["source"], ROOT / row["destination"]
        assert not old.exists() and new.is_file() and sha(new) == row["sha256"], new
    for dataset, pointer_name in [("Dataset-2", "dataset2_active.json"), ("Dataset-2.1", "dataset21_active.json")]:
        pointer = load(ROOT / "data" / pointer_name)
        assert pointer["formal_report"] == catalog["active"][dataset]["main_report"]
        assert pointer["numerical_appendix"] == catalog["active"][dataset]["numerical_appendix"]
    for row in load(ROOT / "configs/dataset_catalog.json")["resources"]:
        assert sha(ROOT / row["manifest"]) == row["manifest_sha256"]
    evidence = load(ROOT / "reports/Dataset-2/evidence/data_report.json")
    assert evidence["current_trajectory_count"] == 288
    for row in evidence["configurations"]:
        assert row["trajectory_count"] == 144 and row["split_counts"] == {"train": 96, "val": 24, "test": 24}
        assert sha(ROOT / row["learner_manifest"]) == row["learner_manifest_sha256"]
    assert Path(evidence["source_protocol_note"]).is_file()
    assert sha(ROOT / evidence["frozen_protocol_snapshot"]) == evidence["source_protocol_note_sha256"]
    return {"status": "passed", "active_report_groups": 2, "markdown_links_checked": links,
            "archived_files_sha_verified": len(archive["files"]), "dataset_manifests_verified": 3,
            "current_beam_trajectories": 288, "simulation_executed": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output")
    args = parser.parse_args()
    result = audit()
    if args.output:
        output = (ROOT / args.output).resolve()
        assert output.is_relative_to(ROOT) and not output.exists()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
