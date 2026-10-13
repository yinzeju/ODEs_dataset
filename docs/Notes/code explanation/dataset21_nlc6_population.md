# NACA-NLC6 population generation

The user accepted the NLC6 proposal after one completed exploratory trajectory
and explicitly authorized 144 clean trajectories without additional smoke or
independent qualification runs. This is an implementation and launch record,
not a completed-dataset report. Generation is in progress.

Current engineering revision: `dataset21_nlc6_f4096_144_v1_r2`, configured by
`configs/releases/dataset21_nlc6_v1_r2.json` and its hashed explicit population
plan. Five failed family-3 cases use the user-authorized 0.8 displacement scale;
all other recipes, split identities and physics remain unchanged. Seventy-one
accepted parent files are reused immutably with full readback. The r1 worker
disappeared without a Julia exception; its evidence remains preserved. The
current worker uses `launch_dataset21_nlc6_detached.ps1` and a hidden native
Windows PowerShell supervisor created through WMI, outside the Codex terminal
process tree. Inspect `runs/naca_campaign_control/state.json` for the current
receipt before any launch. The original v1 design/launch details below remain
historical references and must not be used to restart retired workers.

## Frozen design

- Release: `dataset21_nlc6_f4096_144_v1`.
- Config: `configs/releases/dataset21_nlc6_v1.json`.
- Mechanical model: 14,922 displacement DOFs, 29,844 full physical states; no
  reduced dynamics and no additional connector states.
- Six passive fixed-direction patch connectors implement cubic elastic forces
  and smooth saturating velocity-dependent damping, as specified in
  `dataset21_naca_nlc6_proposal.md`. The model includes a stationary support
  fixture and is distinct from the original SSMTool NACA example.
- Updated baseline Rayleigh coefficients: aM = 0.5879008847043158 /s and
  aK = 1.6378470960752408e-6 s. The first/fourth mode targets are 1.0% / 0.12%.
- 4096 Float64 frames including t=0, dt=0.0005 s, duration=2.0475 s.
- Full-state Radau IIA5: two internal substeps, startup refinement 32 over the
  first 0.05 s, scaled Newton tolerance 1e-13. GPU evaluates shell geometric
  forces; CPU sparse solves use exact rank-18 connector stage-tangent updates.
- Zero initial velocities, no ongoing force, no gravity, rotation or noise.

## Population and initialization

Twelve families contain the four individual original modes, their six pairs,
one four-mode mixture, and a nonlinear static release. Modes set initial
conditions only. Every family contributes eight Train, two Validation and two
Test cases. The Validation split is a machine-learning split; its name does not
mean that an independent numerical qualification campaign is being executed.

| Split | Low | Middle | High | Total |
| --- | ---: | ---: | ---: | ---: |
| Train | 16 | 40 | 40 | 96 |
| Validation | 4 | 10 | 10 | 24 |
| Test | 4 | 10 | 10 | 24 |
| Total | 24 | 60 | 60 | 144 |

Strength means added quartic connector potential divided by the original linear
strain energy. Its centers are 0.025, 0.10 and 0.25, with predeclared 10% relative
jitter. The frozen per-family allocation in the JSON config sets every count.
Seeds are SHA256-derived from release identity, seed 20261012, family and ordinal.
The leading modal/static sign alternates, with independent signs for remaining
modal components. Pair energy fractions cycle through 0.25, 0.50 and 0.75;
four-mode fractions permute 0.1/0.2/0.3/0.4, jitter by 10%, then normalize.
The complete plan is saved before the first trajectory starts.

Modal states use the exact algebraic scale for the target connector-energy
ratio. Static states solve the full nonlinear equilibrium and the same ratio
constraint jointly, with a unit-total normal load over the outer 10% of the
skin; the load is removed for release. Continuation uses 1/16, 1/4, 1/2 and 1
times the requested ratio. The force check is roundoff-aware, the correction
tolerance is 1e-9, and the ratio tolerance is 1e-8. This equilibrium calculation
is required initial-condition construction, not a validation trajectory.
An inadmissible initial state stops the run; its strength is not silently lowered.

## Execution and recovery

Entry points:

```powershell
pwsh -NoProfile -File experiments/data_generation/start_dataset21_nlc6_campaign.ps1 -Attempt 01
```

