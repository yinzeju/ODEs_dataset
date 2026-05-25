# Duffing Nonlinearity Basic v1 Report

## Objective And Scope

`duffing_nonlinearity_basic_v1` provides a compact, quick-test Duffing
hardening release derived from the mathematical design of
`duffing_nonlinearity_matrix_v1` without copying or slicing its generated data.
It keeps the object sequence small: two linear health checks plus five Duffing
objects ordered by the nonlinearity index
\(\chi_{\mathrm{nl}}=\beta Q^2\).

## Implementation Method And Key Assumptions

The release uses the unforced damped hardening Duffing system

$$
\dot q = p,\qquad
\dot p = -\delta p - \alpha q - \beta q^3,
$$

with \(\alpha=1.0\), \(\delta=0.08\), and \(\tau=0.01\). Full-state clean
observations are stored as `obs_phys`, `obs_full`, and `target_phys`, all equal
to the generated state tensor.

The generator is independent for this release. It reads new
`duffing_nonlinearity_basic_v1` configs, builds a 7-object generation plan, and
writes new raw and processed JLD2 tensors. It reuses the existing Duffing
integration and diagnostic helper functions to preserve the numerical
conventions of the larger matrix release.

## Variables And Parameters

| Symbol or field | Meaning | Value or convention |
| --- | --- | --- |
| \(q\) | Displacement state | Stored in channel 1 |
| \(p\) | Velocity state | Stored in channel 2 |
| \(\alpha\) | Linear stiffness | `1.0` |
| \(\delta\) | Damping | `0.08` |
| \(\beta\) | Cubic hardening coefficient | Object-specific |
| \(Q\) | Initial-condition amplitude level | Object-specific |
| \(\chi_{\mathrm{nl}}\) | Nonlinearity index | \(\beta Q^2\) |
| \(R\) | Trajectories per object | `64` |
| \(M\) | Time steps | `512` |
| \(\tau\) | Snapshot interval | `0.01` |

## Data Provenance And Object Selection

The formal release contains these objects.

| Object | Kind | \(\beta\) | \(Q\) | \(\chi_{\mathrm{nl}}\) | Role |
| --- | --- | ---: | ---: | ---: | --- |
| `L0_discrete_damped_rotation` | Linear | 0.0 | 1.0 | 0.0 | Exact discrete recurrence health check |
| `L1_continuous_linear_oscillator` | Linear | 0.0 | 1.0 | 0.0 | Continuous linear flow health check |
| `D_beta_0050__Q_100` | Duffing | 0.05 | 1.0 | 0.05 | Weak nonlinearity |
| `D_beta_1000__Q_100` | Duffing | 1.0 | 1.0 | 1.0 | Moderate nonlinearity |
| `D_beta_5000__Q_100` | Duffing | 5.0 | 1.0 | 5.0 | Strong nonlinearity |
| `D_beta_10000__Q_200` | Duffing | 10.0 | 2.0 | 40.0 | Very strong nonlinearity |
| `D_beta_20000__Q_400` | Duffing | 20.0 | 4.0 | 320.0 | Extreme nonlinearity |

Initial conditions are generated from annuli
\(0.75Q \le \sqrt{q_0^2+p_0^2} \le Q\). Objects sharing the same \(Q\) reuse the
same initial-condition library, enabling direct comparisons across \(\beta\).

## Validation Protocol

The smoke command exercised the complete generation path with `R=8`, `M=128`,
and Split-I `6/1/1`.

```powershell
julia --project=. experiments\smoke_tests\run_duffing_nonlinearity_basic_v1_smoke.jl
```

The formal command generated the reusable release with `R=64`, `M=512`, and
Split-I `48/8/8`.

```powershell
julia --project=. experiments\data_generation\generate_duffing_nonlinearity_basic_v1_dataset.jl
```

Both commands checked tensor shape, finite values, split counts, energy
dissipation, raw/processed reload consistency, and initial-condition reuse.

## Results And Diagnostics

The formal run passed all diagnostics.

| Metric | Result |
| --- | --- |
| Object count | `7` |
| Duffing object count | `5` |
| Shape per object | `(64, 513, 2)` |
| Split-I counts | `48 / 8 / 8` |
| All object diagnostics passed | `true` |
| Initial-condition reuse passed | `true` |
| Maximum final energy violation count | `0` |
| Maximum state absolute value | `49.200843043780296` |

Key object diagnostics:

| Object | \(\chi_{\mathrm{nl}}\) | State max abs | Mean energy drop | Passed |
| --- | ---: | ---: | ---: | --- |
| `L0_discrete_damped_rotation` | 0.0 | 0.9887726061406423 | 0.815866854913913 | true |
| `L1_continuous_linear_oscillator` | 0.0 | 0.9887726061406423 | 0.12690693946905207 | true |
| `D_beta_0050__Q_100` | 0.05 | 0.9887726061406423 | 0.12850087414779485 | true |
| `D_beta_1000__Q_100` | 1.0 | 1.1200793623579994 | 0.15463436955525217 | true |
| `D_beta_5000__Q_100` | 5.0 | 1.7211293262725214 | 0.2350267088531295 | true |
| `D_beta_10000__Q_200` | 40.0 | 8.23566576548783 | 3.7267201815845237 | true |
| `D_beta_20000__Q_400` | 320.0 | 49.200843043780296 | 127.94786215674883 | true |

For one-step windows, each object has `24576` train windows, `4096` validation
windows, and `4096` test windows. For the largest rollout horizon `64`, each
object has `21552` train windows, `3592` validation windows, and `3592` test
windows.

## Interpretation

The resulting release is suitable as a quick object-level screening set before
running the full `duffing_nonlinearity_matrix_v1` matrix. The sequence preserves
a clear progression in nonlinear stiffness and amplitude stress while retaining
linear objects that should expose basic data-binding, recurrence, and full-state
identity mistakes early.

The strongest object reaches a state absolute maximum of about `49.20`, so it
is numerically more demanding than the weak and moderate objects. The stricter
integration settings for \(\chi_{\mathrm{nl}}\ge 80\) were sufficient for the
formal run: no object reported final energy growth beyond tolerance.

## Limitations And Next Steps

This release is not a dense parameter surface. It should not replace
`duffing_nonlinearity_matrix_v1` for full \((\beta,Q)\) degradation studies or
response-surface analysis. Its purpose is quick downstream testing, ordered
nonlinearity sanity checks, and early pipeline validation.

No hyperparameter or solver adjustment was made in response to unexpected
numerical failures. The chosen profile intentionally reduces trajectory count
and time horizon relative to the large matrix release to keep the release fast
to consume.
