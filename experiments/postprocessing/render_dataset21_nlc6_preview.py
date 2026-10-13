"""Render existing NLC6 data only, with equal physical axis units and explicit gain."""
import os
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("OMP_NUM_THREADS", "1")
import json
import argparse
from pathlib import Path
from collections import defaultdict
import h5py
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm
from mpl_toolkits.mplot3d.art3d import Poly3DCollection, Line3DCollection
from mpl_toolkits.mplot3d import proj3d
from PIL import Image
import psutil
from plot_dataset21_naca_completed import read_mesh
from dataset21_nlc6_report import CONFIG, REPORT_ROOT

ROOT = Path(__file__).resolve().parents[2]


def exterior_mesh(path, xyz, triangles):
    lines = path.read_text().splitlines(); start = lines.index("$Elements")
    domains = {}
    for line in lines[start+2:start+2+int(lines[start+1])]:
        a = list(map(int, line.split())); ntags = a[2]
        if a[1] == 2 and 1 <= a[3] <= 100:
            domains[tuple(sorted(a[3+ntags:]))] = a[3]
    domain = np.array([domains[k] for k in sorted(domains)])
    pts = xyz[triangles]
    at_x_end = np.all(np.isclose(pts[:, :, 0], xyz[:, 0].min(), atol=1e-10), axis=1) | np.all(np.isclose(pts[:, :, 0], xyz[:, 0].max(), atol=1e-10), axis=1)
    at_z_end = np.all(np.isclose(pts[:, :, 2], xyz[:, 2].min(), atol=1e-10), axis=1) | np.all(np.isclose(pts[:, :, 2], xyz[:, 2].max(), atol=1e-10), axis=1)
    tri = triangles[(domain == 1) | ((domain == 2) & at_x_end) | ((domain == 3) & at_z_end)].copy()
    adjacency = defaultdict(list)
    for face, t in enumerate(tri):
        for a, b in zip(t, np.roll(t, -1)):
            adjacency[tuple(sorted((int(a), int(b))))].append((face, 1 if a < b else -1))
    assert all(len(v) == 2 for v in adjacency.values()), "The displayed physical exterior must be closed"
    neighbors = defaultdict(list)
    for pair in adjacency.values():
        (a, da), (b, db) = pair
        neighbors[a].append((b, -da*db)); neighbors[b].append((a, -da*db))
    orientation = np.zeros(len(tri), dtype=int); orientation[0] = 1; queue = [0]
    while queue:
        face = queue.pop()
        for neighbor, relation in neighbors[face]:
            expected = orientation[face]*relation
            if orientation[neighbor] == 0:
                orientation[neighbor] = expected; queue.append(neighbor)
            else:
                assert orientation[neighbor] == expected
    assert np.all(orientation != 0)
    tri[orientation < 0] = tri[orientation < 0][:, [0, 2, 1]]
    volume = np.einsum("ij,ij->i", xyz[tri[:, 0]], np.cross(xyz[tri[:, 1]], xyz[tri[:, 2]])).sum()/6
    if volume < 0:
        tri = tri[:, [0, 2, 1]]
    edges = np.array(list(adjacency))
    faces = np.array([[a[0], b[0]] for a, b in adjacency.values()])
    return tri, edges, faces, abs(float(volume))