The above attempt is already running. Do not repeat it. A resume requires a new
attempt identifier and verification that the previous PID/creation-time pair is
no longer alive. The directory execution lock prevents duplicate launches.
The Julia entry is `experiments/data_generation/run_dataset21_nlc6_campaign.jl`;
the reusable driver is `src/data/dataset21_nlc6/campaign.jl`.

The retained base model is `artifacts/dataset21_nlc6/base_model.jld2`, SHA256
`c2aca06d27abf835ad75d03f3c9f968037a3137bb6a36ed6be54e16686e34b14`.
Its mesh is retained alongside it. These local numerical dependencies are not
uploaded to Git. The inherited shell source, pinned upstream identity, source
retrieval tool, mesh assembly recipes, environment and diagnostics remain in
`src/data/dataset21_naca/`, `configs/` and `experiments/data_generation/`.

Data are saved under `data/releases/dataset21_nlc6_f4096_144_v1/`; each trajectory
has its own directory containing `trajectory.h5`, initial-condition metadata,
solver receipt, progress and readback receipt. Julia x axes are state/time;
h5py sees time/state. The first half of each state is q, followed by qdot.
Separate fields store energy, linear/nonlinear dissipated work, connector
potential, six connector displacements and velocities, and recovered strain.

`runs/dataset21_nlc6_f4096_144_v1/` holds the immutable input fingerprint/source
capsule, population plan, completed list, campaign status, launcher receipts
and logs. Recovery reuses only complete files with matching initial states,
hashes and full readback. Partial files and failure receipts are preserved.
Changing frozen numerical inputs requires an explicit versioned repair record.

## Execution checks and evidence boundary

Independent time/grid qualification and new validation experiments are waived.
The release status is `user_waived_independent_qualification`. Existing checks
remain: finite states, Newton convergence, strain <=0.001, relative energy-balance
error <=1e-4, terminal energy <=40%, complete readback and SHA256 binding. Failure
stops the campaign for diagnosis; no parameter or acceptance limit is relaxed
automatically. The generator writes a complete manifest only after 144 successes.

The prior single NLC6 trial remains separate evidence: 4096 frames, energy ratio
0.1941108740, maximum energy-balance error 1.2140542e-5, strain 6.6231445e-5,
1451.93 s integration time, 978,751,801 HDF5 bytes. Extrapolating that one case
gives roughly 58 hours and 131.26 GiB for 144 trajectories; actual runtimes vary
by initial condition and these estimates do not constitute batch results.

The old NACA trajectory and verification HDF5 data were removed at the user's
request. See `../evidence/dataset21_naca_retirement_20261012.json`. Old source
capsules, small receipts and an exact-byte ZIP are on archive branch
`codex/abolish-naca-pre-nlc6-20261012`. New NLC6 data, the completed trial, shared
models and source code were protected. Do not restart the retired campaign.

The existing heartbeat follows this population and reports only meaningful
changes or required repairs. The earlier final-shutdown authorization applies only after data, readback, reporting and publication are complete and unrelated experiments are inactive. The final Chinese report
and numerical appendix will use the completed population evidence; this launch
does not claim that all trajectories are already generated.

## Visualization workspace

Current plots and animations are curated in
`reports/Dataset21_NLC6_v1_nonlinear_wing/`. Open `tables/index.html` there for the
single offline summary of four selected completed cases and the separate trial.
All current GIFs use 10x display displacement and six-second playback; metrics use
the full 4096-frame histories. Figures are in `plots/`, GIFs in `animations/`, CSV
and JSON metrics in `tables/`, and hashes/relocation records in `evidence/`.
Superseded renderings and the retired original NACA preview are retained under
`archive/` and are clearly separated from current NLC6 evidence.

Maintained analysis, plotting and rendering scripts moved to
`experiments/postprocessing/`; shared report paths and selected IDs are declared
in `configs/visualizations/dataset21_nlc6_report.json`. Simulation data and active
worker inputs remain in their original locations. Rebuild only the dashboard with
`python -X utf8 experiments/postprocessing/dataset21_nlc6_report.py`; audit the
curated files with `audit_dataset21_nlc6_report.py` in the same directory.
