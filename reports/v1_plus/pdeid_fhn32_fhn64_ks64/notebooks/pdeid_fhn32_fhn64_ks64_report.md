# PDEID FHN32/FHN64/KS64 Data Generation Report

## Objective And Scope

This report documents the completed `pdeid_fhn32_fhn64_ks64` data-generation task. The objective was to generate three complete-state, uniformly sampled, autonomous PDE-discretized datasets for downstream MP-KDSM and Koopman-style direct multi-step prediction studies. The release stores raw physical-coordinate states only; it does not include in-object standardization, normalization, or field-shared training statistics.

| Object | Model | Spatial points | State dimension | Domain | Formal shape |
| --- | --- | ---: | ---: | --- | --- |
| `fhn32` | FitzHugh-Nagumo reaction-diffusion | 32 | 64 | `[0,32)` | `[480,1025,64]` |
| `fhn64` | FitzHugh-Nagumo reaction-diffusion | 64 | 128 | `[0,32)` | `[480,1025,128]` |
| `ks64` | Kuramoto-Sivashinsky | 64 | 64 | `[0,22)` | `[480,1025,64]` |

The task follows the mathematical specification at `docs/notes/mathematical explanation/pdeid_fhn32_fhn64_ks64.md`. It only generates and validates numerical data; no downstream MP-KDSM model is trained here.

## Method And Engineering Choices

All formal objects use complete-state prediction, so `y_m = z_m`. The current trajectory protocol is `R=480`, split by full trajectories into `320/80/80`, with `M=1024`, `tau=0.25`, and rollout horizons `{1,2,4,8,16,32,64}`. The 2026-07-10 regeneration keeps the original dynamics, solver settings, sampling interval, and record length while removing dataset-level standardization semantics from code and documentation.

FHN32 and FHN64 use periodic finite differences for the diffusion term and SciML `Rodas5P()` for the method-of-lines ODE. The formal tolerances are `reltol=1e-8` and `abstol=1e-10`.

KS64 uses a Fourier pseudospectral ETDRK4 integrator with `dt=0.05`, `2/3` dealiasing, and contour-averaged ETDRK4 coefficients. During debugging, long KS trajectories developed finite-time `NaN` values unless the stepper explicitly projected each step back to a real, zero-mean, dealiased state. That projection is now part of the implementation and preserves the intended zero-mean physical state space.

## Variables And Parameters

For FHN, the state is

$$
z(t) = [u_0,\ldots,u_{N_x-1},v_0,\ldots,v_{N_x-1}]^\top.
$$

The fixed PDE parameters are `D_u=1`, `D_v=0`, `epsilon=0.08`, `a=0.7`, and `b=0.8`. Initial conditions are sampled around the resting equilibrium using one or two periodic Gaussian `u` pulses plus low-frequency smooth perturbations.

For KS, the state is the zero-mean physical grid field

$$
z(t) = [u_0,\ldots,u_{63}]^\top.
$$

The initial condition uses Hermitian Fourier modes `n=1:8`, RMS-scaled to `[0.5,1.0]`, then integrated through `T_warm=200` before recording.

## Validation Protocol

The validation separates numerical data-generation error from downstream model error. The key checks were:

| Check | Requirement | Result |
| --- | --- | --- |
| HDF5 schema/readback | Required datasets and split counts present | Passed |
| State finiteness | All saved states finite | Passed |
| Split counts | `320/80/80` per object | Passed |
| One-step time certificate | `epsilon_time_one_step <= 1e-4` | Passed for all objects |
| KS zero mean | Roundoff-scale mean drift | Passed |
| Space certificate | Record FHN64 and KS64 one-step reference gaps | Recorded |

Readback confirmed the formal HDF5 tensor shapes and metadata:

| Object | Tensor shape | Time length | Train/Val/Test | `tau` |
| --- | ---: | ---: | ---: | ---: |
| `fhn32` | `[480,1025,64]` | 1025 | `320/80/80` | 0.25 |
| `fhn64` | `[480,1025,128]` | 1025 | `320/80/80` | 0.25 |
| `ks64` | `[480,1025,64]` | 1025 | `320/80/80` | 0.25 |

## Results And Diagnostics

The formal numerical certificate produced:

| Object | State range | `epsilon_time_one_step` | Space certificate |
| --- | ---: | ---: | ---: |
| `fhn32` | `[-1.846192, 0.224752]` | `1.751643e-13` | `epsilon_fhn32_from_fhn64=2.250337e-4` |
| `fhn64` | `[-1.834584, 0.197110]` | `1.698060e-13` | `epsilon_space=5.973758e-5` |
| `ks64` | `[-3.095514, 3.093958]` | `2.544139e-7` | `epsilon_space=2.546170e-7` |

The certificate values are raw-state relative errors. No train, validation, or test split statistics are saved as reusable dataset resources.

The generated plots include FHN `u/v` heatmaps, the KS `u` heatmap, the KS time-averaged Fourier energy spectrum, and bar plots for the time and space certificates.

## Adjustment Record

The original specification expected the FHN warm-end activity check

$$
A_{\mathrm{FHN}}(T_{\mathrm{warm}}) \ge 0.5.
$$

Under the specified autonomous no-drive parameters and `T_warm=32`, a pre-formal probe found no accepted FHN32 trajectory after 120 attempts. Warm-end activity values were below `0.5`, concentrated below about `0.39`. Keeping the original threshold would have produced no FHN dataset.

The formal run therefore used:

$$
A_{\mathrm{FHN}}(T_{\mathrm{warm}}) \ge 0.35.
$$

No PDE parameter, initial-condition distribution, warm-up duration, solver tolerance, sampling interval, or record length was changed. The accepted FHN32 warm activities were approximately `0.37-0.41`; FHN64 warm activities were approximately `0.35-0.39`. During the recorded interval, however, the FHN activity can continue decaying toward a near-uniform state; the certificate records activity minima at floating-point roundoff scale and low full-record activity means. This adjustment and limitation are recorded in `data/pdeid_fhn32_fhn64_ks64_julia/numeric_certificate.json`.

## Reproducibility Notes

Run the smoke profile with:

```powershell
julia --project=. experiments\smoke_tests\run_pdeid_fhn32_fhn64_ks64_smoke.jl
```

Run the formal profile with:

```powershell
julia --project=. experiments\data_generation\generate_pdeid_fhn32_fhn64_ks64.jl
```

The formal generated data are under `data/pdeid_fhn32_fhn64_ks64_julia/`. The raw HDF5 files are intentionally ignored by git because they are generated data artifacts.

## Limitations And Next Steps

The FHN data should be interpreted as weakly active post-warm reaction-diffusion fields that relax substantially during the saved record, not as sustained high-amplitude traveling pulse data under the original `0.5` activity threshold. Downstream MP-KDSM experiments should report this when comparing FHN32 and FHN64 difficulty. KS64 is suitable for short- and medium-horizon prediction plus long-time statistics checks; pointwise long-horizon errors should be interpreted separately from statistical consistency because the object is chaotic.
