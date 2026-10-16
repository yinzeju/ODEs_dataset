"""Read-only final NLC6 release audit; never integrate or change a trajectory."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import time

import h5py
import numpy as np
import psutil
from scipy.sparse import csc_matrix

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def distribution(values):
    values = np.asarray(values, dtype=float)
    return {"minimum": float(values.min()), "median": float(np.median(values)),
            "maximum": float(values.max()), "sum": float(values.sum())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    parser.add_argument("--worker-receipt", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    started = time.perf_counter()
    output = ROOT / args.output
    require(not output.exists(), "Preserve the previous audit; choose a new output path")
    cfg = load(ROOT / args.config)
    release_id = cfg["release_id"]
    run = ROOT / "runs" / release_id
    active = load(ROOT / "data/dataset21_active.json")
    data = (ROOT / active["manifest"]).parent if active["release_id"] == release_id else ROOT / "data/releases" / release_id
    status = load(run / "campaign_status.json")
    worker = load(ROOT / args.worker_receipt)
    require(status["status"] == "complete" and status["completed"] == 144
            and status["full_readback_passed"] is True, "Campaign is not complete")
    require(worker["status"] == "completed" and worker["exit_code"] == 0,
            "Worker has not exited successfully")
    try:
        process = psutil.Process(worker["pid"])
        expected_start = datetime.fromisoformat(worker["process_started_utc"].replace("Z", "+00:00"))
        require(abs(process.create_time() - expected_start.timestamp()) >= 2,
                "The original worker is still alive")
    except psutil.NoSuchProcess:
        pass
    require(Path(worker["stderr"]).stat().st_size == 0, "Nonempty worker stderr")
    require(not (run / "execution.lock").exists(), "Active execution lock remains")
    require(not (run / "quarantined.json").exists() or not load(run / "quarantined.json"),
            "Quarantined cases cannot be accepted")
    manifest = load(data / "release_manifest.json")
    manifest_sha = sha(data / "release_manifest.json")
    require(status["manifest_sha256"] == manifest_sha, "Final manifest binding")
    require(manifest["status"] == "complete_user_waived_independent_qualification",
            "Final release status")
    require(cfg["qualification_status"] == manifest["qualification_status"]
            == "user_waived_independent_qualification", "Qualification boundary")
    fingerprint = load(run / "input_fingerprint.json")
    require(fingerprint == manifest["source_fingerprint"], "Source capsule binding")
    for relative, expected_hash in fingerprint.items():
        require(sha(ROOT / relative) == expected_hash, f"Current input changed: {relative}")
        require(sha(run / "source_snapshot" / relative) == expected_hash,
                f"Frozen input changed: {relative}")
    require(sha(ROOT / cfg["base_model_path"]) == cfg["base_model_sha256"], "Base model SHA")
    require(sha(data / "model.jld2") == manifest["model_sha256"], "Release model SHA")
    plan = load(run / "population_plan.json")
    rows = load(run / "completed.json")
    require(plan == load(data / "population_plan.json"), "Plan copy differs")
    require(rows == manifest["trajectories"], "Completed/manifest rows differ")
    require(len(rows) == len(plan) == 144, "Population count")
    require([row["id"] for row in rows] == [row["id"] for row in plan], "Ordered IDs")
    require(len({row["id"] for row in rows}) == 144, "Duplicate IDs")
    require(len({row["initial_state_sha256"] for row in rows}) == 144, "Duplicate initial states")
    require(dict(Counter(row["split"] for row in rows)) == {"train": 96, "validation": 24, "test": 24},
            "Split contract")
    require(dict(Counter(row["family"] for row in rows)) == {i: 12 for i in range(1, 13)},
            "Family contract")
    expected_files = {str((data / row["relative_path"]).resolve()) for row in rows}
    require({str(path.resolve()) for path in data.rglob("trajectory.h5")} == expected_files,
            "Unexpected or missing trajectory files")
    require(not list(data.rglob("*.partial.h5")), "Partial file inside final release")
    with h5py.File(data / "model.jld2", "r") as model:
        ports = model["connectors"][()]
        sparse = ports["B"]
        B = csc_matrix((model[sparse["nzval"]][()], model[sparse["rowval"]][()] - 1,
                        model[sparse["colptr"]][()] - 1), shape=(int(sparse["m"]), int(sparse["n"])))
        kappa = model[ports["kappa"]][()]
    require(B.shape == (14922, 6), "Port matrix shape")
    audited = []
    for ordinal, row in enumerate(rows, 1):
        path = data / row["relative_path"]
        receipt = load(Path(str(path) + ".json"))
        initial = load(path.parent / "initial_condition.json")
        readback = load(path.parent / "readback.json")
        require(readback["status"] == "passed" and readback["frames"] == 4096, row["id"])
        require(readback["sha256"] == receipt["sha256"] == row["sha256"] == sha(path),
                f"Trajectory SHA: {row['id']}")
        require(receipt["physics_checks_passed"] is True, row["id"])
        require(receipt["frames"] == 4096 and receipt["state_dimension"] == 29844
                and receipt["dt_seconds"] == 0.0005, row["id"])
        solver = dict(cfg["trial"]["solver"])
        solver.update(cfg.get("case_solver_overrides", {}).get(row["id"], {}))
        require(solver == row["solver"] == receipt["solver"], f"Solver binding: {row['id']}")
        require(receipt["max_newton_scaled_residual"] <= 1e-13, row["id"])
        require(receipt["max_recovered_strain_component"] <= 0.001, row["id"])
        require(receipt["max_energy_balance_relative"] <= 1e-4, row["id"])
        require(receipt["final_energy_ratio"] <= 0.4, row["id"])
        require(initial["initial_state_sha256"] == row["initial_state_sha256"], row["id"])
        bound_hash = cfg.get("case_initial_state_sha256", {}).get(row["id"])
        require(bound_hash is None or bound_hash == row["initial_state_sha256"], row["id"])
        require(abs(initial["actual_connector_energy_ratio"] / row["connector_energy_ratio"] - 1) < 1e-7,
                f"Initial ratio: {row['id']}")
        for stage in initial.get("static_trace", []):
            require(stage["force_residual"] <= stage["force_tolerance"]
                    and stage["correction_relative"] <= 1e-9
                    and stage["ratio_relative_error"] <= 1e-8, f"Static gates: {row['id']}")
        with h5py.File(path, "r") as f:
            require(f["x"].shape == (4096, 29844) and f["x"].dtype == np.dtype("float64"), row["id"])
            require(np.max(np.abs(f["t"][()] - np.arange(4096) * 0.0005)) < 1e-12, row["id"])
            x0 = f["x"][0]
            require(np.array_equal(x0[14922:], np.zeros(14922)), f"Initial velocity: {row['id']}")
            require(hashlib.sha256(x0[:14922].astype("<f8").tobytes()).hexdigest()
                    == row["initial_state_sha256"], f"Exact initial state: {row['id']}")
            E, D, D0, Dn = (f[key][()] for key in ("energy", "dissipated", "dissipated_linear", "dissipated_connector"))
            strain = f["strain_max"][()]
            require(all(np.all(np.isfinite(a)) for a in (E, D, D0, Dn, strain)), row["id"])
            require(E.min() > 0 and np.diff(D0).min() >= -1e-12 and np.diff(Dn).min() >= -1e-12, row["id"])
            require(np.max(np.abs(D-D0-Dn)) < 1e-12 * max(E[0], 1), row["id"])
            balance = float(np.max(np.abs(E + D - E[0])) / E[0])
            require(abs(balance-receipt["max_energy_balance_relative"]) <= 1e-12, row["id"])
            require(abs(E[-1]/E[0]-receipt["final_energy_ratio"]) <= 1e-12, row["id"])
            require(abs(strain.max()-receipt["max_recovered_strain_component"]) <= 1e-12, row["id"])
            max_s_error = max_w_error = max_potential_error = 0.0
            for first in range(0, 4096, 128):
                last = min(first+128, 4096)
                x = f["x"][first:last]
                require(np.all(np.isfinite(x)), f"Saved state finiteness: {row['id']}")
                s, w = (B.T @ x[:, :14922].T).T, (B.T @ x[:, 14922:].T).T
                max_s_error = max(max_s_error, float(np.max(np.abs(s-f["connector_displacement"][first:last]))))
                max_w_error = max(max_w_error, float(np.max(np.abs(w-f["connector_velocity"][first:last]))))
                potential = np.sum(kappa * s**4, axis=1)/4
                max_potential_error = max(max_potential_error, float(np.max(np.abs(potential-f["connector_potential"][first:last]))))
            require(max_s_error < 1e-12 and max_w_error < 1e-12
                    and max_potential_error < 1e-11 * max(E[0], 1), f"All-frame port identities: {row['id']}")
        origin = row.get("reused_from")
        if origin:
            parent = ROOT / "data/releases" / origin["release"] / origin["relative_path"]
            require(origin["sha256"] == row["sha256"], f"Parent SHA binding: {row['id']}")
            if parent.exists():
                require(path.samefile(parent), f"Immutable parent hardlink: {row['id']}")
            else:
                relocation = load(ROOT / "data/dataset_relocations.json")
                evidence = relocation["retired_parent_links"].get(parent.relative_to(ROOT).as_posix())
                require(evidence is not None and evidence["sha256"] == row["sha256"]
                        and ROOT / evidence["retained_path"] == path
                        and evidence["parent_identity"] == evidence["retained_identity"],
                        f"Verified historical hardlink retirement: {row['id']}")
        audited.append({**row, "ordinal": ordinal, "initial_condition": initial,
                        "runtime": receipt, "file_bytes": path.stat().st_size,
                        "full_state_readback_passed": True,
                        "max_saved_port_displacement_error": max_s_error,
                        "max_saved_port_velocity_error": max_w_error,
                        "max_saved_port_potential_error": max_potential_error})
        if ordinal % 12 == 0:
            print(json.dumps({"audited": ordinal, "total": 144}), flush=True)
    metric_keys = ("max_energy_balance_relative", "max_strain", "final_energy_ratio", "wall_seconds")
    metrics = {key: distribution([row[key] for row in audited]) for key in metric_keys}
    metrics["max_newton_scaled_residual"] = distribution([row["runtime"]["max_newton_scaled_residual"] for row in audited])
    summary = {
        "schema": "dataset21.nlc6.final_integrity.v1", "status": "passed",
        "release_id": release_id, "utc": datetime.now(timezone.utc).isoformat(),
        "qualification_status": cfg["qualification_status"],
        "scope": "All144 files: exact initial state, full saved-state and port readback, runtime receipt gates, file SHA256, final manifest and immutable lineage. No integration or independent accuracy qualification.",
        "manifest_sha256": manifest_sha, "model_sha256": manifest["model_sha256"],
        "population_plan_sha256": sha(run / "population_plan.json"),
        "frozen_inputs": fingerprint, "worker_receipt": args.worker_receipt,
        "accepted": 144, "reused": sum("reused_from" in row for row in rows),
        "new_in_active_release": sum("reused_from" not in row for row in rows),
        "counts": dict(Counter(row["split"] for row in rows)),
        "family_counts": dict(Counter(row["family"] for row in rows)),
        "unique_initial_states": 144, "frames": 4096, "state_dimension": 29844,
        "dt_seconds": 0.0005, "duration_seconds": 2.0475,
        "trajectory_file_bytes": sum(row["file_bytes"] for row in audited),
        "logical_state_array_bytes": 144 * 4096 * 29844 * 8,
        "runtime_metrics": metrics,
        "audit_wall_seconds": time.perf_counter()-started,
        "trajectories": audited,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({key: summary[key] for key in ("status", "accepted", "reused", "new_in_active_release", "manifest_sha256", "runtime_metrics", "audit_wall_seconds")}), flush=True)


if __name__ == "__main__":
    main()
