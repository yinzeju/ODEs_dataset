"""Freeze and supervise the SKDM9 Beam truth extension, without modifying the active release."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

BASE = "add4a54bd864922b9c3c7cc3374ffe9ca6611d74bed638e54061fc1244938ba8"
FILES = ["src/data/skdm9_beam_extension.jl", "experiments/data_generation/generate_skdm9_beam.jl",
         "experiments/data_generation/skdm9_beam_campaign.py", "experiments/smoke_tests/skdm9_beam_extension.jl"]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(content, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(path)

def now():
    return datetime.now(timezone.utc).isoformat()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "supervise"])
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--julia", type=Path, required=True)
    parser.add_argument("--smoke-receipt", type=Path)
    args = parser.parse_args()
    root = args.project_root.resolve()
    run = root / "runs/skdm9_beam_h512_v1"
    frozen = run / "frozen_source"
    output = root / "data/extensions/skdm9_beam_h512_v1"
    manifest_path = run / "manifest.json"
    if args.mode == "prepare":
        if manifest_path.exists():
            raise RuntimeError("Existing formal source manifest is immutable")
        if not args.smoke_receipt:
            raise RuntimeError("A passed data smoke receipt is required")
        receipt = json.loads(args.smoke_receipt.read_text(encoding="utf-8"))
        if receipt["status"] != "passed" or not receipt["smoke_only"]:
            raise RuntimeError("Data smoke has not passed")
        for relative in FILES:
            destination = frozen / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / relative, destination)
        write(manifest_path, {"schema":"skdm9.beam_data_campaign.v1","created_utc":now(),
            "project_root":str(root),"output":str(output),"base_source_binding":BASE,
            "source_files":{f:sha(frozen/f) for f in FILES},"smoke_receipt":str(args.smoke_receipt.resolve()),
            "smoke_sha256":sha(args.smoke_receipt),"counts":{"train":96,"val":24,"test":24},
            "periods":32,"samples_per_period":256,"evaluates_test":False,
            "authorization":"User requested additional Beam FE12 truth trajectories using the original dataset code, smoke then automatic formal execution."})
        print(json.dumps({"status":"prepared","manifest":str(manifest_path),"sha256":sha(manifest_path)}))
        return
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for relative, expected in manifest["source_files"].items():
        if sha(frozen/relative) != expected:
            raise RuntimeError(f"Frozen source mismatch: {relative}")
    if sha(Path(manifest["smoke_receipt"])) != manifest["smoke_sha256"]:
        raise RuntimeError("Smoke evidence changed")
    lock = run / "owner.lock"
    with lock.open("x", encoding="utf-8") as stream:
        json.dump({"pid":os.getpid(),"created_utc":now(),"manifest_sha256":sha(manifest_path)},stream)
    env = os.environ.copy()
    env["JULIA_LOAD_PATH"] = "@;@stdlib"
    env["SKDM9_DATASET_PROJECT_ROOT"] = str(root)
    env["OPENBLAS_NUM_THREADS"] = "1"
    base = root / f"data/releases/testsub2_nv_20261004/TestSub2/audit_only/source_snapshots/{BASE}"
    command = [str(args.julia),"--startup-file=no",f"--project={base / 'configs/environments/testsub2_nv'}",
               str(frozen / "experiments/data_generation/generate_skdm9_beam.jl"),str(output)]
    try:
        with (run/"stdout.log").open("ab") as stdout, (run/"stderr.log").open("ab") as stderr:
            child = subprocess.Popen(command,cwd=root,env=env,stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr,
                                     creationflags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0)
            write(run/"process_receipts.json",{"supervisor_pid":os.getpid(),"julia_pid":child.pid,
                "created_utc":now(),"command":command,"executable":str(args.julia),"manifest_sha256":sha(manifest_path)})
            code = child.wait()
        if code:
            raise RuntimeError(f"Julia generator exited {code}; existing qualified trajectories are preserved")
        complete = json.loads((output/"complete.json").read_text(encoding="utf-8"))
        learner = json.loads((output/"learner_manifest.json").read_text(encoding="utf-8"))
        if complete["status"]!="passed" or complete["smoke_only"] or len(learner["trajectories"])!=144:
            raise RuntimeError("Generation is incomplete")
        for item in learner["trajectories"]:
            if sha(output/item["path"])!=item["sha256"]:
                raise RuntimeError("Generated trajectory hash mismatch")
        if sha(output/"learner_manifest.json")!=complete["manifest_sha256"]:
            raise RuntimeError("Learner manifest mismatch")
        write(run/"complete.json",{"status":"passed","julia_exit_code":code,"completed_utc":now(),
            "manifest_sha256":sha(manifest_path),"learner_manifest_sha256":complete["manifest_sha256"],
            "generation_complete_sha256":sha(output/"complete.json"),"trajectories_verified":144,
            "learning_or_test_evaluation":"not_executed_by_this_supervisor"})
    except BaseException as error:
        write(run/f"supervisor_failure_{datetime.now(timezone.utc):%Y%m%dT%H%M%S}.json",
              {"error":str(error),"failed_utc":now()})
        raise
    finally:
        lock.rename(run/f"owner_exited_{os.getpid()}.json")

if __name__ == "__main__":
    main()
