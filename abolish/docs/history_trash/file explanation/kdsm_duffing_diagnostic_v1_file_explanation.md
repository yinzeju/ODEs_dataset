# kdsm_duffing_diagnostic_v1 File Explanation

## Task Summary

This task implemented and executed the `kdsm_duffing_diagnostic_v1` Duffing diagnostic data release for `ODEs_dataset`. The release generates D0-D9 Duffing objects for downstream KDSM diagnostic experiments without defining KDSM training, losses, learned spectra, or intervention rules.

The user explicitly requested the formal workflow without a smoke run. The formal run generated 16 processed objects with `R=64`, `M+1=2049`, `tau=0.05`, and trajectory-level Split-I counts `48/8/8`.

## Run Entry Points and Scripts

- `experiments/baseline_forecasting/kdsm_duffing_diagnostic_v1_release_generation.jl` is the formal release entry point.
- Running `julia --project=. experiments/baseline_forecasting/kdsm_duffing_diagnostic_v1_release_generation.jl` generates all D0-D9 objects, writes raw and processed tensors, writes object and release manifests, and creates CSV report tables and a generation log.

## Core Source, Configs, and Docs Changed

- `configs/systems/kdsm_duffing_diagnostic_v1_systems.toml` declares D0-D9 object parameters, forcing ids, initial-condition policies, noise ids, default observation and target modes, and release scale.
- `configs/observations/kdsm_duffing_diagnostic_v1_observations.toml` declares observation modes, target modes, noisy tensor names, and the noise scale policy.
- `configs/splits/kdsm_duffing_diagnostic_v1_split_trajectory_I.toml` freezes the formal and bounded trajectory-level split counts.
- `configs/windows/kdsm_duffing_diagnostic_v1_windows.toml`, `configs/tasks/kdsm_duffing_diagnostic_v1_tasks.toml`, `configs/benchmarks/kdsm_duffing_diagnostic_v1_benchmark.toml`, and `configs/releases/kdsm_duffing_diagnostic_v1_release.toml` provide downstream-compatible release declarations.
- `src/dynamics/kdsm_duffing_diagnostic_v1_forcing.jl` registers `force_none`, `force_harmonic_1`, `force_harmonic_2`, and optional `force_lorenz_readout`.
- `src/dynamics/kdsm_duffing_diagnostic_v1_dynamics.jl` implements the augmented autonomous Duffing vector field and fixed-step RK4 integration.
- `src/observations/kdsm_duffing_diagnostic_v1_observations.jl` builds clean observations and targets.
- `src/observations/kdsm_duffing_diagnostic_v1_noise.jl` applies seeded per-channel train-split-scaled Gaussian noise to observation and target copies.
- `src/splits/kdsm_duffing_diagnostic_v1_splits.jl` builds deterministic trajectory-level split roles.
- `src/datasets/kdsm_duffing_diagnostic_v1_dataset_objects.jl`, `src/io/kdsm_duffing_diagnostic_v1_io.jl`, `src/manifests/kdsm_duffing_diagnostic_v1_manifests.jl`, `src/registries/kdsm_duffing_diagnostic_v1_registry.jl`, and `src/diagnostics/kdsm_duffing_diagnostic_v1_data_checks.jl` handle object packing, persistence, manifests, registry checks, and data-only diagnostics.

## Generated Data, Artifacts, Reports, and Logs

Generated tensor outputs are local data artifacts and remain ignored by git:

- `data/raw/kdsm_duffing_diagnostic_v1/<object_id>/raw_trajectories.jld2`
- `data/processed/kdsm_duffing_diagnostic_v1/<object_id>/processed_tensors.jld2`
- `data/manifests/kdsm_duffing_diagnostic_v1/<object_id>/manifest.toml`
- `data/releases/kdsm_duffing_diagnostic_v1/release_manifest.toml`
- `data/releases/kdsm_duffing_diagnostic_v1/release_index.toml`

Generated report outputs:

- `reports/v1_core/kdsm_duffing_diagnostic_v1/tables/kdsm_duffing_diagnostic_v1_generation_summary.csv`
- `reports/v1_core/kdsm_duffing_diagnostic_v1/tables/kdsm_duffing_diagnostic_v1_dimension_summary.csv`
- `reports/v1_core/kdsm_duffing_diagnostic_v1/tables/kdsm_duffing_diagnostic_v1_noise_summary.csv`
- `reports/v1_core/kdsm_duffing_diagnostic_v1/logs/kdsm_duffing_diagnostic_v1_generation.log`
- `reports/v1_core/kdsm_duffing_diagnostic_v1/notebooks/kdsm_duffing_diagnostic_v1_report.md`

## Script-to-Script Data Flow

The formal entry point includes the task modules, loads the TOML configs, validates the registry, builds object specs, samples initial conditions, integrates augmented Duffing trajectories, extracts physical and forcing tensors, builds observations and targets, assigns trajectory-level split roles, applies noisy copies, writes JLD2 tensors, writes TOML manifests, and writes CSV/log summaries.

The generator preserves the required tensor orientation `channel x time x trajectory`. For `force_none`, `forcing_state` is saved with first dimension zero and `forcing_signal` is saved as a valid scalar zero tensor.

## Validation Commands and Results

Formal generation command:

```powershell
julia --project=. experiments\baseline_forecasting\kdsm_duffing_diagnostic_v1_release_generation.jl
```

Result: all 16 objects passed internal generation diagnostics.

Independent output check:

```powershell
julia --project=. -e 'using JLD2, TOML; root=pwd(); manifest=joinpath(root,"data","releases","kdsm_duffing_diagnostic_v1","release_manifest.toml"); m=TOML.parsefile(manifest); println(m["object_count"])'
```

Key validation evidence:

- Release manifest object count: `16`.
- D0 `forcing_state` shape: `(0, 2049, 64)`.
- D6 `state_aug` shape: `(6, 2049, 64)`.
- D8 `target_poly9` shape: `(9, 2049, 64)`.
- D9 clean/noisy `state_aug` max difference: `0.0`.
- D9 `noise_1em2` augmented-observation noise RMS: about `0.006138679327101577`.

No smoke script was created or run because the user requested direct formal generation.
