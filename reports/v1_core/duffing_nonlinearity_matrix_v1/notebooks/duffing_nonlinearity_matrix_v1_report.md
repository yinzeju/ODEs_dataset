# Duffing Nonlinearity Matrix v1 Engineering Report

## Objective And Scope

`duffing_nonlinearity_matrix_v1` implements the data-only Duffing task matrix specified in `docs/notes/mathematical explanation/duffing_nonlinearity_matrix_v1_math.md`. The release is intended to test whether downstream rollout, phase, spectral, and conditioning diagnostics degrade systematically as the effective Duffing nonlinearity scale

$$
\chi_{\mathrm{nl}} = \beta Q^2
$$

increases under sufficient trajectory-level data.

This task generated the full 40-cell Duffing matrix and the two requested linear health checks:

$$
\texttt{L0} \to \texttt{L1} \to \texttt{Duffing } \beta=0 \to \texttt{Duffing }(\beta,Q)\text{ matrix}.
$$

No learner, loss, Koopman model, rollout metric computation, or training workflow is included in this dataset-side release.

## Implementation Method And Key Assumptions

All generated objects use the tensor layout `trajectory_by_time_by_channel`:

$$
\mathcal X_{\mathrm{phys}},\ \mathcal Z^{\mathrm{phys}},\ \mathcal Y^{\mathrm{phys}}
\in \mathbb R^{512 \times 1025 \times 2}.
$$

The physical state is

$$
x_{\mathrm{phys}} = (q,p)^\top,
$$

and the clean full-state observation protocol is

$$
\texttt{obs\_phys}=\texttt{obs\_full}=\texttt{target\_phys}=\mathcal X_{\mathrm{phys}}.
$$

The Duffing cells solve

$$
\dot q=p,\qquad
\dot p=-0.08p-q-\beta q^3.
$$

The formal run used a project-local embedded Dormand-Prince 5(4) adaptive solver with the requested high-precision tolerances:

$$
\mathrm{reltol}=10^{-10},\qquad
\mathrm{abstol}=10^{-12},\qquad
\Delta t_{\max}=0.002=\tau/5.
$$

This kept the release self-contained without adding a large new solver dependency. The solver choice was made before running the formal generation and was not a result-driven adjustment.

The two linear base objects are:

| Object | Method | Purpose |
| --- | --- | --- |
| `L0_discrete_damped_rotation` | Exact discrete rotation-contraction with `r=0.995`, `omega=0.08` | Isolate discrete linear data plumbing |
| `L1_continuous_linear_oscillator` | Adaptive continuous integration of the linear oscillator plus true matrix/spectrum metadata | Isolate continuous ODE sampling |

For the base objects, the generator uses the same shell-sampling policy at `Q=1.0` so their tensors match the formal release scale. The Duffing matrix itself uses the exact five `Q` levels from the mathematical note.

## Variables And Parameters

The fixed physical parameters are:

| Symbol | Meaning | Value |
| --- | --- | --- |
| `alpha` | linear stiffness | `1.0` |
| `delta` | damping | `0.08` |
| `gamma` | forcing amplitude | `0.0` |
| `tau` | sampling interval | `0.01` |
| `M` | one-step intervals per trajectory | `1024` |
| `R` | trajectories per object | `512` |

The Duffing matrix grid is:

$$
\beta\in\{0,\ 0.05,\ 0.2,\ 0.5,\ 1,\ 2,\ 5,\ 10\},
$$

$$
Q\in\{0.25,\ 0.5,\ 1.0,\ 1.5,\ 2.0\}.
$$

The resulting nonlinearity scale covers

$$
\chi_{\mathrm{nl}}\in[0,40].
$$

The strongest generated cell is `D_beta_10000__Q_200`, with `beta=10.0`, `Q=2.0`, and `chi_nl=40.0`.

## Data Provenance And Split Protocol

Initial conditions are sampled by the shell rule from the mathematical note:

$$
q_0=a\cos\theta,\qquad p_0=a\sin\theta,
$$

$$
a=\sqrt{(0.75Q)^2+u(Q^2-(0.75Q)^2)}.
$$

