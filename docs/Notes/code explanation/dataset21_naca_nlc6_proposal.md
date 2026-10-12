# NACA-NLC6 mathematical model and parameter proposal

Status: proposal only. No new time integration or formal experiment is authorized.
The earlier v3_partial campaign and its heartbeat are paused. Three complete
trajectories and an interrupted fourth file remain preserved. This document
defines a distinct mechanical benchmark, not a reproduction of the unchanged
SSMTool wing. Values are engineering design choices, not measured connector data.

The prior user notebook, Dataset-2.1-Wing and Blade Structural Dynamics.md,
provides the original shell, root clamp, material and full-state conventions.
The user explicitly requested this nonlinear-connector redesign in the chat.

## Mechanical state and equations

Retain the candidate mesh, all 14922 independent mechanical coordinates,
consistent mass matrix and original geometric nonlinear force. There is no modal
truncation. The six connectors are massless, algebraic and without memory:

\[
\mathbf x=\operatorname{col}(\mathbf q,\mathbf v)\in\mathbb R^{29844},\qquad
\mathbf s=\mathbf B^\top\mathbf q,\quad\mathbf w=\mathbf B^\top\mathbf v.
\]

\[
\mathbf M\ddot{\mathbf q}+\mathbf C_0\dot{\mathbf q}+\mathbf K_0\mathbf q
+\mathbf f_{\rm geo}(\mathbf q)
+\mathbf B\left[\boldsymbol\kappa\odot\mathbf s^{\odot3}
+\mathbf d(\mathbf w)\right]=\mathbf0.
\]

For connector j, with extension s_j in metres and velocity w_j in m/s:

\[
d_j(w_j)=c_{\infty j}\frac{w_j^3}{w_j^2+v_{s,j}^2},\qquad
\kappa_j>0,\quad c_{\infty j}>0,\quad v_{s,j}>0.
\]

The elastic force is exactly cubic. The damper is smooth, cubic near zero and
bounded in secant damping: 0 <= d_j(w)/w < c_infinity_j. The saturation is a
modeling choice intended to avoid excessive high-speed dissipation; it is not a
claim that every mode will exhibit strong nonlinear damping.
Gravity, rotation, ongoing external forcing and added noise remain absent.

## Connection geometry and force distribution

Reference axes are X=chord, Y=normal and Z=span, with span 5 m and chord about 1 m.
Use four skin patches centered at (X,Z)=(0.20,3.0), (0.80,3.0),
(0.20,4.5), (0.80,4.5) m. Each patch has half-widths (0.10,0.12) m in X and Z
and includes both skin faces. Each current-mesh patch contains 18 nodes.

Weights are positive lumped skin areas (each incident skin triangle contributes
one third of its reference area), normalized separately over each patch. All
weights are frozen in the reference configuration. Let u_F and u_R be weighted
mean displacements of the front and rear patches at one span station.

The columns of B define:

1. Mid-span normal mean: s_1=(u_F,Y+u_R,Y)/2 at Z=3.0 m.
2. Outer-span normal mean: s_2=(u_F,Y+u_R,Y)/2 at Z=4.5 m.
3. Mid-span normal difference: s_3=u_R,Y-u_F,Y at Z=3.0 m.
4. Outer-span normal difference: s_4=u_R,Y-u_F,Y at Z=4.5 m.
5. Mid-span chordwise mean: s_5=(u_F,X+u_R,X)/2 at Z=3.0 m.
6. Outer-span chordwise mean: s_6=(u_F,X+u_R,X)/2 at Z=4.5 m.

Mean ports connect to a stationary support fixture. Difference ports apply
equal-and-opposite distributed forces to front/rear patches. Work-conjugate force
distribution is B times the six scalar connector forces. No rigid patch tying,
new inertia, extra nodes, or new dynamic coordinates are introduced. These are
fixed-direction generalized spring-damper laws, not axial springs whose direction
follows current endpoint geometry. The original shell remains geometrically nonlinear.

An initial normal-only four-port design was rejected: its projection on mode 2
was nearly zero and six of 33 algebraic strain checks failed. Adding two chordwise
ports resolves that coverage defect. The rejected calibration is retained.

## Coefficient calibration

