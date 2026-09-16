# Duffing Nonlinearity Basic v1 Mathematical Explanation

## Objective

`duffing_nonlinearity_basic_v1` is a compact representative object subset of
the larger `duffing_nonlinearity_matrix_v1` Duffing hardening matrix. It keeps
two linear health-check objects and five nonlinear Duffing objects ordered by
the nonlinearity index

$$
\chi_{\mathrm{nl}} = \beta Q^2 .
$$

The dataset is generated independently from the defining equations and
configuration. It is not copied or sliced from the existing matrix release.
For formal comparison, its shared generation settings are aligned with the
matrix release: the same initial-condition seed, split seed, formal trajectory
count, trajectory length, time step, solver tolerances, and high-precision
switching rule are used. Apart from `dataset_id`, release paths, and the smaller
object list, the formal Basic objects are intended to match the corresponding
Matrix objects exactly.

## State And Dynamics

Each object uses the two-dimensional state

$$
x(t) = \begin{bmatrix} q(t) \\ p(t) \end{bmatrix},
$$

where `q` is displacement and `p` is velocity. The Duffing hardening objects are
unforced and damped:

$$
\dot{q} = p,
\qquad
\dot{p} = -\delta p - \alpha q - \beta q^3 .
$$

The release fixes

$$
\alpha = 1.0,\qquad \delta = 0.08,\qquad \gamma = 0.0,
\qquad \tau = 0.01 .
$$

The physical energy used for dissipation diagnostics is

$$
E(q,p;\alpha,\beta) =
\frac{1}{2}p^2 + \frac{1}{2}\alpha q^2 + \frac{1}{4}\beta q^4 .
$$

Since \(\delta > 0\), the continuous-time system satisfies

$$
\frac{dE}{dt} = -\delta p^2 \le 0 .
$$

The generator therefore checks that the final energy does not exceed the initial
energy beyond the configured numerical tolerance.

## Linear Health Checks

The two linear objects are included before the nonlinear sequence.

| Object | Definition | Purpose |
| --- | --- | --- |
| `L0_discrete_damped_rotation` | Exact discrete damped rotation with radius `0.995` and angle `0.08`. | Checks discrete linear recurrence and tensor plumbing. |
| `L1_continuous_linear_oscillator` | Continuous damped oscillator with \(\beta=0\), integrated over \(\tau=0.01\). | Checks continuous linear flow, spectra, and recurrence. |

For `L1`, the continuous generator is

$$
A =
\begin{bmatrix}
0 & 1 \\
-\alpha & -\delta
\end{bmatrix},
\qquad
F_\tau = \exp(\tau A).
$$

## Nonlinearity-Ordered Duffing Objects

The five nonlinear objects are sorted by increasing \(\chi_{\mathrm{nl}}\).

| Order | Object | \(\beta\) | \(Q\) | \(\chi_{\mathrm{nl}}\) | Selection role |
| --- | --- | ---: | ---: | ---: | --- |
| 1 | `D_beta_0050__Q_100` | 0.05 | 1.0 | 0.05 | Weak nonlinearity |
| 2 | `D_beta_1000__Q_100` | 1.0 | 1.0 | 1.0 | Moderate nonlinearity |
| 3 | `D_beta_5000__Q_100` | 5.0 | 1.0 | 5.0 | Strong nonlinearity |
| 4 | `D_beta_10000__Q_200` | 10.0 | 2.0 | 40.0 | Very strong nonlinearity |
| 5 | `D_beta_20000__Q_400` | 20.0 | 4.0 | 320.0 | Extreme nonlinearity |

This ordering preserves representative low, medium, high, and extreme
hardening regimes while keeping the object count small enough for quick
downstream tests.

## Initial Conditions

For an amplitude level \(Q\), initial conditions are sampled from an annulus

$$
0.75Q \le \sqrt{q_0^2+p_0^2} \le Q .
$$

The radius is sampled uniformly in area over the annulus and the angle is
uniform on \([0,2\pi)\). Objects with the same amplitude level reuse the same
initial-condition library, so comparisons across \(\beta\) at fixed \(Q\) are
not confounded by different initial states.

## Observations And Targets

The release is full-state and clean:

$$
z_m = x_m,\qquad y_m = x_m .
$$

The stored arrays use the `trajectory_by_time_by_channel` layout with shape
`(R, M+1, 2)`.

## Formal Profile

The formal profile is intentionally identical to the Matrix release profile, so
Basic can be used as a strict same-configuration object subset rather than as a
smaller-data quick test.

| Quantity | Value |
| --- | ---: |
| Trajectories per object \(R\) | 512 |
| Train / validation / test split | 384 / 64 / 64 |
| Time steps \(M\) | 1024 |
| Snapshot interval \(\tau\) | 0.01 |
| Array shape per object | `(512, 1025, 2)` |
| Rollout horizons | `1, 2, 4, 8, 16, 32, 64` |

The high-nonlinearity objects use the stricter integration settings inherited
from the matrix convention when \(\chi_{\mathrm{nl}}>40\):
`reltol=1.0e-11`, `abstol=1.0e-13`, and `max_internal_step=0.0005`. The
`D_beta_10000__Q_200` object has \(\chi_{\mathrm{nl}}=40\), so it remains on
the default tolerance branch; `D_beta_20000__Q_400` has
\(\chi_{\mathrm{nl}}=320\), so it uses the stricter branch.
