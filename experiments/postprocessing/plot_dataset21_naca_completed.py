"""Read a completed physical trajectory and render CPU-only diagnostics/animation."""
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
from matplotlib import colors
from matplotlib.animation import PillowWriter
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import psutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def read_mesh(path):
    """Match the production MSH2 node ordering, triangle deduplication and BCs."""
    lines = path.read_text().splitlines()
    i = lines.index("$Nodes"); count = int(lines[i+1])
    nodes = {int(a[0]): list(map(float, a[1:4]))
             for a in (line.split() for line in lines[i+2:i+2+count])}
    i = lines.index("$Elements"); count = int(lines[i+1])
    elements, fixed = {}, set()
    for line in lines[i+2:i+2+count]:
        a = list(map(int, line.split())); kind, ntags = a[1:3]
        if ntags < 1:
            continue
        physical, ids = a[3], a[3+ntags:]
        if 101 <= physical <= 200:
            fixed.update(ids)
        if 1 <= physical <= 100:
            assert kind == 2 and len(ids) == 3
            key = tuple(sorted(ids))
            assert key not in elements or elements[key][1] == physical
            elements[key] = (ids, physical)
    used = sorted({v for key in elements for v in key})
    mapping = {v: i for i, v in enumerate(used)}
    xyz = np.array([nodes[v] for v in used])
    triangles = np.array([[mapping[v] for v in elements[key][0]] for key in sorted(elements)])
    fixed = np.array(sorted(mapping[v] for v in fixed if v in mapping))
    assert np.max(np.abs(xyz[fixed, 2])) < 1e-8
    active = np.array([i for i in range(6*len(xyz)) if i//6 not in set(fixed)])
    return xyz, triangles, fixed, active


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", default="CAN_train_001")
    parser.add_argument("--frames", type=int, default=160)
    args = parser.parse_args()
    psutil.Process().nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
    state = json.loads((ROOT/"runs/naca_campaign_control/state.json").read_text())
    release = state["release_id"]
    run = ROOT/"runs"/release
    rows = json.loads((run/"formal_progress.json").read_text())
    row = next(r for r in rows if r["id"] == args.id)
    source = ROOT/"data/releases"/release/row["path"]
    receipt = json.loads(Path(str(source)+".json").read_text())
    assert receipt["physical_gates_passed"] and receipt["frames"] == 4096
    out = ROOT/"reports/Dataset-2.1/archive/retired_naca_preview"/args.id
    out.mkdir(parents=True, exist_ok=True)
    mesh = ROOT/"runs/dataset21_naca_zeta006_f4096_v2/meshes/candidate/Wing.msh"
    expected = json.loads((run/"models.json").read_text())["candidate"]
    assert hashlib.sha256(mesh.read_bytes()).hexdigest() == expected["mesh_sha256"]
    xyz, triangles, fixed, active = read_mesh(mesh)
    nq = len(active); assert 2*nq == receipt["state_dimension"] == 29844
    translation = np.flatnonzero(active % 6 < 3)
    node_index, component = active[translation]//6, active[translation] % 6
    indices = np.unique(np.round(np.linspace(0, 4095, args.frames)).astype(int))
    snapshots = {}
    with h5py.File(source, "r") as f:
        assert f["x"].shape == (4096, 2*nq)  # h5py reverses Julia HDF5 dimensions.
        t, energy, dissipated = [f[key][:] for key in ("t", "energy", "dissipated")]
        q0 = f["x"][0, :nq]
        assert hashlib.sha256(q0.tobytes()).hexdigest() == row["initial_state_sha256"]
        initial = np.zeros((len(xyz), 3)); initial[node_index, component] = q0[translation]
        tips = np.flatnonzero(np.isclose(xyz[:, 2], xyz[:, 2].max()))
        tip = tips[np.argmax(np.abs(initial[tips, 1]))]
        tip_col = int(np.flatnonzero(active == 6*tip+1)[0])
        uy, vy = np.empty(len(t)), np.empty(len(t))
        maximum, rms = np.empty(len(t)), np.empty(len(t))
        for first in range(0, len(t), 32):
            stop = min(first+32, len(t)); x = f["x"][first:stop, :]
            assert np.isfinite(x).all()
            u = np.zeros((stop-first, len(xyz), 3))
            u[:, node_index, component] = x[:, translation]
            magnitudes = np.linalg.norm(u, axis=2)
            maximum[first:stop] = magnitudes.max(axis=1)
            rms[first:stop] = np.sqrt(np.mean(magnitudes**2, axis=1))
            uy[first:stop], vy[first:stop] = x[:, tip_col], x[:, nq+tip_col]
            for k in indices[(indices >= first) & (indices < stop)]:
                snapshots[int(k)] = u[k-first].copy()
    balance = np.abs(energy+dissipated-energy[0])/energy[0]
    assert np.isclose(balance.max(), receipt["max_energy_balance_relative"], rtol=1e-7, atol=1e-14)
    assert np.isclose(energy[-1]/energy[0], receipt["final_energy_ratio"])
    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "axes.spines.top": False, "axes.spines.right": False,
                         "axes.grid": True, "grid.alpha": .18})
    blue, orange, green = "#2166ac", "#dd7c22", "#168c78"
    fig, axes = plt.subplots(2, 3, figsize=(14, 8), layout="constrained")
    ax = axes[0, 0]; ax.plot(t, uy*1000, color=blue, lw=1.1)
    ax.set(title="Tip normal displacement", xlabel="Time (s)", ylabel="Displacement (mm)")
    ax = axes[0, 1]; ax.plot(t, maximum*1000, color=blue, label="Maximum across nodes")
    ax.plot(t, rms*1000, color=green, label="Nodal RMS")
    ax.set(title="Translational displacement magnitude", xlabel="Time (s)", ylabel="Displacement (mm)"); ax.legend(fontsize=8)
    ax = axes[0, 2]; ax.plot(t, energy/energy[0], color=blue, label="Mechanical energy / E0")
    ax.plot(t, dissipated/energy[0], color=orange, label="Dissipated energy / E0")
    ax.axhline(.4, color="#777777", ls="--", lw=1, label="Terminal-energy limit")
    ax.set(title=f"Energy decay: final {100*energy[-1]/energy[0]:.2f}%", xlabel="Time (s)", ylabel="Normalized energy"); ax.legend(fontsize=8)
    ax = axes[1, 0]; ax.semilogy(t, np.maximum(balance, 1e-16), color=green)
    ax.axhline(1e-4, color=orange, ls="--", label="Acceptance limit")
    ax.set(title="Energy-balance residual", xlabel="Time (s)", ylabel="|E + D - E0| / E0", ylim=(1e-10, 3e-4)); ax.legend(fontsize=8)
    ax = axes[1, 1]; ax.plot(uy*1000, vy*1000, lw=.7, color=blue)
    ax.scatter([uy[0]*1000], [vy[0]*1000], color=orange, s=30, zorder=4, label="Initial state")
    ax.set(title="Tip phase portrait", xlabel="Normal displacement (mm)", ylabel="Normal velocity (mm/s)"); ax.legend(fontsize=8)
    frequency = np.fft.rfftfreq(len(t), t[1]-t[0]); spectrum = np.abs(np.fft.rfft((uy-uy.mean())*np.hanning(len(t))))**2
    spectrum /= spectrum.max(); ax = axes[1, 2]
    ax.semilogy(frequency, np.maximum(spectrum, 1e-14), color=blue)
    ax.axvline(expected["omega_rad_s"][0]/(2*np.pi), color=orange, ls="--", label="Linear mode 1")
    ax.set(title="Tip displacement spectrum (Hann window)", xlabel="Frequency (Hz)", ylabel="Relative spectral power", xlim=(0, 60), ylim=(1e-10, 2)); ax.legend(fontsize=8)
    fig.suptitle(f"NACA wing | {args.id} | 29,844 states, 4,096 frames\nUser-authorized partial qualification; completed trajectory checks passed", fontsize=15)
    fig.savefig(out/"diagnostics.png", dpi=160); fig.savefig(out/"diagnostics.pdf"); plt.close(fig)
    np.savetxt(out/"metrics.csv", np.column_stack([t, uy, vy, maximum, rms, energy, dissipated, balance]), delimiter=",", header="time_s,tip_uy_m,tip_vy_m_per_s,max_translation_m,rms_translation_m,energy_J,dissipated_J,relative_energy_balance", comments="")
    scale, fps = 100.0, 24
    limit = max(np.abs(u[:, 1]).max() for u in snapshots.values())*1000
    norm = colors.Normalize(-limit, limit); cmap = plt.get_cmap("coolwarm")
    fig = plt.figure(figsize=(9, 6), dpi=100); ax = fig.add_subplot(111, projection="3d")
    fig.subplots_adjust(left=0, right=.85, bottom=.09, top=.85)
    collection = Poly3DCollection(xyz[triangles][:, :, [2, 0, 1]], linewidths=.12, edgecolors=(.1, .2, .3, .18))
    ax.add_collection3d(collection)
    ax.set(xlim=(-.1, 5.1), ylim=(xyz[:, 0].min()-.08, xyz[:, 0].max()+.08), zlim=(-.42, .42), xlabel="Span z (m)", ylabel="Chord x (m)", zlabel="Normal y (m)")
    ax.set_box_aspect((5, 1.2, .85)); ax.view_init(elev=23, azim=-58)
    ax.set_axis_off()
    ax.text(-.05, .5, -.27, "Clamped root", fontsize=9, ha="center")
    ax.text(5.05, .5, -.31, "Free tip", fontsize=9, ha="center")
    ax.scatter(xyz[fixed, 2], xyz[fixed, 0], xyz[fixed, 1], s=5, c="#222222")
    scalar = plt.cm.ScalarMappable(norm=norm, cmap=cmap)
    fig.colorbar(scalar, ax=ax, shrink=.6, pad=.08, label="Actual normal displacement (mm)")
    title = fig.suptitle("", fontsize=13)
    fig.text(.5, .035, f"Span: 5 m | Geometry deformation exaggerated 100x | colors show actual displacement\nFull physical FE snapshots; animation samples {len(indices)} of 4096 frames | partial qualification", ha="center", fontsize=9)
    writer = PillowWriter(fps=fps)
    with writer.saving(fig, str(out/"wing_vibration.gif"), dpi=100):
        for number, k in enumerate(indices):
            u = snapshots[int(k)]; deformed = xyz+scale*u
            collection.set_verts(deformed[triangles][:, :, [2, 0, 1]])
            collection.set_facecolor(cmap(norm(u[triangles, 1].mean(axis=1)*1000)))
            title.set_text(f"NACA wing | {args.id}\nt = {t[k]:.3f} s   |   E / E0 = {energy[k]/energy[0]:.3f}")
            if number in (0, len(indices)//2):
                fig.savefig(out/("wing_initial.png" if number == 0 else "wing_midpoint.png"), dpi=100)
            writer.grab_frame()
            if number % 40 == 0:
                print(f"ANIMATION frame={number+1}/{len(indices)}", flush=True)
    plt.close(fig)
    with Image.open(out/"wing_vibration.gif") as animation:
        assert animation.n_frames == len(indices)
        durations = []
        for frame in range(animation.n_frames):
            animation.seek(frame); durations.append(animation.info.get("duration", 0))
        playback_seconds = sum(durations)/1000
    summary = {"source": str(source.relative_to(ROOT)), "source_sha256_from_generation": row["sha256"], "trajectory": args.id,
               "qualification_status": "user_authorized_partial", "frames": len(t), "final_energy_ratio": energy[-1]/energy[0],
               "maximum_energy_balance": balance.max(), "maximum_translation_mm": maximum.max()*1000,
               "max_recovered_strain_component_from_receipt": receipt["max_recovered_strain_component"],
               "tip_node_zero_based": int(tip), "tip_coordinates_m": xyz[tip].tolist(),
               "mesh_sha256": expected["mesh_sha256"], "animation_deformation_scale": scale,
               "animation_frames": len(indices), "animation_fps": fps,
               "animation_physical_duration_s": float(t[-1]), "animation_playback_duration_s": playback_seconds,
               "method": "Read-only CPU postprocessing; no simulation or GPU execution. Linear triangular display of nodal translations; rotations not separately rendered."}
    (out/"preview_manifest.json").write_text(json.dumps(summary, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == "__main__":
    main()
