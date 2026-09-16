# Duffing Augmented SNR10 File Explanation

## Task Summary

`duffing_aug_snr10` generates a KDSM-MP-ready forced single-degree-of-freedom Duffing dataset with paired clean and 10 dB noisy-input views. The task follows `docs/notes/mathematical explanation/duffing_aug_snr10.md`: all trajectories share one fixed sparse multisine realization, while each trajectory has independent initial displacement, velocity, and forcing phase.

The generated learner interfaces are:

- Clean: `(x, v, u, cos(theta), sin(theta)) -> (x, v)`.
- Noise10: `(x_noisy, v_noisy, u, cos(theta), sin(theta)) -> (x, v)`.

## Run Entry Points and Scripts

- `experiments/data_generation/generate_duffing_aug_snr10_dataset.jl` is the formal generation entry point.
- `src/generators/duffing_aug_snr10_generator.jl` contains the local adaptive DOPRI5 integrator, fixed multisine construction, anti-alias decimation, 10 dB noise protocol, raw-coordinate persistence, diagnostics, JLD2/JSON writing, and time-series plot generation.

Run command used:

```powershell
julia --project=. --threads=auto experiments/data_generation/generate_duffing_aug_snr10_dataset.jl
```

## Core Source, Configs, and Docs Changed

- `configs/systems/v1_core/duffing_aug_snr10.json` records the Duffing parameters, forcing frequencies, seeds, solver tolerances, and sampling rates.
- `configs/observations/duffing_aug_snr10_kdsm_mp.json` records the clean/noise10 KDSM-MP observation protocol.
- `configs/splits/v1_core/duffing_aug_snr10_split_i.json` records the trajectory-level `512/128/128` split.
- `configs/windows/v1_core/duffing_aug_snr10_windows.json` records horizons `{1,2,4,8,16,32,64,128}`.
- `configs/tasks/v1_core/duffing_aug_snr10_tasks.json` records the clean and noisy-input supervised mappings.
- `configs/releases/duffing_aug_snr10_release.json` records the release-level paths and recommended task-interface names.

## Generated Data, Artifacts, Reports, and Logs

Generated outputs are local release artifacts and remain ignored by git:

- Clean data: `data/processed/duffing_aug_snr10/kdsm_data_0dot1_duffing_aug_clean.jld2`.
- Noise10 data: `data/processed/duffing_aug_snr10/kdsm_data_0dot1_duffing_aug_snr10.jld2`.
- Metadata: `data/manifests/duffing_aug_snr10/kdsm_data_0dot1_duffing_aug_metadata.json`.
- Release manifest: `data/releases/duffing_aug_snr10/release_manifest.json`.
- Summary table: `reports/v1_core/duffing_aug_snr10/tables/duffing_aug_snr10_generation_summary.csv`.
- Generation log: `reports/v1_core/duffing_aug_snr10/logs/duffing_aug_snr10_generation.log`.
- Report: `reports/v1_core/duffing_aug_snr10/notebooks/duffing_aug_snr10_report.md`.
- Clean time-series plot: `reports/v1_core/duffing_aug_snr10/plots/duffing_aug_snr10_clean_timeseries.png`.
- Noisy time-series plot: `reports/v1_core/duffing_aug_snr10/plots/duffing_aug_snr10_noisy_timeseries.png`.

The mathematical note recommends `.mat` filenames. This project run uses the existing `JLD2 + JSON` persistence stack rather than adding a new MAT dependency; the metadata records the recommended `.mat` interface names for downstream export if needed.

## Script-to-Script Data Flow

The formal entry script imports `Plots`, includes the generator, and calls `generate_duffing_aug_snr10_dataset(PROJECT_ROOT; profile = :formal)`. The generator samples fixed Fourier phases from `forcing_seed`, computes one global physical-amplitude factor for the multisine template, samples all trajectory initial conditions from `trajectory_seed`, integrates physical Duffing states at `2000 Hz`, anti-alias filters and decimates physical channels to `500 Hz`, evaluates forcing phase and forcing exactly on the model grid, adds 10 dB Gaussian noise only to `x` and `v` after downsampling, runs diagnostics, then writes raw-coordinate data, metadata, report tables, logs, and plots. No input/target standardization statistics are computed or stored.

## Validation Commands and Results

Formal generation passed with:

- `state_clean` shape: `[768, 2000, 2]`.
- `state_noise10` shape: `[768, 2000, 2]`.
- `forcing` shape: `[768, 2000, 1]`.
- `forcing_phase` shape: `[768, 2000, 2]`.
- Split counts: `train=512`, `val=128`, `test=128`.
- Empirical train SNR: `x=9.993356463927531 dB`, `v=9.9927816783009 dB`.
- Phase circle max error: `2.220446049250313e-16`.
- Forcing consistency max error: `1.9255708139098715e-12`.
- All finite: `true`.
- Overall diagnostics passed: `true`.

The clean and noisy time-series PNG files were generated and visually checked for the requested two-subplot layout.
