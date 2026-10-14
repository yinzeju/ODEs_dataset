"""Read-only inventory and integrity audit of the canonical Dataset catalog."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def file_hash(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def audit(catalog_path: Path, *, verify_data: bool = False) -> dict:
    catalog = read_json(catalog_path)
    aliases = set()
    rows = []
    for entry in catalog["resources"]:
        for alias in [entry["dataset_code"], *entry["aliases"]]:
            if alias in aliases:
                raise ValueError(f"Repeated dataset alias: {alias}")
            aliases.add(alias)
        folder = (ROOT / entry["artifact_root"]).resolve()
        manifest_path = (ROOT / entry["manifest"]).resolve()
        if not folder.is_relative_to(ROOT) or not manifest_path.is_relative_to(folder):
            raise ValueError("Dataset path escapes the project or artifact root")
        if file_hash(manifest_path) != entry["manifest_sha256"]:
            raise ValueError(f"Frozen manifest changed: {entry['dataset_code']}")
        manifest = read_json(manifest_path)
        checked = 0
        if verify_data:
            if entry["manifest_kind"] == "standard_odes":
                references = [item for row in manifest["objects"] for item in [row, *row["noise_views"]]]
            elif entry["manifest_kind"] == "dataset2_release":
                index_path = folder / manifest["artifact_manifest"]
                if file_hash(index_path) != manifest["artifact_manifest_sha256"]:
                    raise ValueError("Dataset2 artifact catalog changed")
                references = [{"path": path, "sha256": digest}
                              for path, digest in read_json(index_path)["files"].items()]
            elif entry["manifest_kind"] == "dataset21_nlc6_release":
                references = [{"path": row["relative_path"], "sha256": row["sha256"]}
                              for row in manifest["trajectories"]]
            else:
                references = manifest["trajectories"]
            for row in references:
                path = (folder / row["path"]).resolve()
                if not path.is_relative_to(folder) or file_hash(path) != row["sha256"]:
                    raise ValueError(f"Artifact checksum mismatch: {row['path']}")
                checked += 1
        files = [path for path in folder.rglob("*") if path.is_file()]
        rows.append({"dataset_code": entry["dataset_code"], "files": len(files),
                     "bytes": sum(path.stat().st_size for path in files),
                     "manifest_passed": True, "artifact_hashes_checked": checked})
    return {"status": "passed", "data_hashes_verified": verify_data, "resources": rows,
            "total_files": sum(row["files"] for row in rows),
            "total_bytes": sum(row["bytes"] for row in rows)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-data", action="store_true", help="Verify all indexed numerical/artifact hashes")
    args = parser.parse_args()
    print(json.dumps(audit(ROOT / "configs/dataset_catalog.json", verify_data=args.verify_data), indent=2))


if __name__ == "__main__":
    main()
