# Standard_ODEs_v1 File Explanation

The release stores clean states, clean/noisy observations, and clean targets in unstandardized physical coordinates. JLD2 objects and manifests declare `normalization_policy = none_raw_physical_coordinates`; no mean, standard deviation, normalized tensor, or normalizer object is generated.

## Task Summary

This task created the `lowdim_nonlinear_v1` Float32 dataset release from eight common ODE objects: three linear systems, two Duffing nonlinearity cells, Lorenz63, Rossler, and the Lusch-aligned nonlinear pendulum. Each object stores clean full-state observations plus 5 dB and 15 dB additive Gaussian noisy observation versions. The default target is the clean state.

The release excludes `jordan_nonnormal_linear`.

## Run Entry Points And Scripts

- `experiments/smoke_tests/run_lowdim_nonlinear_v1_smoke.jl` generates a small smoke dataset under `runs/smoke_tests/lowdim_nonlinear_v1/`.
- `experiments/data_generation/generate_lowdim_nonlinear_v1_dataset.jl` generates the formal Float32 dataset under `data/processed/lowdim_nonlinear_v1/`.
- `src/data/lowdim_nonlinear_v1_generation.jl` contains the object specs, initial-condition sampling, analytic linear propagation, local adaptive Dormand-Prince 5(4) integration for Duffing and chaotic systems, noise generation, validation summaries, JLD2 writes, and manifest writes.

## Core Source, Configs, And Docs Changed

- `docs/notes/mathematical explanation/lowdim_nonlinear_v1_math.md` defines the aggregate dataset, object list, formal ML profile, SNR noise model, high-precision integration policy, and validation requirements.
- `src/data/lowdim_nonlinear_v1_generation.jl` implements the generator.
- `experiments/smoke_tests/run_lowdim_nonlinear_v1_smoke.jl` and `experiments/data_generation/generate_lowdim_nonlinear_v1_dataset.jl` are the executable entry points.

No existing source generator was rewritten for this release.

## Generated Data, Artifacts, Reports, And Logs

Formal processed JLD2 outputs:

- `data/processed/lowdim_nonlinear_v1/linear_diagonal/processed_tensors.jld2`
- `data/processed/lowdim_nonlinear_v1/linear_rotation_contraction_2d/processed_tensors.jld2`
- `data/processed/lowdim_nonlinear_v1/damped_linear_oscillator/processed_tensors.jld2`
- `data/processed/lowdim_nonlinear_v1/duffing_chi40_medium/processed_tensors.jld2`
- `data/processed/lowdim_nonlinear_v1/duffing_chi320_strong/processed_tensors.jld2`
- `data/processed/lowdim_nonlinear_v1/lorenz63_standard/processed_tensors.jld2`
- `data/processed/lowdim_nonlinear_v1/rossler_standard/processed_tensors.jld2`
- `data/processed/lowdim_nonlinear_v1/nonlinear_pendulum_lusch2018/processed_tensors.jld2`

Release metadata and summaries:

- `data/releases/lowdim_nonlinear_v1/metadata/release_manifest.json`
- `data/manifests/lowdim_nonlinear_v1/<object_id>/manifest.json`
- `reports/v1_core/lowdim_nonlinear_v1/tables/generation_summary.csv`
- `reports/v1_core/lowdim_nonlinear_v1/logs/generation.log`

Smoke outputs:

- `runs/smoke_tests/lowdim_nonlinear_v1/release_manifest.json`
- `runs/smoke_tests/lowdim_nonlinear_v1/summary.csv`
- `runs/smoke_tests/lowdim_nonlinear_v1/<object_id>/processed_tensors.jld2`

Generated run data are ignored by Git under the project `.gitignore`.

## Script-To-Script Data Flow

The smoke and formal scripts both include `src/data/lowdim_nonlinear_v1_generation.jl`. Each object follows this flow:

1. Build the object specification.
2. Sample initial conditions.
3. Generate clean state trajectories in Float64.
4. Convert state, clean observation, noisy observations, and clean target to Float32.
5. Compute train-split channel-wise signal power and add 5 dB / 15 dB Gaussian observation noise.
6. Save a JLD2 file with `state_clean`, `observation_clean`, `observation_noise_5db`, `observation_noise_15db`, `target_clean`, `time_grid`, `initial_conditions`, `split_roles`, and metadata.
7. Write object manifest and aggregate release manifest.

## Validation Commands And Results

Parse check:

```powershell
julia --project=. -e 'Meta.parseall(read("src/data/lowdim_nonlinear_v1_generation.jl", String)); Meta.parseall(read("experiments/smoke_tests/run_lowdim_nonlinear_v1_smoke.jl", String)); Meta.parseall(read("experiments/data_generation/generate_lowdim_nonlinear_v1_dataset.jl", String)); println("parse ok")'
```

Result: `parse ok`.

Smoke command:

```powershell
julia --project=. experiments/smoke_tests/run_lowdim_nonlinear_v1_smoke.jl
```

Result: generated all eight smoke objects with `all_passed=true`.

Formal command:

```powershell
julia --project=. experiments/data_generation/generate_lowdim_nonlinear_v1_dataset.jl
```

Result: generated all eight formal objects with `all_passed=true`.

Formal summary:

| Object | Shape | Train one-step pairs | Max abs state | Finite |
| --- | --- | ---: | ---: | --- |
| `linear_diagonal` | `(512, 1025, 4)` | 393216 | 167.122743 | true |
| `linear_rotation_contraction_2d` | `(512, 2049, 2)` | 786432 | 1.980349 | true |
| `damped_linear_oscillator` | `(512, 3001, 2)` | 1152000 | 2.713434 | true |
| `duffing_chi40_medium` | `(512, 2049, 2)` | 786432 | 8.940973 | true |
| `duffing_chi320_strong` | `(512, 2049, 2)` | 786432 | 49.611611 | true |
| `lorenz63_standard` | `(512, 4097, 3)` | 1572864 | 47.248772 | true |
| `rossler_standard` | `(512, 4097, 3)` | 1572864 | 22.851357 | true |
| `nonlinear_pendulum_lusch2018` | `(8192, 51, 2)` | 307200 | 2.995286 | true |

Aggregate totals:

- State vectors: `9,821,696`.
- Train one-step pairs per observation mode: `7,357,440`.
- Saved formal JLD2 size: about `475 MiB`.
- Example reload check on `lorenz63_standard`: `state_clean` has shape `(512, 4097, 3)` and element type `Float32`; `observation_noise_5db` has the same shape.
