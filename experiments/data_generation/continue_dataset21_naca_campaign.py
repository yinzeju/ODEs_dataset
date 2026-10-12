"""Advance an authorized campaign after successful stages; stop on any failure.

Numerical repairs, reports, Git publication and final shutdown remain with the
thread heartbeat. This supervisor never kills a process or bypasses a gate.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

import psutil

ROOT = Path(__file__).resolve().parents[2]
CONTROL = ROOT / "runs/naca_campaign_control"
STATE = CONTROL / "state.json"
LOCK = CONTROL / "supervisor.lock"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path: Path, value: dict) -> None:
    temporary = path.with_suffix(path.suffix + ".supervisor.tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def same_process(pid: int, created: float) -> bool:
    try:
        return abs(psutil.Process(pid).create_time() - created) < 2
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        return False


def receipt_process_alive(receipt: dict) -> bool:
    created = dt.datetime.fromisoformat(receipt["process_started_utc"].replace("Z", "+00:00")).timestamp()
    return same_process(receipt["pid"], created)


def event(message: str, **values) -> None:
    row = dict(utc=dt.datetime.now(dt.timezone.utc).isoformat(), message=message, **values)
    with (CONTROL / "supervisor_events.jsonl").open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(row) + "\n")
    print(json.dumps(row), flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    initial = read_json(STATE)
    config_path = ROOT / initial["config"]
    cfg = read_json(config_path)
    if not cfg["execution_authorized"] or cfg["mesh"]["state_dimension_hard_max"] > 30000:
        raise RuntimeError("Execution authorization or hard state cap is missing")
    if args.check:
        print(json.dumps(dict(release=initial["release_id"], stage=initial["status"],
                              current_receipt=initial["current_receipt"], action="read-only check")))
        return 0
    if not args.execute:
        parser.error("--execute is required")
    if LOCK.exists():
        previous = read_json(LOCK)
        if same_process(previous["pid"], previous["creation_unix"]):
            raise RuntimeError("A campaign supervisor is already active")
        stale = CONTROL / ("supervisor_stale_" + str(time.time_ns()) + ".json")
        if LOCK.resolve().parent != CONTROL.resolve() or stale.resolve().parent != CONTROL.resolve():
            raise RuntimeError("Unexpected supervisor lock location")
        LOCK.replace(stale)
    identity = dict(pid=os.getpid(), creation_unix=psutil.Process().create_time(),
                    config=initial["config"], release_id=initial["release_id"])
    with LOCK.open("x", encoding="utf-8") as stream:
        json.dump(identity, stream)
    write_json(CONTROL / "supervisor.json", dict(identity, status="running"))
    event("Supervisor started", **identity)
    missing_since: dict[str, float] = {}
    try:
        while True:
            try:
                state = read_json(STATE)
            except (OSError, json.JSONDecodeError):
                time.sleep(2)
                continue
            if (state["config"], state["release_id"]) != (initial["config"], initial["release_id"]):
                event("Configuration superseded; leaving new campaign to its operator")
                return 0
            stage = state["status"]
            if stage not in {"qualify", "generate", "verify"}:
                event("Stage requires thread action; supervisor will not advance", stage=stage)
                return 0
            receipt_path = ROOT / state["current_receipt"]
            try:
                receipt = read_json(receipt_path)
            except (OSError, json.JSONDecodeError):
                first_missing = missing_since.setdefault(str(receipt_path), time.monotonic())
                if time.monotonic() - first_missing > 120:
                    raise RuntimeError("Stage launcher did not produce a readable receipt within 120 seconds")
                time.sleep(3)
                continue
            missing_since.pop(str(receipt_path), None)
            if receipt["status"] == "running":
                if receipt_process_alive(receipt):
                    time.sleep(15)
                    continue
                # Give the PowerShell launcher time to write its terminal receipt.
                time.sleep(3)
                receipt = read_json(receipt_path)
            if receipt.get("status") != "completed" or receipt.get("exit_code") != 0:
                state["status"] = "needs_repair"
                state["supervisor_error"] = "Stage failed or worker exited without a successful receipt"
                write_json(STATE, state)
                event("Stopped for autonomous thread diagnosis", receipt=state["current_receipt"])
                return 1
            completed = state.setdefault("completed_stages", [])
            label = stage + ":" + receipt_path.name
            if label not in completed:
                completed.append(label)
            state["last_successful_receipt"] = state["current_receipt"]
            if stage == "verify":
                state["status"] = "ready_for_wrapup"
                state["next_stage"] = "Write report and appendix, update project records, scoped commit/push, verify remote parity, then safe shutdown"
                write_json(STATE, state)
                event("Data verification completed; reports and publication remain pending")
                return 0
            if stage == "qualify":
                qualification = read_json(ROOT / "runs" / state["release_id"] / "qualification/qualified.json")
                if qualification["status"] != "qualified":
                    raise RuntimeError("Successful launcher lacks accepted qualification")
            next_stage = {"qualify": "generate", "generate": "verify"}[stage]
            attempt = "auto_" + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S")
            stem = next_stage + "_" + attempt
            state["status"] = next_stage
            state["current_receipt"] = "runs/naca_campaign_control/" + stem + ".json"
            state["current_log"] = "runs/naca_campaign_control/" + stem + ".log"
            write_json(STATE, state)
            command = [shutil.which("pwsh") or "pwsh", "-NoProfile", "-File",
                       str(ROOT / "experiments/data_generation/run_dataset21_naca_stage.ps1"),
                       "-Stage", next_stage, "-Config", state["config"], "-Attempt", attempt]
            with (CONTROL / (stem + ".launcher.log")).open("w", encoding="utf-8") as log:
                process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                           creationflags=subprocess.CREATE_NO_WINDOW)
            event("Advanced after successful gate", stage=next_stage, launcher_pid=process.pid,
                  receipt=state["current_receipt"])
            time.sleep(5)
    except Exception as error:
        state = read_json(STATE)
        state["status"] = "needs_repair"
        state["supervisor_error"] = str(error)
        write_json(STATE, state)
        event("Supervisor error; thread diagnosis required", error=str(error))
        raise
    finally:
        write_json(CONTROL / "supervisor.json", dict(identity, status="finished"))
        if LOCK.exists() and read_json(LOCK).get("pid") == os.getpid():
            LOCK.unlink()


if __name__ == "__main__":
    raise SystemExit(main())
