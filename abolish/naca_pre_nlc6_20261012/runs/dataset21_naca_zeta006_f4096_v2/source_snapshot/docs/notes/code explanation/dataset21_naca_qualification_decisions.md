# NACA qualification decisions before population generation

Status: engineering decisions awaiting independent numerical qualification.
No formal population is accepted by this document alone.

## Fixed user constraints

The formal model has at most 30,000 physical states, including every independent
displacement and velocity. Keep the pinned shell formulation, topology, materials,
0.6% first-two-mode Rayleigh damping, zero initial velocities, no forcing or noise,
4096 frames and the 96/24/24 population. Reference meshes may be larger because
they are numerical qualification resources, not learning data.

## Time integration repair

Average-acceleration Newmark at 4/8 internal steps per output interval produced
full-state discrepancies near 0.0048, concentrated at the first saved velocity
frame. Tightening its scaled Newton tolerance from 1e-11 to 1e-13 improved energy
balance but did not remove that initial-layer discrepancy. Failed receipts remain
under `runs/dataset21_naca_zeta006_f4096_v1_r5` and `runs/naca_precision_r6`.

Evaluate fifth-order, L-stable Radau IIA collocation of the same full mechanical
equations. Its complex basis transform acts only on the three time stages. It
does not transform or truncate mechanical coordinates. One real and one complex
sparse factorization accelerate chord iteration; the exact coupled stage tangent
is available when chord convergence fails. Retain Float64 physical q/v output,
full-state time refinement at 1e-4, mechanical energy balance at 1e-4 and independent
CPU/GPU comparisons. A first Radau check with four startup intervals showed its
remaining discrepancy immediately after that short refinement window ended.
Refine the first 64 output intervals internally by another factor of 32 to resolve
the fast initial layer; no frames or transients are removed.
The same physical startup duration applies to double-rate output.

Method references: [Hairer and Wanner](https://www.unige.ch/~hairer/preprints/coimbra.html)
and [SciML FIRK documentation](https://docs.sciml.ai/OrdinaryDiffEq/stable/implicit/FIRK/).

## Spatial assessment consistent with the supplied note

The note proposes approximately 2-3% modal-frequency screening and separately
requires mode shapes, compliance, phase, envelopes and nonlinear-mechanism
convergence. The first code version instead imposed a single 5% maximum
same-clock trajectory difference over the entire record. That additional
engineering default is incompatible with even sub-percent frequency differences
after many cycles. It is retained as a reported diagnostic, not mislabeled as
passed or used to equate the coarse model with the fine model.

The revised assessment freezes separate tests before formal generation:

- First four frequency differences <= 3%, MAC >= 0.95, static compliance
  difference <= 5%, and initial physical shape mismatch <= 5%.
- Phase-rate differences <= 3%. Fit unwrapped phase from each matched modal q/v
  pair with amplitude-squared weights, using samples above 10% of its peak radius.
  Also report the maximum active cumulative phase difference in radians.
- Relative differences <= 5% in the four matched q-v phase-plane envelopes,
  `sqrt(eta^2 + (eta_dot/omega)^2)` expressed in physical displacement units.
- Absolute differences <= 0.05 between normalized total mechanical-energy curves.
- A resolved dynamic nonlinear-energy-transfer signal: subtract the corresponding
  linear reference's modal energies from the nonlinear trajectory, normalize by
  nonlinear initial mechanical energy, and include energy outside the four matched
  modes as a fifth channel. Average over one period of the highest of the four
  initialized modes, using the same physical window on both meshes. This separates
  energy-transfer envelopes from carrier oscillations. Require a signal >= 0.01
  and at least five times its measured grid/time error. Also retain the >= 0.01
  nonlinear-versus-linear full-state exposure gate.

All these quantities are diagnostics extracted from complete q/v histories;
they do not replace the learner state or the full-state temporal-accuracy test.
Only spatially tested cases contribute to the nonlinear signal acceptance test.
Raw same-clock state errors and cumulative phase drift are always preserved.
A qualified coarse resource is not a claim of 5% pointwise agreement with the
original fine model over the full record.

## Initial conditions and qualification coverage

Transfer modal initial conditions using the same physical coefficients in
MAC-matched complete FE mode shapes, including all their rotational components.
For static release, solve each grid's own nonlinear static equilibrium using the
same preload shape and target physical displacement amplitude. Verify the common
physical initial shape. Piecewise-linear interpolation of all six nodal values
does not reproduce the shell's internal interpolation and can create artificial
fine-grid strain; it is no longer used to initialize reference trajectories.

Use five independent cases: small and finite mode 1, finite mode 4, finite mixed
modes 1-4, and finite static release. All receive full-duration time, strain,
energy and output-band checks. The finite mode-4 and mixed cases additionally run
on both finer grids, including their independent linear references. This follows
the note's instruction to use a small independent spatial QUAL population.

The proposed maximum offered qualification amplitude is 0.006 m, with formal
centers 0.15/0.40/0.70 of that value and the predeclared 8% jitter. This is a tested
resource envelope, not a measured aluminium yield limit. The recovered-strain
screen remains 0.001 and must pass dynamically; no large-amplitude or material
claim follows merely from an initial-state screen.

## Evidence boundary

Qualification requires measured results from both finer meshes, full-state time
refinement, spectral checks and all frozen gates. Any subsequent failure must
remain visible and be diagnosed. Formal data, completion reports, publication and
shutdown remain conditional on successful qualification, population generation
and complete readback.