With the other ports unloaded, define the linear port stiffness by

\[
k_j^{\rm ref}=\left(\mathbf b_j^\top\mathbf K_0^{-1}\mathbf b_j\right)^{-1},
\qquad\kappa_j=k_j^{\rm ref}/s_{{\rm ref},j}^2.
\]

Use s_ref=(2,2,1,1,2,2) mm. For damping caps use
c_infinity_j=2 zeta_c k_ref_j / omega_carrier_j, where zeta_c=0.0005
and the carriers are (omega_1,omega_1,omega_4,omega_4,omega_2,omega_2).
This is a reference calibration, not the actual damping ratio of each coupled mode.

| Port | Cubic stiffness, N/m^3 | Damping cap, N s/m | Velocity scale, m/s |
| --- | ---: | ---: | ---: |
| 1 | 1.30807452365e10 | 1.77569805453 | 0.020 |
| 2 | 3.79728994587e9 | 0.515478303982 | 0.030 |
| 3 | 5.15697107058e11 | 1.65851784277 | 0.050 |
| 4 | 3.44558019709e11 | 1.10812260867 | 0.070 |
| 5 | 3.44459506974e11 | 9.04199117035 | 0.060 |
| 6 | 1.03980478955e11 | 2.72946617400 | 0.090 |

All six laws and coefficients are fixed across the population. Only initial
states vary. The complete numeric values and patch weights are in
`configs/designs/dataset21_naca_nlc6_proposal.json`, with execution disabled.

## Passivity, stiffness and solver derivatives

\[
E=\tfrac12\mathbf v^\top\mathbf M\mathbf v+
\tfrac12\mathbf q^\top\mathbf K_0\mathbf q+V_{\rm geo}(\mathbf q)
+\sum_{j=1}^6\tfrac14\kappa_js_j^4,
\]

\[
\dot E=-\mathbf v^\top\mathbf C_0\mathbf v
-\sum_{j=1}^6c_{\infty j}\frac{w_j^4}{w_j^2+v_{s,j}^2}\le0.
\]

Added energy is nonnegative. This proves dissipation of this proposed autonomous
model; it does not prove a particular terminal energy ratio or nonlinear signal.
Accumulated dissipation is a diagnostic quadrature, not a hidden constitutive state.

\[
D_{\mathbf q}\mathbf f_s=\mathbf B\operatorname{diag}(3\kappa_js_j^2)\mathbf B^\top,
\]
\[
D_{\mathbf v}\mathbf f_d=\mathbf B\operatorname{diag}\!\left(
c_{\infty j}\frac{w_j^2(w_j^2+3v_{s,j}^2)}{(w_j^2+v_{s,j}^2)^2}
\right)\mathbf B^\top.
\]

Both added tangents are positive semidefinite and rank at most six. They vanish
at the zero state, so the original undamped small-amplitude spectrum is retained.
At finite amplitude the spectrum changes. Julia integration must add these forces
to every Radau stage, use both tangents in its coupled Newton matrix, add the
quartic potential, and integrate the nonlinear damping power at internal stages.
The cached linear factorization may serve chord iteration, not replace the exact
residual or required nonlinear correction. The original FE kernels can still use
the GPU; the six scalar constitutive laws do not require GPU execution.

## Proposed sampling and baseline damping

Keep 4096 frames including t=0 and propose dt=0.0005 s, giving T=2.0475 s.
This is a changed output interval relative to v3_partial. It must be checked
against the actual nonlinear spectrum; 24 samples/cycle corresponds to an
effective-band limit of 83.333 Hz, not the Nyquist limit. Significant higher
harmonics can require a smaller output interval and a coordinated duration/damping
revision. No bandwidth acceptance is claimed by this proposal.

Use C_0=a_M M+a_K K_0, targeting zeta_1=1.0% and zeta_4=0.12%:

- a_M=0.5879008847043158 /s.
- a_K=1.6378470960752408e-6 s.
- Resulting first-four damping ratios: 1.0000%, 0.20538%, 0.17672%, 0.1200%.

This replaces the old first-two-mode 0.6% setting in the proposal only. It keeps
the low-frequency decay substantial over the shorter record while avoiding rapid
high-mode damping. Linear energy-envelope estimates at T are 29.9%, 27.8%, 26.9%,
and 21.7%. These are estimates, not guarantees for the modified nonlinear model.
The actual terminal-energy target remains <=40%.

