"""Observe campaign processes without starting, terminating or changing solvers."""
from __future__ import annotations

import datetime as dt
import ctypes
import json
from pathlib import Path
import shutil
import subprocess
import time

import psutil

ROOT = Path(__file__).resolve().parents[2]
CONTROL = ROOT / "runs/naca_campaign_control"


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {}


def main() -> None:
    peak = read_json(CONTROL / "resource_peaks.json")
    # Keep the authorized long experiment awake without changing the power plan
    # or keeping the display on. Windows releases this thread request on exit.
    power_request = ctypes.windll.kernel32.SetThreadExecutionState(0x80000001)
    peak["temporary_system_sleep_inhibition"] = bool(power_request)
    while True:
        state = read_json(CONTROL / "state.json")
        if state.get("status") in {"complete", "shutdown_scheduled"}:
            return
        receipt = read_json(ROOT / state.get("current_receipt", "missing"))
        record = {"utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                  "stage": state.get("status"), "pid": receipt.get("pid"),
                  "free_disk_bytes": shutil.disk_usage(ROOT).free,
                  "host_available_ram_bytes": psutil.virtual_memory().available}
        pid = receipt.get("pid")
        if pid:
            try:
                process = psutil.Process(pid)
                # Julia on this host rewrites its visible command line to the
                # executable alone. Bind the worker by PID AND creation time
                # from our launch receipt, never by PID alone.
                started = dt.datetime.fromisoformat(receipt["process_started_utc"].replace("Z", "+00:00")).timestamp()
                if process.name().lower() == "julia.exe" and abs(process.create_time() - started) < 2:
                    memory = process.memory_info()
                    record.update(worker_rss_bytes=memory.rss,
                                  worker_cpu_seconds=sum(process.cpu_times()[:2]),
                                  worker_creation_unix=process.create_time())
                    peak["worker_rss_bytes_sampled"] = max(peak.get("worker_rss_bytes_sampled", 0), memory.rss)
            except (psutil.NoSuchProcess, psutil.AccessDenied, KeyError, ValueError):
                record["worker_status"] = "not_accessible_or_finished"
        try:
            result = subprocess.run(["nvidia-smi", "--query-gpu=memory.used,utilization.gpu",
                                     "--format=csv,noheader,nounits"], capture_output=True,
                                    text=True, timeout=8, creationflags=subprocess.CREATE_NO_WINDOW)
            if result.returncode == 0:
                memory, utilization = map(int, result.stdout.strip().split(","))
                record.update(whole_gpu_memory_used_mib=memory, whole_gpu_utilization_percent=utilization)
                peak["whole_gpu_memory_used_mib_sampled"] = max(peak.get("whole_gpu_memory_used_mib_sampled", 0), memory)
        except (OSError, ValueError, subprocess.TimeoutExpired):
            record["gpu_query"] = "unavailable"
        peak["sampling_interval_seconds"] = 30
        peak["gpu_scope"] = "whole device, includes unrelated processes; not worker-attributed"
        (CONTROL / "resource_peaks.json").write_text(json.dumps(peak, indent=2)+"\n")
        with (CONTROL / "resource_samples.jsonl").open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(record)+"\n")
        time.sleep(30)


if __name__ == "__main__":
    main()
