"""Read a single completed NLC6 trial; compare to its exact linear tangent response."""
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
from dataset21_nlc6_report import REPORT_ROOT, section_path
from render_dataset21_nlc6_preview import render_preview

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", default="dataset21_nlc6_trial_01")
    parser.add_argument("--gif", action="store_true")
    parser.add_argument("--out", type=Path, default=REPORT_ROOT, help="Report root for trial plots, metrics and animation.")
    args = parser.parse_args()
    if (args.out/"plots/trial/diagnostics.png").exists():
        parser.error("This frozen trial presentation already exists; choose a new versioned --out directory.")
    psutil.Process().nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
    run = ROOT / "runs" / args.id
    completion = json.loads((run / "completion.json").read_text())
    assert completion["full_readback_passed"]
    cfg = json.loads((run / "source_snapshot/configs/trials/dataset21_nlc6_one.json").read_text())
    receipt = json.loads((run / "trajectory.h5.json").read_text())
    source = run / "trajectory.h5"
    with source.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    assert digest == completion["trajectory_sha256"] == receipt["sha256"]
    out = section_path(args.out, "plots", "trial")
    tables = section_path(args.out, "tables", "trial")
    with h5py.File(run / "analysis_reference.h5", "r") as ref:
        phi, mass_phi = ref["modes"][:].T, ref["mass_modes"][:].T
        omega, active = ref["omega"][:], ref["active"][:].astype(int) - 1
        xyz, q0, B = ref["nodes"][:].T, ref["q0"][:], ref["B"][:].T
        coefficients, (aM, aK) = ref["modal_coefficients"][:], ref["linear_damping"][:]
    nq = len(active)
    translation = np.flatnonzero(active % 6 < 3)
    nodes, components = active[translation] // 6, active[translation] % 6
    indices = np.array(cfg["trial"]["modes"]) - 1
    nmode = len(omega)
    all_u0 = np.zeros((len(xyz), 3))
    all_u0[nodes, components] = q0[translation]
    tips = np.flatnonzero(np.isclose(xyz[:, 2], xyz[:, 2].max()))
    tip = tips[np.argmax(abs(all_u0[tips, 1]))]
    tip_column = np.flatnonzero(active == 6 * tip + 1).item()
    window_sums = np.zeros((4, 4))
    with h5py.File(source, "r") as f:
        assert f["x"].shape == (4096, 2 * nq)
        assert np.array_equal(f["x"][0, :nq], q0) and np.count_nonzero(f["x"][0, nq:]) == 0
        t, E, D, D0, Dn, Uc, strain = [f[name][:] for name in
            ("t", "energy", "dissipated", "dissipated_linear", "dissipated_connector", "connector_potential", "strain_max")]
        s, w = f["connector_displacement"][:], f["connector_velocity"][:]
        assert np.allclose(t, np.arange(4096)*cfg["sampling"]["dt_candidate_s"], atol=1e-14, rtol=0)
        assert np.allclose(D, D0+Dn, atol=1e-14, rtol=0)
        assert np.allclose(Uc, (s**4 @ np.array([p["cubic_stiffness_N_per_m3"] for p in cfg["ports"]]))/4, atol=1e-14, rtol=1e-12)
        alpha = (aM + aK * omega[indices] ** 2) / 2
        wd = np.sqrt(omega[indices] ** 2 - alpha ** 2)
        decay = np.exp(-t[:, None] * alpha)
        phase = t[:, None] * wd
        eta_lin = coefficients * decay * (np.cos(phase) + alpha / wd * np.sin(phase))
        vel_lin = -coefficients * decay * (wd + alpha ** 2 / wd) * np.sin(phase)
        eta, etadot = np.empty((len(t), nmode)), np.empty((len(t), nmode))
        tip_q, tip_v, max_u = np.empty(len(t)), np.empty(len(t)), np.empty(len(t))
        qerr = verr = qden = vden = 0.
        for first in range(0, len(t), 32):
            stop = min(first + 32, len(t))
            x = f["x"][first:stop, :]
            assert np.isfinite(x).all()
            q, v = x[:, :nq], x[:, nq:]
            assert np.allclose(q@B, s[first:stop], atol=1e-14, rtol=1e-12)
            assert np.allclose(v@B, w[first:stop], atol=1e-14, rtol=1e-12)
            eta[first:stop], etadot[first:stop] = q @ mass_phi, v @ mass_phi
            qlin = eta_lin[first:stop] @ phi[translation][:, indices].T
            vlin = vel_lin[first:stop] @ phi[translation][:, indices].T
            qerr += np.sum((q[:, translation] - qlin) ** 2)
            verr += np.sum((v[:, translation] - vlin) ** 2)
            qden += np.sum(qlin ** 2)
            vden += np.sum(vlin ** 2)
            # Chunk boundaries divide each 1024-frame window exactly.
            window_sums[first//1024] += [np.sum((q[:, translation]-qlin)**2),
                np.sum((v[:, translation]-vlin)**2), np.sum(qlin**2), np.sum(vlin**2)]
            u = np.zeros((stop - first, len(xyz), 3))
            u[:, nodes, components] = q[:, translation]
            max_u[first:stop] = np.linalg.norm(u, axis=2).max(axis=1)
            tip_q[first:stop], tip_v[first:stop] = q[:, tip_column], v[:, tip_column]
    slin, wlin = eta_lin @ (B.T @ phi[:, indices]).T, vel_lin @ (B.T @ phi[:, indices]).T
    balance = abs(E + D - E[0]) / E[0]
    assert np.isclose(balance.max(), receipt["max_energy_balance_relative"], atol=1e-12)
    assert np.all(np.diff(D0) >= -1e-12) and np.all(np.diff(Dn) >= -1e-12)
    Emode = .5 * (etadot ** 2 + eta ** 2 * omega ** 2)
    port_qdiff = np.linalg.norm(s - slin, axis=0) / np.linalg.norm(slin, axis=0)
    port_vdiff = np.linalg.norm(w - wlin, axis=0) / np.linalg.norm(wlin, axis=0)
    frequency = np.fft.rfftfreq(len(t), t[1] - t[0])
    window = np.hanning(len(t))[:, None]
    power = abs(np.fft.rfft((w - w.mean(axis=0)) * window, axis=0)) ** 2
    pooled = power.sum(axis=1)
    limit = cfg["sampling"]["candidate_effective_frequency_limit_Hz"]
    high_band_fraction = pooled[frequency > limit].sum() / pooled.sum()
    bandwidth99 = frequency[np.searchsorted(np.cumsum(pooled) / pooled.sum(), .99)]
    port_high_band = power[frequency > limit].sum(axis=0) / power.sum(axis=0)
    port_bandwidth99 = [float(frequency[np.searchsorted(np.cumsum(power[:, j])/power[:, j].sum(), .99)]) for j in range(6)]
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
        "axes.spines.top": False, "axes.spines.right": False, "axes.grid": True, "grid.alpha": .18})
    blue, orange, green = "#2166ac", "#d86b27", "#188c78"
    fig, axes = plt.subplots(2, 3, figsize=(15, 8), layout="constrained")
    ax = axes[0, 0]
    ax.plot(t, tip_q * 1000, color=blue, lw=.9, label="Full nonlinear model")
    ax.plot(t, eta_lin @ phi[tip_column, indices] * 1000, color=orange, lw=.7, alpha=.7, label="Same-IC linear tangent")
    ax.set(title="Tip normal displacement", xlabel="Time (s)", ylabel="mm"); ax.legend(fontsize=8)
    ax = axes[0, 1]
    ax.plot(t, s[:, 1] * 1000, color=blue, lw=1, label="Nonlinear")
    ax.plot(t, slin[:, 1] * 1000, color=orange, lw=.8, label="Linear")
    ax.set(title="Outer bending port", xlabel="Time (s)", ylabel="Extension (mm)"); ax.legend(fontsize=8)
    ax = axes[0, 2]
    ax.plot(t, E/E[0], label="Mechanical energy", color=blue)
    ax.plot(t, D0/E[0], label="Linear damping loss", color=orange)
    ax.plot(t, Dn/E[0], label="Connector damping loss", color=green)
    ax.axhline(.4, color="gray", ls="--", lw=.8)
    ax.set(title=f"Terminal energy: {100*E[-1]/E[0]:.2f}%", xlabel="Time (s)", ylabel="Fraction of E0"); ax.legend(fontsize=8)
    ax = axes[1, 0]
    ax.plot(s[:, 1] * 1000, w[:, 1], color=blue, lw=.8, label="Nonlinear")
    ax.plot(slin[:, 1] * 1000, wlin[:, 1], color=orange, lw=.6, alpha=.6, label="Linear")
    ax.set(title="Outer bending phase portrait", xlabel="Extension (mm)", ylabel="Velocity (m/s)")
    ax = axes[1, 1]
    ax.plot(t, Uc/E, color=green)
    ax.set(title="Added cubic-spring energy share", xlabel="Time (s)", ylabel="Connector potential / mechanical energy")
    ax = axes[1, 2]
    ax.semilogy(t, np.maximum(balance, 1e-16), color=blue, label="Energy-balance error")
    ax.axhline(1e-4, color=orange, ls="--", label="Target")
    ax.set(title="Numerical energy balance", xlabel="Time (s)", ylabel="|E + D - E0| / E0"); ax.legend(fontsize=8)
    fig.suptitle("NACA-NLC6 | one exploratory full-state trajectory | 29,844 states", fontsize=15)
    fig.savefig(out/"diagnostics.png", dpi=160); fig.savefig(out/"diagnostics.pdf"); plt.close(fig)
    fig, axes = plt.subplots(2, 2, figsize=(12, 8), layout="constrained")
    for j in range(6):
        axes[0, 0].plot(t, s[:, j]*1000, lw=.8, label=f"Port {j+1}")
        axes[0, 1].plot(t, w[:, j], lw=.8, label=f"Port {j+1}")
    axes[0, 0].set(title="All connector extensions", xlabel="Time (s)", ylabel="mm"); axes[0, 0].legend(ncol=3, fontsize=8)
    axes[0, 1].set(title="All connector velocities", xlabel="Time (s)", ylabel="m/s")
    for j in range(min(4, nmode)):
        axes[1, 0].plot(t, Emode[:, j]/E[0], label=f"Original mode {j+1}")
    axes[1, 0].set(title="Projection onto original modes (diagnostic)", xlabel="Time (s)", ylabel="Linear modal energy / E0")
    axes[1, 0].legend(fontsize=8)
    axes[1, 1].semilogy(frequency, np.maximum(pooled/pooled.max(), 1e-12), color=blue)
    axes[1, 1].axvline(limit, ls="--", color=orange, label="24 samples/cycle threshold")
    axes[1, 1].set(title="Port velocity spectrum (Hann window)", xlabel="Frequency (Hz)", ylabel="Normalized spectral power", xlim=(0, 250), ylim=(1e-7, 1.1))
    axes[1, 1].legend(fontsize=8)
    fig.savefig(out/"ports_and_modes.png", dpi=160); plt.close(fig)
    fig, axes = plt.subplots(1, 2, figsize=(11, 4), layout="constrained")
    for j, port in enumerate(cfg["ports"]):
        sj = np.linspace(s[:, j].min(), s[:, j].max(), 400)
        wj = np.linspace(w[:, j].min(), w[:, j].max(), 400)
        axes[0].plot(sj*1000, port["cubic_stiffness_N_per_m3"]*sj**3, label=f"Port {j+1}")
        axes[1].plot(wj, port["damping_cap_N_s_per_m"]*wj**3/(wj**2+port["saturation_speed_m_per_s"]**2))
    axes[0].set(title="Cubic forces over visited displacement ranges", xlabel="Extension (mm)", ylabel="Force (N)")
    axes[0].legend(fontsize=8, ncol=2)
    axes[1].set(title="Smooth damper forces over visited velocity ranges", xlabel="Velocity (m/s)", ylabel="Force (N)")
    fig.savefig(out/"connector_laws.png", dpi=160); plt.close(fig)
    summary = {"status": "single_exploratory_trajectory_not_qualified_dataset", "source_sha256": digest,
        "frames": len(t), "state_dimension": 2*nq, "duration_s": t[-1], "file_bytes": source.stat().st_size,
        "initial_energy_J": E[0], "terminal_energy_fraction": E[-1]/E[0],
        "max_energy_balance_relative": balance.max(), "max_strain_component": strain.max(),
        "max_translation_mm": max_u.max()*1000, "linear_damping_loss_fraction_E0": D0[-1]/E[0],
        "connector_damping_loss_fraction_E0": Dn[-1]/E[0],
        "translation_displacement_L2_difference_from_linear": np.sqrt(qerr/qden),
        "translation_velocity_L2_difference_from_linear": np.sqrt(verr/vden),
        "translation_comparison_by_time_quarter": [dict(start_s=t[1024*j], end_s=t[1024*(j+1)-1],
            displacement_relative_L2=float(np.sqrt(a/c)), velocity_relative_L2=float(np.sqrt(b/d)))
            for j, (a,b,c,d) in enumerate(window_sums)],
        "port_displacement_L2_difference_from_linear": port_qdiff.tolist(),
        "port_velocity_L2_difference_from_linear": port_vdiff.tolist(),
        "port_velocity_hann_power_fraction_above_83_33_Hz": high_band_fraction,
        "port_velocity_hann_99pct_bandwidth_Hz": bandwidth99,
        "individual_port_velocity_power_fraction_above_83_33_Hz": port_high_band.tolist(),
        "individual_port_velocity_99pct_bandwidth_Hz": port_bandwidth99,
        "connector_potential_fraction_of_E_mean": np.mean(Uc/E),
        "connector_potential_fraction_of_E_second_half_mean": np.mean((Uc/E)[len(t)//2:]),
        "max_original_modes_5_to_12_linear_energy_fraction_E0": np.max(Emode[:,4:12].sum(axis=1))/E[0],
        "comparison": "Exact original linear tangent response for the same modal initial condition and updated linear damping. Differences include geometric and connector nonlinearities, plus any integration error. Translation L2 uses all free translational components and times, divided by the corresponding linear-reference norm; rotations are excluded to avoid mixed units.",
        "limitations": ["No same-IC physical time-refinement test", "No new spatial qualification", "One initial condition only", "Port spectrum is a windowed output-bandwidth diagnostic, not a full-state aliasing guarantee"],
        "physics_checks_passed": receipt["physics_checks_passed"]}
    if args.gif:
        summary["animation"] = render_preview(source, section_path(args.out, "animations", "trial"), "NACA-NLC6 trial")
    np.savetxt(tables/"metrics.csv", np.column_stack([t, tip_q, tip_v, max_u, E, D, balance, strain]),
        delimiter=",", comments="", header="time_s,tip_uy_m,tip_vy_m_s,max_translation_m,energy_J,dissipated_J,energy_balance_relative,strain_max")
    (tables/"analysis.json").write_text(json.dumps(summary, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == "__main__":
    main()