Proposed solver: full-state Float64 Radau IIA5, initially two internal substeps,
first 0.05 s refined by another factor of 32, scaled Newton tolerance 1e-13,
full-state temporal-refinement and energy-balance targets 1e-4, and the unchanged
recovered-strain screen 0.001. These settings are pending engineering tests.

## Initial conditions and the 144-trajectory population

Retain 12 families: four single original modes, all six pairs, one four-mode
mixture, and nonlinear static release. Modes construct initial shapes only.
Every state thereafter evolves under the complete mechanical equations.
Initial velocities remain zero. Mass-normalize modes and use coefficients
proportional to sign_i sqrt(p_i)/omega_i, so p_i sets initial linear modal-energy
fractions before common rescaling. Pair fractions use 0.25/0.50/0.75; four-mode
fractions use permuted (0.1,0.2,0.3,0.4) with 10% jitter and renormalization.
Use both signs. Freeze an independent seed and all parameters before population.

Replace common millimetre bands with the connector-energy ratio

\[
R_s(\mathbf q_0)=
\frac{\sum_j\kappa_j(\mathbf b_j^\top\mathbf q_0)^4/4}
{\mathbf q_0^\top\mathbf K_0\mathbf q_0/2}
\in\{0.025,0.10,0.25\},
\]

with predeclared 10% relative jitter. For a fixed nonzero shape q_hat with
nonzero port response, the exact algebraic scale is

\[
a=\sqrt{R_s\,V_2(\hat{\mathbf q})/V_4(\hat{\mathbf q})},\qquad
\mathbf q_0=a\hat{\mathbf q}.
\]

This fixes added initial potential energy, not observed waveform error. The
directional added-to-linear restoring-force ratio is exactly 2 R_s along q_0.
Initial strain is checked separately. An inadmissible shape is reported, not
silently assigned a smaller nonlinear target. Static-release cases require the
new nonlinear equilibrium K_0 q+f_geo(q)+B(kappa*s^3)=F p, with the same outer-skin
preload geometry and both signs; find the target energy ratio on that branch and
remove the preload. This new equilibrium construction has not yet been executed.

| Split | Low R_s | Middle R_s | High R_s | Total |
| --- | ---: | ---: | ---: | ---: |
| Train | 16 | 40 | 40 | 96 |
| Validation | 4 | 10 | 10 | 24 |
| Test | 4 | 10 | 10 | 24 |
| Total | 24 | 60 | 60 | 144 |

Every family has 12 trajectories (8/2/2), with 2 low, 5 middle and 5 high targets.
The draft JSON contains the exact compatible integer allocation matrices.

## Evidence and next authorized step

Only CPU linear compliance, port rank/positivity, and initial-state algebra were
computed. The six-port operator has rank six; all 33 representative modal
initial-state checks passed the initial strain screen. Their largest strain was
about 6.64e-4. These samples do not cover every sign, mixture, jitter or static
state, and do not establish dynamic strain validity or temporal accuracy.

The draft coefficients should next be checked on a small number of representative
trajectories on this same candidate mesh, after authorization. Compare the full
model with its linear tangent and with a version omitting only nonlinear damping.
Measure position and velocity differences separately in declared physical
observables, amplitude-dependent frequency, and the duration of the nonlinear
signal. Initial R_s alone is not sufficient. Proposed observational targets are
5%/10% linear-baseline differences for middle/high tiers and persistence over a
substantial part of the record; these are engineering design targets, not claims
or universal standards. Do not recreate the deleted fine-grid campaigns.

No full generator modification, nonlinear trajectory, final sampling choice,
all-population initial-state certification, report, commit or new release has
been completed by this proposal. Await the user's implementation/run instruction.

References for the general modeling concepts (not these proposed coefficients):
[spring-damper theory](https://doc.comsol.com/6.3/doc/com.comsol.help.sme/sme_ug_theory.06.069.html),
[Rayleigh damping](https://doc.comsol.com/6.3/doc/com.comsol.help.sme/sme_ug_modeling.05.126.html).
