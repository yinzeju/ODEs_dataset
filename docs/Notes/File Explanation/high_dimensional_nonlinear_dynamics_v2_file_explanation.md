# High-Dimensional Nonlinear Dynamics v2 File Explanation

## Task Summary

This task implements and releases the independent `high_dimensional_nonlinear_dynamics_v2` data factory defined by `docs/notes/mathematical explanation/High-Dimensional Nonlinear Dynamics Data Generation.md`. The release contains newly integrated raw physical-coordinate trajectories for L96-40, KS64, and FHN64. It does not include or import trajectories from the earlier Lorenz96 or PDEID releases, and it does not store normalized states or normalization parameters.

Each system contains 480 trajectories with trajectory-level Split-I counts `320/80/80`. L96 stores 2,049 snapshots of a 40-dimensional state. KS64 stores 5,121 snapshots of a 64-dimensional field. FHN64 stores 5,121 snapshots of the concatenated 64-point `u` and `v` fields, giving state dimension 128.

## Run Entry Points

- `experiments/smoke_tests/run_high_dimensional_nonlinear_dynamics_v2_smoke.jl` runs the minimal end-to-end profile.
- `experiments/data_generation/generate_high_dimensional_nonlinear_dynamics_v2.jl` runs the formal 480-trajectory profile.
- `test/unit/test_high_dimensional_nonlinear_dynamics_v2.jl` checks fixed configuration contracts, periodic indexing, zero-mean KS initialization, FHN regime counts, and minimal trajectories.

The formal command used 16 Julia threads:

```powershell
julia --threads=16 --project=. experiments\data_generation\generate_high_dimensional_nonlinear_dynamics_v2.jl
```

## Core Source And Configuration

`src/data/high_dimensional_nonlinear_dynamics_v2_generation.jl` assembles the independent implementation under `src/data/hdnd_v2/`:

- `core.jl` defines profiles, deterministic seeds, HDF5 structure, common statistics, PCA split metrics, autocorrelation, and certificate helpers.
- `l96.jl` defines L96-40, Vern9 production/reference integration, tangent dynamics, and Lyapunov diagnostics.
- `ks64.jl` defines Fourier pseudospectral ETDRK4, two-thirds dealiasing, real-Hermitian projection, resolution transfer, and tangent ETDRK4.
- `fhn64.jl` defines the fourth-order periodic spatial stencil, Rodas5P integration, four initial-condition regimes, blockwise error certificates, and pulse diagnostics.
- `generation.jl` performs deterministic multithreaded trajectory generation, main-thread HDF5 writes, diagnostics, plotting, certificate refresh, and run summaries.

The release declaration is `configs/releases/high_dimensional_nonlinear_dynamics_v2.json`. Its source policy is `fresh_numerical_integration`; its normalization policy is `none_raw_physical_coordinates`.

## Generated Data And Reports

Formal data are under `data/releases/high_dimensional_nonlinear_dynamics_v2/`:

- `l96_nx40_raw_v2.h5`: 306,152,176 bytes.
- `ks64_raw_v2.h5`: 1,201,784,043 bytes.
- `fhn64_raw_v2.h5`: 1,250,173,731 bytes.
- Three system-specific `*_data_certificate_v2.json` files.

Each HDF5 file contains `/meta`, `/train`, `/val`, `/test`, and `/diagnostics`. Split groups contain raw `Float64` state tensors, time, trajectory IDs, deterministic seeds, first recorded states, warm-up times, and regime labels. No file contains a `/normalization` group.

The implementation report, generation table, 25 diagnostic figures, and formal run summary are under `reports/v2_core/high_dimensional_nonlinear_dynamics_v2/`.

## Data Flow

The release config and formal profile fix all physical and numerical settings. A system-specific seed and trajectory ID generate a fresh pre-initial condition. The corresponding production solver performs warm-up and fixed-time output. Independent trajectories are integrated in parallel within a split, while HDF5 writes remain serial on the main thread. Statistics and reference solves operate on deterministic subsets after each system is written. The final certificate combines finite, shape, time-grid, duplicate, numerical-convergence, symmetry, stationarity, split-distribution, and system-specific checks.

## Validation

- Unit tests passed: 27/27.
- Multithreaded smoke generation passed for all three systems.
- Formal HDF5 readback confirmed shapes `(320,2049,40)/(80,2049,40)` for L96, `(320,5121,64)/(80,5121,64)` for KS64, and `(320,5121,128)/(80,5121,128)` for FHN64.
- FHN regime counts passed exactly: train `160/64/64/32`; validation and test `40/16/16/8` for active/formation/collision/recovery.
- All states are finite, all initial-state hashes and seeds are unique, time grids pass a scale-aware machine-precision check, and no normalization group exists.
- Formal one-step time errors are `2.398909e-16` for L96, `1.233415e-9` for KS64, and `1.595933e-14` for FHN64.
- KS64 and FHN64 spatial errors against `N_x=128` are `1.906190e-8` and `1.375269e-3`.
- Largest Lyapunov exponents are positive for L96 (`1.638868`) and KS64 (`0.0468412`).

The first formal attempt exposed growth of a nonphysical Fourier imaginary component during long KS integration. The ETDRK4 step and tangent step were corrected to project onto the real Hermitian subspace after every internal step. A 500-time-unit probe kept the imaginary component at approximately `1e-16`, and the regenerated 480-trajectory KS release passed. The final common gate initially rejected valid time grids because it used an absolute `32eps(Float64)` tolerance; the observed accumulated subtraction residual was `1.71e-14`. The check now uses `8eps(maximum(abs, time))`, after which all three unchanged time arrays passed.
