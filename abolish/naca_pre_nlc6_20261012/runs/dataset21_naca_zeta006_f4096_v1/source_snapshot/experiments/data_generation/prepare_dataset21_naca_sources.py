"""Verify or fetch only the pinned NACA source files; never run a solver."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true")
    args = parser.parse_args()
    manifest = json.loads((ROOT / "configs/references/naca_sources.json").read_text(encoding="utf-8"))
    cache = (ROOT / manifest["cache_root"]).resolve()
    if not cache.is_relative_to(ROOT / "data/cache"):
        raise ValueError("Source cache escapes project cache")
    for row in manifest["files"]:
        target = (cache / row["path"]).resolve()
        if not target.is_relative_to(cache):
            raise ValueError("Source path escapes cache")
        if not target.exists():
            if not args.download:
                raise FileNotFoundError(f"{target}; use --download to fetch sources")
            with urllib.request.urlopen(row["url"], timeout=60) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != row["sha256"]:
                raise ValueError(f"Downloaded source mismatch: {row['path']}")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        if hashlib.sha256(target.read_bytes()).hexdigest() != row["sha256"]:
            raise ValueError(f"Cached source mismatch: {target}")
    print(json.dumps({"status": "source_hashes_verified", "files": len(manifest["files"]),
                      "commit": manifest["commit"], "simulation_started": False}))


if __name__ == "__main__":
    main()
