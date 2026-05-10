# kdsm_duffing_diagnostic_v1 Engineering Report

## Objective and Scope

This report documents the `kdsm_duffing_diagnostic_v1` data release generated in `ODEs_dataset` for downstream KDSM Duffing diagnostic experiments. It follows the mathematical definition in `docs/notes/mathematical explanation/kdsm_duffing_diagnostic_v1_math.md` and the implementation plan in `docs/notes/code explanation/kdsm_duffing_diagnostic_v1_plan.md`.

The release is a data-generation artifact only. It does not train KDSM, compute learned Koopman spectra, evaluate interventions, or interpret diagnostic success.

## Implementation Method and Key Assumptions

Each Duffing object is generated as an autonomous augmented ODE

$$
\dot q=p,\qquad
\dot p=-\delta p-\alpha q-\beta q^3+\gamma A_\nu(u),\qquad
\dot u=h_\nu(u).
$$

The implementation uses fixed-step RK4 with sample step `tau=0.05`. This keeps the project dependency footprint unchanged and matches existing ODEs_dataset fixed-step generators. The formal scale is `R=64` trajectories and `M+1=2049` sampled states per object.

The mathematical note does not specify a physical initial-condition box for D6. The implementation uses the same physical box as D5, `(q_0,p_0) in [-1,1] x [-1,1]`, while using the D6 two-frequency forcing parameters exactly as specified. This is a minimal engineering choice needed to make D6 runnable and comparable to the periodic forced object.

## Variables and Parameters

The physical state is `state_phys = (q,p)` with dimension 2. The augmented state is `state_aug = (q,p,u)` with dimension `2+d_u`.

Forcing ids and dimensions:

- `force_none`: `d_u=0`, `A_\nu(u)=0`.
- `force_harmonic_1`: `d_u=2`, `u=(c,s)`, `A_\nu(u)=c`.
- `force_harmonic_2`: `d_u=4`, `u=(c_1,s_1,c_2,s_2)`, `A_\nu(u)=c_1+\eta c_2`.
- `force_lorenz_readout`: registered as optional, `d_u=3`, with bounded readout `tanh(u_1/s_L)`.

The release stores `observation_aug`, `observation_phys`, `target_phys`, `target_aug`, `target_poly9`, and `target_energy5`. The polynomial target is

$$
(q,p,q^2,qp,p^2,q^3,q^2p,qp^2,p^3),
$$

and the energy target is

$$
\left(q,p,\frac12p^2,\frac{\alpha}{2}q^2+\frac{\beta}{4}q^4,\frac12p^2+\frac{\alpha}{2}q^2+\frac{\beta}{4}q^4\right).
$$

## Data Provenance and Split Protocol

All trajectories are generated locally from deterministic configs and seeded initial-condition sampling. Split-I assigns full trajectories to train, validation, or test before any downstream windowing. The formal split counts are `48/8/8`.

Noise is applied only to copied observation and target tensors:

$$
z_{m,\sigma}=z_m+\sigma D_z\epsilon_m,\qquad \epsilon_m\sim\mathcal N(0,I).
$$

The scale matrix `D_z` is represented by per-channel training-split standard deviations and is saved in each processed object metadata. Clean ground-truth tensors remain unchanged.

## Validation Protocol

The formal command was run directly per user request:

```powershell
julia --project=. experiments\baseline_forecasting\kdsm_duffing_diagnostic_v1_release_generation.jl
```

The generator checked tensor dimensions, finite values, clean observation equality, clean target equality, harmonic forcing radius diagnostics, split counts, target dimensions, and noisy tensor shapes.

An independent output check parsed the release manifest and loaded representative processed tensors:

- `manifest_object_count=16`
- D0 `forcing_state` size `(0, 2049, 64)`
- D6 `state_aug` size `(6, 2049, 64)`
- D8 `target_poly9` size `(9, 2049, 64)`
- D9 clean/noisy `state_aug` max difference `0.0`
- D9 `noise_1em2` augmented-observation noise RMS about `0.006138679327101577`

## Results and Diagnostics

All 16 objects were generated successfully:

- D0-D3 use unforced Duffing objects with physical observations by default.
- D4, D5, D7, D8, and D9 use single-frequency autonomous harmonic forcing.
- D6 uses two-frequency autonomous harmonic forcing with augmented state dimension 6.
- D8 stores the required 9-dimensional `target_poly9`.
- D9 noise-scan objects share the same clean generated state across noise levels and differ only in noisy observation and target copies.

The release manifest was written to `data/releases/kdsm_duffing_diagnostic_v1/release_manifest.toml`, and summary tables were written under `reports/v1_core/kdsm_duffing_diagnostic_v1/tables/`.

## Interpretation

The generated release satisfies the data-side contract needed by downstream KDSM experiments: autonomous augmented state is available for forced systems, physical-only observations are available as negative controls, high-dimensional target pressure is available through D8, and noise continuation is available through D9.

The validation evidence is data-generation evidence only. It does not imply that a downstream diagonal-spectrum learner will succeed on the harder regimes.

## Limitations, Risks, and Next Steps

The generator uses fixed-step RK4 rather than an adaptive ODE solver. The current diagnostics confirm finite values and shape/consistency checks at the configured release scale, but they do not certify long-horizon numerical accuracy for every chaotic trajectory.

D6 uses an implementation-selected physical initial-condition box because the mathematical note fixes the forcing parameters but not the box. If a later task plan gives a different D6 sampling rule, regenerate D6 with that rule and record the change.

Large generated tensors are local artifacts and are intentionally not staged by default. Downstream projects should consume the local `data/releases/kdsm_duffing_diagnostic_v1` release path or use a separate artifact publication mechanism.
