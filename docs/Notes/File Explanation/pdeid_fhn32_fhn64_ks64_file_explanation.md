# PDEID FHN32/FHN64/KS64 File Explanation

## Task Summary

This task generated the `pdeid_fhn32_fhn64_ks64` high-dimensional PDE identification dataset for three complete-state autonomous systems: `fhn32`, `fhn64`, and `ks64`. The implementation follows the task specification in `docs/notes/mathematical explanation/pdeid_fhn32_fhn64_ks64.md` for the data interface, trajectory split, sampling interval, record length, HDF5 schema, and numerical certificates.

The current formal run uses `R=480` trajectories per object, split as `320/80/80`, with `M=1024`, `tau=0.25`, and complete-state targets `y_m = z_m`. The output tensors are stored in row-time-dimension layout as `/state_rtd[trajectory, time, state]`. This 2026-07-07 update expands the original 120-trajectory release by 4x while keeping the dynamics, sampling interval, record length, solver settings, and acceptance/certificate protocol unchanged.

## Run Entry Points And Scripts

- `experiments/smoke_tests/run_pdeid_fhn32_fhn64_ks64_smoke.jl` runs the minimal smoke profile under `runs/smoke_tests/`.
- `experiments/data_generation/generate_pdeid_fhn32_fhn64_ks64.jl` runs the formal profile and writes the release outputs under `data/pdeid_fhn32_fhn64_ks64_julia/`.
- `src/data/pdeid_fhn32_fhn64_ks64_generation.jl` contains the reusable task implementation: FHN method-of-lines generation, KS Fourier ETDRK4 generation, HDF5/TOML/JSON writing, numerical certificates, tables, and plots.

## Core Source, Configs, And Docs Changed

- `Project.toml` and `Manifest.toml` now include the task dependencies `HDF5`, `FFTW`, `OrdinaryDiffEq`, and `SciMLBase`. Existing dependencies were resolved forward so the environment could instantiate successfully.
- The FHN generator uses periodic finite differences and `Rodas5P()` with formal tolerances `reltol=1e-8`, `abstol=1e-10`.
- The KS generator uses a Fourier pseudospectral ETDRK4 stepper with `dt=0.05`, `2/3` dealiasing, contour-averaged coefficients, and a per-step projection back to real zero-mean dealiased states to prevent long-time Hermitian-symmetry drift.

## Generated Data, Artifacts, Reports, And Logs

Formal data outputs are local generated files and remain ignored by git:

- `data/pdeid_fhn32_fhn64_ks64_julia/fhn32.h5`
- `data/pdeid_fhn32_fhn64_ks64_julia/fhn64.h5`
- `data/pdeid_fhn32_fhn64_ks64_julia/ks64.h5`
- `data/pdeid_fhn32_fhn64_ks64_julia/fhn32.toml`
- `data/pdeid_fhn32_fhn64_ks64_julia/fhn64.toml`
- `data/pdeid_fhn32_fhn64_ks64_julia/ks64.toml`
- `data/pdeid_fhn32_fhn64_ks64_julia/numeric_certificate.json`
- `data/pdeid_fhn32_fhn64_ks64_julia/Project.toml`
- `data/pdeid_fhn32_fhn64_ks64_julia/Manifest.toml`

Report outputs are under `reports/v1_plus/pdeid_fhn32_fhn64_ks64/`, including certificate tables, split/state summaries, heatmaps, KS Fourier spectrum, and the formal run summary JSON.

## Script-To-Script Data Flow

The smoke and formal entry points both include `src/data/pdeid_fhn32_fhn64_ks64_generation.jl` and select a profile. The profile fixes trajectory counts, warm-up times, record length, output roots, tolerances, seeds, and acceptance settings. The source implementation then generates raw complete-state trajectories, computes train-only field-shared statistics for certificates, writes one HDF5 file and one TOML file per object, writes the shared numerical certificate JSON, and generates report-local tables and plots.

## Validation Commands And Results

Smoke command:

```powershell
julia --project=. experiments\smoke_tests\run_pdeid_fhn32_fhn64_ks64_smoke.jl
```

Smoke passed with shapes `[6,17,64]`, `[6,17,128]`, and `[6,17,64]`. One-step time errors were `4.718969e-11` for `fhn32`, `3.205976e-11` for `fhn64`, and `4.092219e-7` for `ks64`.

Formal command:

```powershell
julia --project=. experiments\data_generation\generate_pdeid_fhn32_fhn64_ks64.jl
```

Formal generation passed. Readback checks confirmed HDF5 shapes `[480,1025,64]`, `[480,1025,128]`, and `[480,1025,64]`, with split counts `320/80/80` for every object. Formal one-step time errors were `3.730045e-12`, `3.736437e-12`, and `2.231861e-7`, all below the `1e-4` threshold. The FHN64 space certificate was `1.310732e-3`, the KS64 space certificate was `2.234353e-7`, and KS zero-mean drift stayed at floating-point roundoff scale in generation diagnostics.

## Numerical Adjustments

The original FHN acceptance expectation required `A_FHN(T_warm) >= 0.5` after `T_warm=32`. A pre-formal probe found that the specified autonomous no-drive FHN setup produced warm-end activities below `0.5`, concentrated below about `0.39`, so no formal FHN trajectory could be accepted under the original threshold. The formal profile therefore uses `A_FHN(T_warm) >= 0.35` while keeping the PDE parameters, initial-condition distribution, warm-up duration, solver, tolerances, sampling interval, and record length unchanged. The certificate also shows that FHN activity may continue relaxing during the saved record, so downstream users should not treat the FHN objects as sustained traveling-pulse data. This adjustment is recorded in `numeric_certificate.json` and the task report.
