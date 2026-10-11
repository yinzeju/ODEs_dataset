"""Freeze and supervise the authorized SKDM9.6 full physical-data generation."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
import psutil


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False)


def now():
    return datetime.now(timezone.utc).isoformat()


def main():
    root = Path(__file__).resolve().parents[2]
    julia = Path(sys.argv[1]).resolve()
    run = root / "runs/skdm96/formal_data_v1"
    output = root / "data/extensions/skdm96_beam_transient_h2048_v1"
    design = root / "runs/skdm96/design_v2"
    completed = json.loads((design / "complete.json").read_text())
    assert completed["status"] == "passed_numerics_and_transient_design" and completed["design_only"]
    assert completed["trajectories"] == 2
    assert not run.exists() and not output.exists(), "Preserve prior attempts; never relaunch"
    run.mkdir(parents=True)
    sources = ["src/data/skdm96_beam_extension.jl", "src/data/skdm9_beam_extension.jl",
               "experiments/data_generation/generate_skdm96_beam.jl",
               "experiments/data_generation/skdm96_beam_campaign.py"]
    hashes = {}
    for rel in sources:
        dst = run / "frozen_source" / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / rel, dst)
        hashes[rel] = sha(dst)
    base = root / "data/releases/testsub2_nv_20261004/TestSub2/audit_only/source_snapshots/add4a54bd864922b9c3c7cc3374ffe9ca6611d74bed638e54061fc1244938ba8"
    manifest = dict(schema="skdm96.data_campaign.v1", created_utc=now(), sources=hashes,
                    base_capsule_manifest_sha256=sha(base / "snapshot_manifest.json"),
                    design_complete_sha256=sha(design / "complete.json"),
                    generation_config_sha256=sha(design / "generation_config.json"),
                    counts=dict(train=96, val=24, test=24), frames=4097, state_dimension=66,
                    output=str(output), authorization="User authorized new SKDM9.6 data and formal experiment; early fast modes, rear-half slow decay confirmed.")
    write(run / "manifest.json", manifest)
    command = [str(julia), "--startup-file=no", f"--project={base / 'configs/environments/testsub2_nv'}",
               str(run / "frozen_source/experiments/data_generation/generate_skdm96_beam.jl"), "formal", str(output)]
    env = os.environ.copy()
    env.update(JULIA_LOAD_PATH="@;@stdlib", SKDM9_DATASET_PROJECT_ROOT=str(root), OPENBLAS_NUM_THREADS="1")
    parent = psutil.Process()
    write(run / "supervisor_process.json", dict(pid=parent.pid, epoch=parent.create_time(),
          exe=parent.exe(), argv=parent.cmdline(), created_utc=now()))
    with (run / "stdout.log").open("xb") as stdout, (run / "stderr.log").open("xb") as stderr:
        child = subprocess.Popen(command, cwd=root, env=env, stdin=subprocess.DEVNULL,
                                 stdout=stdout, stderr=stderr,
                                 creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        proc = psutil.Process(child.pid)
        epoch = proc.create_time()
        write(run / "process.json", dict(pid=child.pid, epoch=epoch, exe=proc.exe(), command=command,
              manifest_sha256=sha(run / "manifest.json"), created_utc=now()))
        print(json.dumps(dict(status="launched", run=str(run), pid=child.pid, epoch=epoch)), flush=True)
        code = child.wait()
    exact_gone = not psutil.pid_exists(child.pid) or abs(psutil.Process(child.pid).create_time() - epoch) > .01
    write(run / "child_exit.json", dict(exit_code=code, exact_process_gone=exact_gone, completed_utc=now()))
    if code != 0 or not exact_gone:
        raise RuntimeError("Generator failed; preserve sources, logs and partial output")
    result = json.loads((output / "complete.json").read_text())
    learner = json.loads((output / "learner_manifest.json").read_text())
    assert result["status"] == "passed_numerics_and_transient_design" and not result["design_only"]
    assert learner["snapshot_count"] == 4097 and learner["state_dimension"] == 66
    assert len(learner["trajectories"]) == 144 and sha(output / "learner_manifest.json") == result["manifest_sha256"]
    for row in learner["trajectories"]:
        assert sha(output / row["path"]) == row["sha256"]
    for rel, digest in hashes.items():
        assert sha(run / "frozen_source" / rel) == digest
    assert all(row["passed_transient_design"] for row in json.loads((output / "transient_checks.json").read_text()))
    write(run / "completion.json", dict(status="passed144_qualified_truth_trajectories_and_exact_child_exit",
          child_exit_code=code, learner_manifest_sha256=result["manifest_sha256"], completed_utc=now(),
          model_training=False, model_Test=False))
    print("SKDM96_GENERATION_VERIFIED", flush=True)


if __name__ == "__main__":
    main()