def render_preview(source, out, label="NACA-NLC6", gain=CONFIG["animation"]["displacement_gain"]):
    if (out/f"wing_vibration_6s_{gain:g}x.gif").exists():
        raise FileExistsError("This frozen animation already exists; choose a new versioned output directory.")
    psutil.Process().nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
    out.mkdir(parents=True, exist_ok=True)
    xyz, triangles, _, active = read_mesh(ROOT / "artifacts/dataset21_nlc6/Wing.msh")
    with h5py.File(ROOT / "runs/dataset21_nlc6_trial_01/analysis_reference.h5") as ref:
        assert np.array_equal(active, ref["active"][:]-1)
        assert np.allclose(xyz, ref["nodes"][:].T, atol=1e-12)
    triangles, edges, edge_faces, enclosed_volume = exterior_mesh(ROOT / "artifacts/dataset21_nlc6/Wing.msh", xyz, triangles)
    indices = np.rint(np.linspace(0, 400, 150)).astype(int)
    translation = np.flatnonzero(active % 6 < 3)
    nodes, components = active[translation]//6, active[translation] % 6
    with h5py.File(source) as f:
        t = f["t"][indices]
        q = f["x"][indices, :len(active)]
        energy = f["energy"][indices] / f["energy"][0]
    u = np.zeros((len(indices), len(xyz), 3))
    u[:, nodes, components] = q[:, translation]
    assert np.isfinite(u).all()
    elev, azim = np.deg2rad(25), np.deg2rad(-65)
    view_plot = np.array([np.cos(elev)*np.cos(azim), np.cos(elev)*np.sin(azim), np.sin(elev)])
    view_xyz = view_plot[[1, 2, 0]]
    limit = float(np.max(np.abs(u[:, :, 1]))*1000)
    norm = TwoSlopeNorm(vmin=-limit, vcenter=0, vmax=limit)
    cmap = plt.get_cmap("coolwarm")
    fig = plt.figure(figsize=(10, 5.5), dpi=100)
    ax = fig.add_axes([.02, .13, .82, .76], projection="3d", proj_type="ortho")
    ax.computed_zorder = False
    surface = Poly3DCollection(xyz[triangles][:, :, [2, 0, 1]], edgecolors="none", antialiased=False)
    ax.add_collection3d(surface)
    outline = Line3DCollection(xyz[edges][:, :, [2, 0, 1]], colors="#a7b0bc", linewidths=.75, alpha=.9)
    ax.add_collection3d(outline)
    surface.set_zorder(3); outline.set_zorder(4)
    displayed = xyz[None, :, :] + gain*u
    padding = np.array([.08, .04, .08])
    low = np.minimum(displayed.min(axis=(0, 1))-padding, [-.10, -.15, -.08])
    high = np.maximum(displayed.max(axis=(0, 1))+padding, [1.10, .15, 5.08])
    bounds = np.column_stack([low[[2, 0, 1]], high[[2, 0, 1]]])
    ax.set(xlim=bounds[0], ylim=bounds[1], zlim=bounds[2], xlabel="Span z (m)")
    box_aspect = np.diff(bounds, axis=1).ravel()
    zoom = 1.0
    ax.set_box_aspect(box_aspect, zoom=zoom)
    ax.set_xticks([0, 1, 2, 3, 4, 5]); ax.set_yticks([0, .5, 1]); ax.set_zticks([-.1, 0, .1])
    ax.tick_params(labelsize=8, pad=1)
    ax.view_init(elev=25, azim=-65)
    fig.text(.70, .31, "Chord x (m)", fontsize=9, ha="center")
    fig.text(.76, .49, "Normal y (m)", fontsize=9, rotation=90, va="center")
    color_ax = fig.add_axes([.86, .29, .018, .39])
    fig.colorbar(plt.cm.ScalarMappable(norm=norm, cmap=cmap), cax=color_ax, label="Actual normal displacement (mm)")
    title = fig.suptitle("", fontsize=13, y=.96)
    fig.text(.5, .065, f"Actual FE wing-box exterior | displacement {gain:g}x | equal axis units\nFirst 0.20 s of motion | 6.00 s playback per loop | visible light-gray contours", ha="center", fontsize=10)
    # Equal axis units do not guarantee that the projected geometry fits the
    # square Axes3D clipping rectangle. Fit all frames in display coordinates.
    projected_geometry = displayed[:, :, [2, 0, 1]].reshape(-1, 3)
    margin_px = 16.0
    for _ in range(12):
        fig.canvas.draw()
        px, py, _ = proj3d.proj_transform(*projected_geometry.T, ax.get_proj())
        pixels = ax.transData.transform(np.column_stack([px, py]))
        lower, upper = pixels.min(axis=0), pixels.max(axis=0)
        allowed_lower = np.array([ax.bbox.x0, ax.bbox.y0])+margin_px
        allowed_upper = np.array([ax.bbox.x1, ax.bbox.y1])-margin_px
        if np.all(lower >= allowed_lower) and np.all(upper <= allowed_upper):
            break
        zoom *= .9
        ax.set_box_aspect(box_aspect, zoom=zoom)
    else:
        raise RuntimeError("Could not fit the full animated wing inside the viewport")
    viewport_clearance = np.minimum(lower-allowed_lower+margin_px, allowed_upper-upper+margin_px)
    frames = []
    edge_counts = []
    for j, k in enumerate(indices):
        deformed = xyz + gain*u[j]
        normals = np.cross(deformed[triangles[:, 1]]-deformed[triangles[:, 0]], deformed[triangles[:, 2]]-deformed[triangles[:, 0]])
        normals /= np.linalg.norm(normals, axis=1)[:, None]
        facing = normals @ view_xyz; front = facing > 1e-10
        surface.set_verts(deformed[triangles][:, :, [2, 0, 1]])
        surface.set_facecolor(cmap(norm(u[j, triangles, 1].mean(axis=1)*1000)))
        left, right = edge_faces.T
        silhouette = front[left] != front[right]
        crease = np.einsum("ij,ij->i", normals[left], normals[right]) < np.cos(np.deg2rad(30))
        visible = (silhouette | crease) & (front[left] | front[right])
        edge_counts.append(int(visible.sum()))
        outline.set_segments(deformed[edges[visible]][:, :, [2, 0, 1]])
        title.set_text(f"{label} | t = {t[j]:.4f} s | E/E0 = {energy[j]:.3f}")
        fig.canvas.draw()
        frame = Image.fromarray(np.asarray(fig.canvas.buffer_rgba())[:, :, :3].copy())
        frames.append(frame)
        if j in (0, 75):
            frame.save(out / ("initial.png" if j == 0 else "midpoint.png"))
        if j % 25 == 0:
            print(f"RENDER {j+1}/{len(indices)}", flush=True)
    path = out / f"wing_vibration_6s_{gain:g}x.gif"
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=[40]*len(frames), loop=0, optimize=False, disposal=2)
    plt.close(fig)
    with Image.open(path) as gif:
        durations = []
        for j in range(gif.n_frames):
            gif.seek(j); durations.append(gif.info["duration"])
        assert gif.n_frames == 150 and sum(durations) == 6000
    metadata = dict(source=str(source.relative_to(ROOT)), output=str(path.relative_to(ROOT)),
        frames=150, playback_duration_ms=sum(durations), physical_start_s=float(t[0]), physical_end_s=float(t[-1]),
        snapshot_indices=indices.tolist(), displacement_gain=gain, geometry_gain=1, equal_axis_units=True,
        projection="orthographic", exterior_triangles=len(triangles), closed_exterior=True, reference_enclosed_volume_m3=enclosed_volume,
        visible_edge_count_range=[min(edge_counts), max(edge_counts)], edge_color="#a7b0bc", edge_display="per-frame outward-facing physical exterior creases and silhouettes; internal rib/stiffener edges excluded",
        color_values="Actual normal displacement in mm, without display gain", bounds_plot_m=bounds.tolist(),
        render_revision="v2_projected_viewport_fit", camera_zoom=zoom,
        all_frame_projected_clearance_px=viewport_clearance.tolist(), minimum_required_clearance_px=margin_px,
        all_exterior_faces_rendered=True, simulation_executed=False)
    (out / "render_metadata.json").write_text(json.dumps(metadata, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in metadata.items() if k != "snapshot_indices"}, indent=2), flush=True)
    return metadata


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=ROOT/"runs/dataset21_nlc6_trial_01/trajectory.h5")
    parser.add_argument("--out", type=Path, default=REPORT_ROOT/"animations/trial")
    parser.add_argument("--label", default="NACA-NLC6")
    parser.add_argument("--gain", type=float, default=CONFIG["animation"]["displacement_gain"])
    args = parser.parse_args()
    render_preview(args.source.resolve(), args.out.resolve(), args.label, gain=args.gain)


if __name__ == "__main__":
    main()
