"""Render accepted population files on CPU without touching campaign inputs."""
import os
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("OMP_NUM_THREADS", "1")
import argparse
import hashlib
import json
from pathlib import Path
import h5py
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import psutil
from render_dataset21_nlc6_preview import ROOT, render_preview
from dataset21_nlc6_report import CONFIG, REPORT_ROOT, build_dashboard, section_path


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2)+"\n", encoding="utf-8")


def save_figure(fig, out, name):
    fig.savefig(out/f"{name}.png", dpi=150)
    fig.savefig(out/f"{name}.pdf")
    plt.close(fig)


def analyze(source, row, cfg, reference, report):
    out = section_path(report, "plots", "selected", row["id"])
    tables = section_path(report, "tables", "selected", row["id"])
    animation = section_path(report, "animations", "selected", row["id"])
    receipt = read_json(source.with_name(source.name+".json"))
    back = read_json(source.with_name("readback.json"))
    ic = read_json(source.with_name("initial_condition.json"))
    assert receipt["physics_checks_passed"] and back["status"] == "passed"
    with source.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    assert digest == row["sha256"] == receipt["sha256"] == back["sha256"]
    xyz, active, phi, mass_phi, omega = reference
    nq = len(active)
    translation = np.flatnonzero(active % 6 < 3)
    nodes, components = active[translation]//6, active[translation] % 6
    modes = np.asarray(ic["modes"], dtype=int)-1
    coefficients = np.asarray(ic["modal_coefficients"])
    alpha = (cfg["linear_damping"]["aM_per_s"] + cfg["linear_damping"]["aK_s"]*omega[modes]**2)/2
    wd = np.sqrt(omega[modes]**2-alpha**2)
    with h5py.File(source, "r") as f:
        assert f["x"].shape == (4096, 2*nq)
        data = {k: f[k][:] for k in ["t", "energy", "dissipated", "dissipated_linear",
            "dissipated_connector", "connector_potential", "strain_max", "connector_displacement", "connector_velocity"]}
        t, E = data["t"], data["energy"]
        assert np.allclose(t, np.arange(4096)*.0005, atol=1e-14, rtol=0)
        q0 = f["x"][0, :nq]
        assert hashlib.sha256(q0.tobytes()).hexdigest() == ic["initial_state_sha256"]
        assert np.allclose(q0, phi[:, modes]@coefficients, atol=1e-13, rtol=1e-12)
        initial = np.zeros((len(xyz), 3)); initial[nodes, components] = q0[translation]
        tips = np.flatnonzero(np.isclose(xyz[:, 2], xyz[:, 2].max()))
        tip = int(tips[np.argmax(np.linalg.norm(initial[tips], axis=1))])
        tip_cols = np.array([np.flatnonzero(active == 6*tip+j).item() for j in range(3)])
        decay = np.exp(-t[:, None]*alpha); phase = t[:, None]*wd
        eta_ref = coefficients*decay*(np.cos(phase)+alpha/wd*np.sin(phase))
        velocity_ref = -coefficients*decay*(wd+alpha**2/wd)*np.sin(phase)
        tip_q_ref, tip_v_ref = eta_ref@phi[tip_cols][:, modes].T, velocity_ref@phi[tip_cols][:, modes].T
        tip_q, tip_v = np.empty((len(t), 3)), np.empty((len(t), 3))
        max_u, rms_u, modal_energy = np.empty(len(t)), np.empty(len(t)), np.empty((len(t), 4))
        errors = np.zeros(4)
        for first in range(0, len(t), 32):
            stop = min(first+32, len(t)); x = f["x"][first:stop, :]
            assert np.isfinite(x).all()
            q, v = x[:, :nq], x[:, nq:]
            tip_q[first:stop], tip_v[first:stop] = q[:, tip_cols], v[:, tip_cols]
            u = np.zeros((stop-first, len(xyz), 3)); u[:, nodes, components] = q[:, translation]
            lengths = np.linalg.norm(u, axis=2)
            max_u[first:stop], rms_u[first:stop] = lengths.max(axis=1), np.sqrt(np.mean(lengths**2, axis=1))
            eta, vel = q@mass_phi[:, :4], v@mass_phi[:, :4]
            modal_energy[first:stop] = .5*(vel**2+eta**2*omega[:4]**2)
            qr = eta_ref[first:stop]@phi[translation][:, modes].T
            vr = velocity_ref[first:stop]@phi[translation][:, modes].T
            errors += [np.sum((q[:, translation]-qr)**2), np.sum(qr**2),
                np.sum((v[:, translation]-vr)**2), np.sum(vr**2)]
    balance = abs(E+data["dissipated"]-E[0])/E[0]
    assert np.isclose(balance.max(), receipt["max_energy_balance_relative"], atol=1e-12)
    assert np.isclose(E[-1]/E[0], receipt["final_energy_ratio"])
    assert balance.max()<=1e-4 and data["strain_max"].max()<=.001
    blue, orange, green = "#2166ac", "#d86b27", "#188c78"
    fig, ax = plt.subplots(2, 3, figsize=(15, 8), layout="constrained")
    for j, name in enumerate(["Chord x", "Normal y", "Span z"]):
        ax[0, j].plot(t, tip_q[:, j]*1000, color=blue, lw=.85, label="Full nonlinear FE")
        ax[0, j].plot(t, tip_q_ref[:, j]*1000, color=orange, lw=.65, alpha=.75, label="Same-IC linear tangent")
        ax[1, j].plot(t, tip_v[:, j], color=blue, lw=.8)
        ax[1, j].plot(t, tip_v_ref[:, j], color=orange, lw=.65, alpha=.75)
        ax[0, j].set(title=f"Tip {name} displacement", xlabel="Time (s)", ylabel="Displacement (mm)")
        ax[1, j].set(title=f"Tip {name} velocity", xlabel="Time (s)", ylabel="Velocity (m/s)")
    ax[0, 0].legend(fontsize=8)
    fig.suptitle(f"{row['id']} | original modes {ic['modes']} | R = {ic['connector_energy_ratio']:.3f}\nFull 4096-frame histories; selected free-tip node {tip+1}", fontsize=14)
    save_figure(fig, out, "displacement_velocity")
    fig, ax = plt.subplots(2, 3, figsize=(15, 8), layout="constrained")
    s, w = data["connector_displacement"], data["connector_velocity"]
    for j in range(6):
        ax[0, 0].plot(t, s[:, j]*1000, lw=.7, label=f"Port {j+1}")
        ax[0, 1].plot(t, w[:, j], lw=.7, label=f"Port {j+1}")
    ax[0, 0].set(title="Six connector extensions", xlabel="Time (s)", ylabel="Extension (mm)"); ax[0, 0].legend(ncol=3, fontsize=7)
    ax[0, 1].set(title="Six connector velocities", xlabel="Time (s)", ylabel="Velocity (m/s)")
    ax[0, 2].plot(s[:, 1]*1000, w[:, 1], lw=.7, color=blue)
    ax[0, 2].set(title="Outer bending port phase portrait", xlabel="Extension (mm)", ylabel="Velocity (m/s)")
    for j in range(4):
        ax[1, 0].plot(t, modal_energy[:, j]/E[0], lw=.8, label=f"Mode {j+1}")
    ax[1, 0].set(title="Original modal projections (diagnostic)", xlabel="Time (s)", ylabel="Linear modal energy / E0"); ax[1, 0].legend(fontsize=8)
    freq = np.fft.rfftfreq(len(t), .0005)
    power = abs(np.fft.rfft((w-w.mean(axis=0))*np.hanning(len(t))[:, None], axis=0))**2
    pooled = power.sum(axis=1)
    ax[1, 1].semilogy(freq, np.maximum(pooled/pooled.max(), 1e-12), color=blue)
    ax[1, 1].set(title="Port velocity spectrum (Hann)", xlabel="Frequency (Hz)", ylabel="Relative power", xlim=(0, 250), ylim=(1e-9, 2))
    ax[1, 2].plot(t, data["connector_potential"]/E, color=green)
    ax[1, 2].set(title="Cubic connector energy share", xlabel="Time (s)", ylabel="Connector potential / mechanical energy")
    fig.suptitle(row["id"]+" | connector and modal diagnostics", fontsize=14)
    save_figure(fig, out, "ports_phase_spectrum")
    fig, ax = plt.subplots(2, 2, figsize=(12, 7), layout="constrained")
    for name, title in [("energy", "Mechanical energy"), ("dissipated_linear", "Linear damping loss"), ("dissipated_connector", "Connector damping loss")]:
        ax[0, 0].plot(t, data[name]/E[0], label=title)
    ax[0, 0].axhline(.4, ls="--", color="gray", lw=.8)
    ax[0, 0].set(title=f"Terminal energy: {100*E[-1]/E[0]:.2f}%", xlabel="Time (s)", ylabel="Fraction of E0"); ax[0, 0].legend(fontsize=8)
    ax[0, 1].semilogy(t, np.maximum(balance, 1e-16), color=blue)
    ax[0, 1].axhline(1e-4, ls="--", color=orange, label="Limit")
    ax[0, 1].set(title="Energy-balance residual", xlabel="Time (s)", ylabel="|E + D - E0| / E0"); ax[0, 1].legend(fontsize=8)
    ax[1, 0].plot(t, max_u*1000, label="Maximum node"); ax[1, 0].plot(t, rms_u*1000, label="Nodal RMS")
    ax[1, 0].set(title="Nodal translation magnitude", xlabel="Time (s)", ylabel="Displacement (mm)"); ax[1, 0].legend(fontsize=8)
    ax[1, 1].semilogy(t, np.maximum(data["strain_max"], 1e-16), color=green)
    ax[1, 1].axhline(.001, ls="--", color=orange, label="Limit")
    ax[1, 1].set(title="Recovered strain maximum", xlabel="Time (s)", ylabel="Strain component (dimensionless)"); ax[1, 1].legend(fontsize=8)
    fig.suptitle(row["id"]+" | runtime diagnostics; independent qualification waived", fontsize=14)
    save_figure(fig, out, "energy_strain")
    np.savetxt(tables/"metrics.csv", np.column_stack([t, tip_q, tip_v, max_u, rms_u, E, data["dissipated"], balance, data["strain_max"]]), delimiter=",", comments="", header="time_s,tip_ux_m,tip_uy_m,tip_uz_m,tip_vx_m_s,tip_vy_m_s,tip_vz_m_s,max_translation_m,rms_translation_m,energy_J,dissipated_J,energy_balance_relative,strain_max")
    summary = dict(id=row["id"], family=row["family"], modes=ic["modes"], tier=row["tier"],
        connector_energy_ratio=ic["connector_energy_ratio"], initial_amplitude_mm=ic["initial_amplitude_m"]*1000,
        maximum_translation_mm=float(max_u.max()*1000), terminal_energy_fraction=float(E[-1]/E[0]),
        max_energy_balance_relative=float(balance.max()), max_strain=float(data["strain_max"].max()),
        translation_displacement_L2_difference_from_linear=float(np.sqrt(errors[0]/errors[1])),
        translation_velocity_L2_difference_from_linear=float(np.sqrt(errors[2]/errors[3])),
        source=str(source.relative_to(ROOT)), source_sha256=digest, initial_state_sha256=ic["initial_state_sha256"],
        tip_node_one_based=tip+1, tip_coordinates_m=xyz[tip].tolist(), qualification_status=cfg["qualification_status"],
        physics_checks_passed=True, full_readback_receipt_verified=True,
        reference="Analytic original linear tangent response, same modal initial condition and linear damping; differences include phase accumulation and integration error, not a percentage of nonlinearity.",
        postprocessing="CPU only; all 4096 saved frames used for metrics. No new simulation or independent qualification.")
    write_json(tables/"analysis.json", summary)
    render_preview(source, animation, row["id"], gain=CONFIG["animation"]["displacement_gain"])
    return summary, (t, tip_q[:, 1]*1000, tip_v[:, 1], E/E[0])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=REPORT_ROOT, help="Report root; plots, animations and tables are separated below it.")
    args = parser.parse_args()
    if (args.out/"evidence/selected/manifest.json").exists():
        parser.error("This frozen packet already exists; choose a new versioned --out directory.")
    args.out.mkdir(parents=True, exist_ok=True)
    psutil.Process().nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "axes.spines.top": False,
        "axes.spines.right": False, "axes.grid": True, "grid.alpha": .18})
    state = read_json(ROOT/"runs/naca_campaign_control/state.json"); release = state["release_id"]
    cfg = read_json(ROOT/state["config"])
    candidates = [(release, read_json(ROOT/"runs"/release/"completed.json"))]
    parent = cfg.get("repair_parent_release")
    if parent:
        candidates.append((parent, read_json(ROOT/"runs"/parent/"completed.json")))
    with h5py.File(ROOT/"runs/dataset21_nlc6_trial_01/analysis_reference.h5") as f:
        reference = (f["nodes"][:].T, f["active"][:].astype(int)-1, f["modes"][:].T, f["mass_modes"][:].T, f["omega"][:])
    summaries, series = [], []
    for case in CONFIG["selected_ids"]:
        match = next(((source_release, row) for source_release, rows in candidates for row in rows
            if row["id"] == case and (source_release == release or cfg.get("amplitude_overrides", {}).get(case, 1) == 1)), None)
        if match is None:
            raise RuntimeError(f"Selected case has no accepted current or unchanged-parent receipt: {case}")
        source_release, row = match
        print("ANALYZE", row["id"], flush=True)
        summary, curves = analyze(ROOT/"data/releases"/source_release/row["relative_path"], row, cfg, reference, args.out)
        summaries.append(summary); series.append(curves)
    fig, axes = plt.subplots(4, 3, figsize=(15, 12), layout="constrained")
    for i, (summary, (t, q, v, energy)) in enumerate(zip(summaries, series)):
        for j, (values, ylabel) in enumerate([(q, "Tip normal displacement (mm)"), (v, "Tip normal velocity (m/s)"), (energy, "Mechanical energy / E0")]):
            axes[i, j].plot(t, values, lw=.8); axes[i, j].set(xlabel="Time (s)", ylabel=ylabel)
        axes[i, 0].set_title(f"{summary['id']} | modes {summary['modes']} | R={summary['connector_energy_ratio']:.3f}")
    fig.suptitle("Four accepted NACA-NLC6 population trajectories | full time histories", fontsize=16)
    save_figure(fig, section_path(args.out, "plots", "selected"), "overview")
    write_json(section_path(args.out, "evidence", "selected")/"manifest.json", dict(release=release, selection="Frozen illustrative IDs; accepted current or unchanged-parent files, never population statistics.", trajectories=summaries,
        animation=dict(frames=150, duration_s=6, physical_window_s=[0, .2], displacement_gain=10, equal_axis_units=True)))
    build_dashboard(args.out)
    print("COMPLETE", args.out, flush=True)


if __name__ == "__main__":
    main()
