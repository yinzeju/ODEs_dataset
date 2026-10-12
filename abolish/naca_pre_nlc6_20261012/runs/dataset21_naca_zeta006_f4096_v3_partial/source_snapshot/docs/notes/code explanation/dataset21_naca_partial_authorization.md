# User-authorized partial qualification

On 2026-10-11 (America/Los_Angeles), the user explicitly instructed the campaign
to stop further independent qualification, keep the two completed cases, delete
the other cases and dedicated caches, and launch all 144 formal trajectories.
This supersedes the original five-case qualification requirement.

Release `dataset21_naca_zeta006_f4096_v3_partial` reuses the identical 29844-state
physical candidate from v2. The integrator and force kernels are unchanged.
Use Radau IIA with two internal substeps, the existing startup refinement,
0.6% first-two-mode damping, 4096 frames, dt=0.0008 s, and clean 96/24/24 data.
The offered amplitude remains 0.006 m, not a fully qualified validity envelope.
Only small/finite mode-1 qualification cases are retained, including CPU/GPU
comparison, time refinement, linear references and double-rate output.
Remaining mixed-mode, static-release and nonlinear spatial qualification are
waived, not passed. Every formal trajectory still checks Newton convergence,
strain, energy balance and terminal energy; release verification checks hashes,
finite values, dimensions, time grid, splits and Train-only normalization.
The manifest must say partial qualification, never dataset-qualified.

The original frozen v2 source snapshot and stop/deletion receipts preserve
provenance. Deletion of large case 3-5 artifacts and dedicated fine-grid caches was
explicitly requested. Automatic approval blocked both deletion attempts; these
files remain on disk, unused. See runs/naca_campaign_control/user_qual_cleanup_status.json. Shared source provenance and the formal
candidate model are retained. No remaining QUAL case may be resumed automatically.