For each fixed `Q`, the same initial-condition library is reused for every `beta`, so beta-direction comparisons are not confounded by initial-condition changes.

The split is performed at the trajectory level before any one-step pairs or rollout windows are counted:

| Split | Count |
| --- | ---: |
| train | 384 |
| val | 64 |
| test | 64 |

The declared rollout horizons are:

$$
\mathcal H_{\mathrm{eval}}=\{1,2,4,8,16,32,64\}.
$$

## Validation Protocol

The formal command was:

```text
$env:JULIA_NUM_THREADS='auto'; julia --project=. experiments/data_generation/generate_duffing_nonlinearity_matrix_v1_dataset.jl
```

Validation checks included tensor shapes, finite-value checks, trajectory-level split counts, final Duffing energy trend checks, raw/processed JLD2 reload consistency, identity checks for observation and target tensors, true recurrence residual checks for linear objects, shared initial-condition reuse checks, and object/release checksums.

## Results And Diagnostics

The formal generation completed successfully on 2026-05-24.

| Quantity | Result |
| --- | ---: |
| Total objects | 42 |
| Duffing cells | 40 |
| Shape per object | `(512, 1025, 2)` |
| Split counts | `384/64/64` |
| `chi_nl` range over Duffing cells | `[0, 40]` |
| Maximum state absolute value | `8.81383143591368` |
| Maximum energy violation count | `0` |
| Maximum linear recurrence residual | `6.66133814775094e-16` |
| Initial-condition reuse across beta | passed |
| Release `all_passed` flag | `true` |

Representative Duffing cells:

| Object | beta | Q | chi_nl | state_abs_max | mean_energy_drop | passed |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `D_beta_0000__Q_100` | 0.0 | 1.0 | 0.0 | 0.9986423193821249 | 0.21871132202527832 | true |
| `D_beta_1000__Q_200` | 1.0 | 2.0 | 4.0 | 3.2672215103927207 | 1.5133868960721972 | true |
| `D_beta_5000__Q_200` | 5.0 | 2.0 | 20.0 | 6.348931317643773 | 3.94806062500673 | true |
| `D_beta_10000__Q_200` | 10.0 | 2.0 | 40.0 | 8.813831435913675 | 6.9645380400398516 | true |

The generated local outputs are:

- `data/releases/duffing_nonlinearity_matrix_v1/duffing_nonlinearity_matrix_v1_manifest.toml`
- `data/releases/duffing_nonlinearity_matrix_v1/release_index.toml`
- `data/releases/duffing_nonlinearity_matrix_v1/checksums.toml`
- `reports/v1_core/duffing_nonlinearity_matrix_v1/tables/duffing_nonlinearity_matrix_v1_object_summary.csv`
- `reports/v1_core/duffing_nonlinearity_matrix_v1/tables/duffing_nonlinearity_matrix_v1_duffing_matrix_summary.csv`
- `reports/v1_core/duffing_nonlinearity_matrix_v1/logs/duffing_nonlinearity_matrix_v1_generation.log`

## Interpretation

The release now provides a dense Duffing nonlinearity grid where each cell has

$$
384\times1024=393216
$$

training one-step pairs. This scale is intended to reduce sample scarcity as an explanation for downstream rollout degradation. Because all objects share the same clean full-state observation protocol and all `beta` values reuse the same initial-condition library for a fixed `Q`, downstream changes along `beta`, `Q`, or `chi_nl` can be attributed more directly to the Duffing nonlinearity and amplitude-induced frequency drift.

The zero energy-violation count confirms that the generated continuous Duffing trajectories preserve the expected dissipative trend at the requested validation tolerance. The near machine-precision recurrence residuals on the linear objects confirm that the discrete and continuous linear health checks are numerically consistent with their recorded true matrices.

## Limitations And Next Steps

This release contains clean, unforced, full-state data only. It does not include noisy observations, forced Duffing variants, partial observations, learned model diagnostics, or downstream error surfaces. The next manual step is for downstream learning code to consume the release and compute the intended metrics over the `(beta,Q)` grid, especially `h16`, `h32`, `h64`, Koopman residuals, reconstruction errors, phase diagnostics, spectral diagnostics, and Gram conditioning.
