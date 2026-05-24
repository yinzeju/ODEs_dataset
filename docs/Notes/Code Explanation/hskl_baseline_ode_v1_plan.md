Subject name:

$$

\boxed{\texttt{HSKL\_Baseline\_ODE\_v1}}

$$

# Step 2: Implementation Blueprint for `hskl_baseline_ode_v1`

## 1. Confirmed task summary

This task creates a dedicated full-state, noiseless ODE dataset release inside the `ODEs_dataset` project for the formal HSKL Baseline tests.

Dataset name:

```text
hskl_baseline_ode_v1
```

Main constraints confirmed:

```text
observation_mode = full_state
noise_level = clean
```

Therefore, for every saved trajectory,

$$

\mathbf z_m = \mathbf x_m,
\qquad
\mathbf y_m = \mathbf x_m,
\qquad
d_z=d_y=d_x.

$$

This dataset is designed to support the HSKL-Base learning chain

$$

\mathbf z
\mapsto
\boldsymbol{\varphi}_{\theta}(\mathbf z)
\mapsto
\mathbf\Lambda^\ell\boldsymbol{\varphi}_{\theta}(\mathbf z)
\mapsto
\widehat{\mathbf y}_{s+\ell},

$$

with Koopman linear propagation, Hardy admissibility, and trajectory-level reconstruction as the downstream targets. This matches the HSKL Baseline guides, which fix the three mathematical foundations as Koopman linear propagation, Hardy realizability, and trajectory reconstruction. fileciteturn6file0

This task is still a dataset-engineering task, not an HSKL training task. The HSKL project should later consume this release only through metadata such as `benchmark_version`, `system_id`, `difficulty_level`, `split_id`, `observation_mode`, `parameter_regime`, `window_profile`, and `noise_level`, rather than taking over ODE data generation. fileciteturn6file0

---

## 2. Task decomposition

### Task A: Freeze dataset protocol

Purpose: define the official dataset identity, allowed systems, difficulty levels, parameter regimes, split rules, and window profiles.

Output: one registry-level specification for `hskl_baseline_ode_v1`.

### Task B: Define system families

Purpose: define the ODE system objects needed for HSKL formal tests.

Systems:

```text
linear_diagonal
linear_rotation_contraction
linear_jordan_nonnormal
damped_linear_oscillator
van_der_pol
duffing
lotka_volterra
fitzhugh_nagumo
lorenz63
rossler
lorenz96
```

The system list follows the HSKL Baseline Tasks Guide, which separates internal tests, v1-core ODE benchmarks, and stress objects. fileciteturn6file9

### Task C: Define full-state, clean observation protocol

Purpose: remove all observation and noise ambiguity.

Fixed rules:

$$

\mathbf z_m=\mathbf x_m,
\qquad
\mathbf y_m=\mathbf x_m.

$$

No partial sensors, no nonlinear observation, no noisy variants, no denoising target.

### Task D: Define trajectory-level split protocol

Purpose: avoid window leakage.

Splits:

```text
split_i_initial_condition
split_p_parameter
```

Excluded in this release:

```text
split_o_observation
```

because all observations are full-state by confirmation.

### Task E: Define difficulty and window profiles

Purpose: ensure trajectories are long enough for one-step pairs, rollout windows, reconstruction windows, and Hardy windows.

Profiles:

```text
small
medium
large
```

Each profile defines:

$$

R_{\mathrm{train}},R_{\mathrm{val}},R_{\mathrm{test}},
\quad
M,
\quad
\tau,
\quad
L_{\mathrm H},
\quad
L_{\mathrm{rec}},
\quad
L_{\mathrm{roll}}.

$$

### Task F: Generate raw and processed trajectories

Purpose: integrate ODEs, apply burn-in where needed, sample trajectories, and save full-state clean arrays.

### Task G: Validate release numerically

Purpose: verify dimensions, finite values, split disjointness, trajectory lengths, parameter metadata, and downstream HSKL window feasibility.

### Task H: Produce release artifacts and human-readable reports

Purpose: save data arrays, metadata, registry entries, summary tables, diagnostic plots, logs, and release manifest.

---

## 3. Sub-task specification

## 3.1 Freeze dataset protocol

Purpose: create a stable benchmark identity.

Input:

```text
subject_name = HSKL_Baseline_ODE_v1
benchmark_version = hskl_baseline_ode_v1
observation_mode = full_state
noise_level = clean
```

Output:

```text
docs/spec/hskl_baseline_ode_v1_registry.md
configs/data/hskl_baseline_ode_v1_release.yaml
```

Dependency: none.

Diagnostic checks:

- `benchmark_version` appears in every metadata table.
- every config has `observation_mode = full_state`;
- every config has `noise_level = clean`;
- no config contains partial observation, nonlinear observation, or noise sweep.

---

## 3.2 Define system object registry

Purpose: define all ODE systems in this release.

Input:

```text
system_id
state_dimension
parameter_regime
difficulty_level
split_id
```

Output:

```text
docs/spec/hskl_baseline_ode_v1_system_registry.md
configs/data/hskl_baseline_ode_v1_systems.yaml
```

Dependency: dataset protocol.

Diagnostic checks:

- every `system_id` belongs to the approved list;
- every system has at least `small` profile;
- internal systems support dimensions needed for smoke tests;
- stress systems are not required to pass small smoke as formal HSKL success.

---

## 3.3 Define parameter regimes

Purpose: freeze system parameter sets and parameter-generalization rules.

Examples:

For `van_der_pol`:

$$

\dot x=v,
\qquad
\dot v=\mu(1-x^2)v-x.

$$

Regimes:

```text
near_linear: μ = 0.2
limit_cycle: μ = 1.0
relaxation: μ = 3.0
```

For `lorenz96`:

$$

\dot x_i=(x_{i+1}-x_{i-2})x_{i-1}-x_i+F.

$$

Regimes:

```text
forcing_low: F = 6
forcing_standard: F = 8
forcing_high: F = 10
```

Output:

```text
configs/data/hskl_baseline_ode_v1_parameter_regimes.yaml
reports/tables/hskl_baseline_ode_v1_parameter_regimes.csv
```

Dependency: system registry.

Diagnostic checks:

- every parameter regime has explicit scalar or vector parameters;
- Split-P regimes have disjoint train / val / test parameter sets;
- no hidden stochastic parameter sampling unless recorded by seed.

---

## 3.4 Define full-state clean observation protocol

Purpose: enforce the confirmed simplification.

Mathematical rule:

$$

\mathbf z_m=\mathbf x_m,
\qquad
\mathbf y_m=\mathbf x_m.

$$

Output:

```text
configs/data/hskl_baseline_ode_v1_observation_full_state_clean.yaml
docs/spec/hskl_baseline_ode_v1_observation_protocol.md
```

Dependency: dataset protocol.

Diagnostic checks:

- $d_z=d_x$;
- $d_y=d_x$;
- no sensor matrix is used;
- no observation nonlinearity is used;
- no noise field is applied;
- metadata still records `noise_level = clean` for compatibility with downstream HSKL configs.

---

## 3.5 Define trajectory split protocol

Purpose: guarantee no leakage between train, validation, and test.

Split-I:

$$

\mathcal X_{0,\mathrm{train}}
\cap
\mathcal X_{0,\mathrm{val}}
\cap
\mathcal X_{0,\mathrm{test}}
=
\varnothing,

$$

with fixed parameters.

Split-P:

$$

\Pi_{\mathrm{train}}
\cap
\Pi_{\mathrm{test}}
=
\varnothing.

$$

Output:

```text
configs/data/hskl_baseline_ode_v1_splits.yaml
data/releases/hskl_baseline_ode_v1/metadata/splits.csv
```

Dependency: parameter regimes.

Diagnostic checks:

- no trajectory id appears in more than one split;
- no initial condition is duplicated across splits;
- Split-P parameter sets are disjoint;
- Split-O is not present in this release.

The reason for trajectory-level splitting is that HSKL later constructs windows; windows must be built after splitting, not before, to avoid leakage.

---

## 3.6 Define window profiles

Purpose: guarantee downstream compatibility with HSKL windows.

Minimum downstream objects:

$$

L_{\mathrm H},
\qquad
L_{\mathrm{rec}},
\qquad
L_{\mathrm{roll}}.

$$

The HSKL guides require Hardy windows with the fixed tensor convention

$$

\mathcal F^{(\rho,L)}
\in
\mathbb C^{L\times N\times S},

$$

where axis 1 is Hardy coefficient order, axis 2 is spectral channel, and axis 3 is window start. fileciteturn4file0

Output:

```text
configs/windows/hskl_baseline_ode_v1_windows.yaml
reports/tables/hskl_baseline_ode_v1_window_profiles.csv
```

Dependency: split protocol.

Diagnostic checks:

- $M+1 > L_{\mathrm{roll}}$;
- $M+1 > L_{\mathrm{rec}}$;
- $M+1 > L_{\mathrm H}$;
- $S=M-L_{\mathrm H}+1>0$;
- each trajectory supports one-step pairs $(\mathbf z_m,\mathbf z_{m+1})$.

---

## 3.7 Generate full-state clean trajectories

Purpose: create the actual ODE release.

Input:

```text
system_id
parameter_regime
difficulty_level
split_id
initial_condition_seed
solver_profile
sampling_time τ
trajectory_length M
```

Output arrays:

$$

\mathcal X
\in
\mathbb R^{d_x\times(M+1)\times R},

$$

$$

\mathcal Z
=
\mathcal X
\in
\mathbb R^{d_x\times(M+1)\times R},

$$

$$

\mathcal Y
=
\mathcal X
\in
\mathbb R^{d_x\times(M+1)\times R}.

$$

Target path:

```text
data/releases/hskl_baseline_ode_v1/processed/<system_id>/<difficulty_level>/<split_id>/<parameter_regime>/full_state_clean/
```

Dependency: all protocol configs.

Diagnostic checks:

- all values finite;
- no NaN / Inf;
- expected tensor shape;
- time index length equals $M+1$;
- metadata matches saved tensor shape;
- trajectories are not all constant;
- no noise perturbation was applied.

---

## 3.8 Validate release

Purpose: produce dataset-level sanity checks before HSKL uses the release.

Output:

```text
reports/tables/hskl_baseline_ode_v1_release_validation.csv
reports/logs/hskl_baseline_ode_v1_validation.log
reports/plots/hskl_baseline_ode_v1_<system_id>_trajectory_overview.png
reports/plots/hskl_baseline_ode_v1_<system_id>_phase_portrait.png
```

Dependency: generated trajectories.

Diagnostic checks:

- dimension table;
- split count table;
- finite-value check;
- trajectory length check;
- state scale table;
- parameter regime table;
- HSKL window feasibility table;
- attractor / phase portrait plots for nonlinear systems;
- stress warning table for chaotic systems.

---

## 4. Directory and file plan

This plan uses the same directory logic as the Koopman Learning engineering blueprint: `docs/` for documents, `configs/` for declarative settings, `src/` for reusable logic, `data/` for data releases, `reports/` for human-readable outputs, and `test/` for validation. The blueprint also separates `runs/`, `artifacts/`, and `reports/` as process records, reusable outputs, and human-readable summaries. fileciteturn6file11 fileciteturn6file10

## 4.1 Documentation files

```text
docs/notes/mathematical explanation/HSKL_Baseline_ODE_v1_math_explanation.md
```

Role: stores the confirmed mathematical description.

```text
docs/notes/code explanation/HSKL_Baseline_ODE_v1_task_plan.md
```

Role: stores this implementation blueprint.

```text
docs/spec/hskl_baseline_ode_v1_registry.md
```

Role: top-level release identity, allowed metadata keys, allowed system ids.

```text
docs/spec/hskl_baseline_ode_v1_system_registry.md
```

Role: ODE equations, state dimensions, parameter regimes, split availability.

```text
docs/spec/hskl_baseline_ode_v1_observation_protocol.md
```

Role: records that this release is full-state and noiseless only.

```text
docs/spec/hskl_baseline_ode_v1_release_manifest_schema.md
```

Role: human-readable schema for release manifests.

---

## 4.2 Config files

```text
configs/data/hskl_baseline_ode_v1_release.yaml
```

Role: global dataset release config.

```text
configs/data/hskl_baseline_ode_v1_systems.yaml
```

Role: system list and dimensions.

```text
configs/data/hskl_baseline_ode_v1_parameter_regimes.yaml
```

Role: system-specific parameter regimes.

```text
configs/data/hskl_baseline_ode_v1_splits.yaml
```

Role: train / validation / test split policy.

```text
configs/data/hskl_baseline_ode_v1_observation_full_state_clean.yaml
```

Role: fixed observation and noise config.

```text
configs/windows/hskl_baseline_ode_v1_windows.yaml
```

Role: $L_{\mathrm H}$, $L_{\mathrm{rec}}$, $L_{\mathrm{roll}}$, and length feasibility rules.

```text
configs/experiments/hskl_baseline_ode_v1_generation_smoke.yaml
```

Role: smoke generation config.

```text
configs/experiments/hskl_baseline_ode_v1_generation_formal.yaml
```

Role: formal full release generation config.

---

## 4.3 Source files

No implementation code is written here, but the planned Julia files are:

```text
src/data/hskl_baseline_ode_v1_system_specs.jl
```

Role: reusable system specification objects.

```text
src/data/hskl_baseline_ode_v1_parameter_specs.jl
```

Role: parameter-regime definitions.

```text
src/data/hskl_baseline_ode_v1_initial_conditions.jl
```

Role: initial-condition sampling protocol.

```text
src/data/hskl_baseline_ode_v1_generation.jl
```

Role: dataset generation orchestration.

```text
src/data/hskl_baseline_ode_v1_observations.jl
```

Role: full-state clean observation mapping.

```text
src/data/hskl_baseline_ode_v1_splits.jl
```

Role: trajectory-level split construction and verification.

```text
src/data/hskl_baseline_ode_v1_release_io.jl
```

Role: save/load release arrays and metadata.

```text
src/diagnostics/hskl_baseline_ode_v1_data_checks.jl
```

Role: dimension, finite-value, split, and window feasibility checks.

```text
src/diagnostics/hskl_baseline_ode_v1_plot_diagnostics.jl
```

Role: trajectory and phase-portrait diagnostic plots.

```text
src/registries/hskl_baseline_ode_v1_registry.jl
```

Role: register dataset objects and allowed metadata values.

---

## 4.4 Data release files

```text
data/releases/hskl_baseline_ode_v1/raw/<system_id>/<difficulty_level>/<split_id>/<parameter_regime>/full_state_clean/
```

Role: high-fidelity or solver-native trajectory outputs, if retained.

```text
data/releases/hskl_baseline_ode_v1/processed/<system_id>/<difficulty_level>/<split_id>/<parameter_regime>/full_state_clean/
```

Role: official sampled full-state clean arrays consumed by HSKL.

```text
data/releases/hskl_baseline_ode_v1/metadata/release_manifest.json
```

Role: global release manifest.

```text
data/releases/hskl_baseline_ode_v1/metadata/systems.csv
```

Role: system summary table.

```text
data/releases/hskl_baseline_ode_v1/metadata/parameter_regimes.csv
```

Role: parameter regime table.

```text
data/releases/hskl_baseline_ode_v1/metadata/splits.csv
```

Role: split table.

```text
data/releases/hskl_baseline_ode_v1/metadata/window_profiles.csv
```

Role: downstream HSKL window feasibility metadata.

---

## 4.5 Report files

```text
reports/tables/hskl_baseline_ode_v1_system_summary.csv
```

Role: system dimensions and regimes.

```text
reports/tables/hskl_baseline_ode_v1_parameter_regimes.csv
```

Role: human-readable parameter table.

```text
reports/tables/hskl_baseline_ode_v1_split_summary.csv
```

Role: trajectory counts by split.

```text
reports/tables/hskl_baseline_ode_v1_window_feasibility.csv
```

Role: verifies $M$, $L_{\mathrm H}$, $L_{\mathrm{rec}}$, and $L_{\mathrm{roll}}$.

```text
reports/tables/hskl_baseline_ode_v1_release_validation.csv
```

Role: final validation summary.

```text
reports/plots/hskl_baseline_ode_v1_<system_id>_trajectory_overview.png
```

Role: trajectory visualization.

```text
reports/plots/hskl_baseline_ode_v1_<system_id>_phase_portrait.png
```

Role: phase portrait for 2D / 3D systems.

```text
reports/logs/hskl_baseline_ode_v1_generation.log
```

Role: generation log.

```text
reports/logs/hskl_baseline_ode_v1_validation.log
```

Role: validation log.

---

## 4.6 Test files

```text
test/unit/test_hskl_baseline_ode_v1_system_specs.jl
```

Role: system registry and parameter specification checks.

```text
test/unit/test_hskl_baseline_ode_v1_full_state_clean.jl
```

Role: verifies $\mathbf z=\mathbf x$, $\mathbf y=\mathbf x$, no noise.

```text
test/unit/test_hskl_baseline_ode_v1_splits.jl
```

Role: verifies split disjointness.

```text
test/integration/test_hskl_baseline_ode_v1_generation_smoke.jl
```

Role: smoke generation for a minimal system subset.

```text
test/regression/test_hskl_baseline_ode_v1_release_manifest.jl
```

Role: release manifest stability.

---

## 5. Module / component responsibilities

## 5.1 Data handling

Responsible files:

```text
src/data/hskl_baseline_ode_v1_generation.jl
src/data/hskl_baseline_ode_v1_release_io.jl
```

Responsibilities:

- generate or load trajectory arrays;
- preserve full trajectory order;
- save raw and processed arrays;
- write metadata;
- never create random windows before split.

---

## 5.2 Dynamics

Responsible file:

```text
src/data/hskl_baseline_ode_v1_system_specs.jl
```

Responsibilities:

- define the mathematical system identity;
- define state dimension $d_x$;
- define parameter names;
- define whether burn-in is required;
- define expected qualitative behavior.

---

## 5.3 Observables

Responsible file:

```text
src/data/hskl_baseline_ode_v1_observations.jl
```

Responsibilities:

- enforce full-state mapping;
- set $d_z=d_x$;
- set $d_y=d_x$;
- confirm no noise is added.

---

## 5.4 Splits

Responsible file:

```text
src/data/hskl_baseline_ode_v1_splits.jl
```

Responsibilities:

- construct trajectory-level train / val / test indices;
- implement Split-I and Split-P;
- exclude Split-O;
- verify no leakage.

---

## 5.5 Diagnostics

Responsible files:

```text
src/diagnostics/hskl_baseline_ode_v1_data_checks.jl
src/diagnostics/hskl_baseline_ode_v1_plot_diagnostics.jl
```

Responsibilities:

- check dimensions;
- check finite values;
- check state scale;
- check trajectory length;
- check HSKL window feasibility;
- produce trajectory and phase plots.

---

## 5.6 Registries

Responsible file:

```text
src/registries/hskl_baseline_ode_v1_registry.jl
```

Responsibilities:

- expose valid `system_id`;
- expose valid `parameter_regime`;
- expose valid `difficulty_level`;
- expose valid `split_id`;
- expose fixed `observation_mode = full_state`;
- expose fixed `noise_level = clean`.

---

## 6. Planned `##` sections

## 6.1 `src/data/hskl_baseline_ode_v1_system_specs.jl`

Planned section titles:

```text
## Dataset identity and release constants
## Internal HSKL sanity systems
## Core nonlinear benchmark systems
## Chaotic and high-dimensional stress systems
## State dimension registry
## System equation metadata
## Burn-in and sampling metadata
## System validation rules
```

---

## 6.2 `src/data/hskl_baseline_ode_v1_parameter_specs.jl`

Planned section titles:

```text
## Parameter regime identity
## Linear system parameter regimes
## Oscillator parameter regimes
## Nonlinear low-dimensional parameter regimes
## Chaotic system parameter regimes
## Split-P parameter disjointness rules
## Parameter table export fields
```

---

## 6.3 `src/data/hskl_baseline_ode_v1_initial_conditions.jl`

Planned section titles:

```text
## Initial-condition domain registry
## Initial-condition seed protocol
## Split-I initial-condition disjointness
## System-specific sampling ranges
## Initial-condition validation diagnostics
```

---

## 6.4 `src/data/hskl_baseline_ode_v1_generation.jl`

Planned section titles:

```text
## Load release generation config
## Resolve system and parameter registry entries
## Construct trajectory-level split objects
## Generate or bind ODE trajectories
## Apply burn-in and fixed sampling interval
## Apply full-state clean observation mapping
## Assemble raw and processed trajectory tensors
## Save release arrays and metadata
## Write generation log and manifest
```

---

## 6.5 `src/data/hskl_baseline_ode_v1_observations.jl`

Planned section titles:

```text
## Full-state observation protocol
## Target observation protocol
## Dimension equality checks
## Clean-noise invariant checks
## Observation metadata fields
```

---

## 6.6 `src/data/hskl_baseline_ode_v1_splits.jl`

Planned section titles:

```text
## Trajectory-id split protocol
## Split-I initial-condition generalization
## Split-P parameter generalization
## Excluded Split-O observation generalization
## Split disjointness checks
## Split metadata export
```

---

## 6.7 `src/data/hskl_baseline_ode_v1_release_io.jl`

Planned section titles:

```text
## Release path resolution
## Raw trajectory array saving
## Processed trajectory array saving
## Metadata table writing
## Release manifest writing
## Release manifest validation
```

---

## 6.8 `src/diagnostics/hskl_baseline_ode_v1_data_checks.jl`

Planned section titles:

```text
## Tensor shape diagnostics
## Finite-value diagnostics
## Full-state clean diagnostics
## Split leakage diagnostics
## Parameter-regime diagnostics
## HSKL window feasibility diagnostics
## State scale diagnostics
## Validation table assembly
```

---

## 6.9 `src/diagnostics/hskl_baseline_ode_v1_plot_diagnostics.jl`

Planned section titles:

```text
## Time-series overview plots
## Two-dimensional phase portraits
## Three-dimensional phase portraits
## High-dimensional coordinate summary plots
## Split comparison plots
## Plot manifest writing
```

---

## 6.10 `src/registries/hskl_baseline_ode_v1_registry.jl`

Planned section titles:

```text
## Dataset release registry
## System-id registry
## Difficulty-level registry
## Parameter-regime registry
## Split-id registry
## Observation-mode registry
## Noise-level registry
## Registry consistency diagnostics
```

---

## 7. Data flow and dimensions

## 7.1 Data flow

The full flow is:

$$

\text{system config}
\to
\text{parameter regime}
\to
\text{initial conditions}
\to
\text{ODE integration}
\to
\text{burn-in}
\to
\text{sampling}
\to
\text{full-state observation}
\to
\text{trajectory-level split}
\to
\text{release arrays}
\to
\text{validation reports}.

$$

No HSKL latent variables are generated in this task.

---

## 7.2 Core tensor shapes

For each release object:

$$

\mathcal X
\in
\mathbb R^{d_x\times(M+1)\times R},

$$

$$

\mathcal Z
\in
\mathbb R^{d_x\times(M+1)\times R},

$$

$$

\mathcal Y
\in
\mathbb R^{d_x\times(M+1)\times R}.

$$

Since this release is full-state clean:

$$

\mathcal X=\mathcal Z=\mathcal Y

$$

at the processed-data level, up to storage layout.

---

## 7.3 Snapshot pairs for downstream HSKL

Downstream one-step learning can form:

$$

\mathbf Z_X
=
[
\mathbf z_0,\dots,\mathbf z_{M-1}
]
\in
\mathbb R^{d_x\times M},

$$

$$

\mathbf Z_Y
=
[
\mathbf z_1,\dots,\mathbf z_M
]
\in
\mathbb R^{d_x\times M}.

$$

For $R$ trajectories, downstream code may concatenate across trajectories only after respecting split boundaries.

---

## 7.4 Window feasibility

For a trajectory length $M+1$, downstream windows require:

$$

S_{\mathrm H}
=
M-L_{\mathrm H}+1>0,

$$

$$

S_{\mathrm{rec}}
=
M-L_{\mathrm{rec}}+1>0,

$$

$$

S_{\mathrm{roll}}
=
M-L_{\mathrm{roll}}+1>0.

$$

The dataset should not itself construct Hardy tensors, but it must save enough time points for HSKL to construct them later.

---

## 7.5 Difficulty-level dimensions

Suggested profiles:

| difficulty | trajectory count | time length | intended use |
|---|---:|---:|---|
| `small` | low $R$ | $M\approx256$ | smoke and protocol checks |
| `medium` | moderate $R$ | $M\approx1024$ | formal HSKL baseline |
| `large` | high $R$ | $M\in\{2048,4096\}$ | chaotic / high-dimensional stress |

Exact values should be frozen in `configs/data/hskl_baseline_ode_v1_release.yaml`.

---

## 8. Package and documentation plan

No package APIs should be assumed from memory.

### DifferentialEquations.jl / OrdinaryDiffEq.jl

Purpose: ODE integration.

Documentation checks before coding:

- fixed-step versus adaptive-save workflow;
- saving at exact sampling interval $\tau$;
- tolerances for chaotic systems;
- ensemble trajectory workflows;
- event-free burn-in handling.

### LinearAlgebra.jl

Purpose:

- linear systems;
- block rotation-contraction matrices;
- matrix exponential checks for linear systems;
- norm and finite-value diagnostics.

Documentation checks:

- no special API assumptions beyond stable standard-library behavior.

### Random / Distributions.jl

Purpose:

- initial condition sampling;
- Split-I seed control;
- parameter sampling if used.

Documentation checks:

- reproducible RNG stream handling;
- distribution object usage;
- deterministic split reproducibility.

### JLD2.jl / HDF5.jl / Arrow.jl

Purpose:

- save trajectory tensors and metadata tables.

Documentation checks:

- which storage format is already used by `ODEs_dataset`;
- array layout preservation;
- metadata compatibility;
- compression behavior for large Lorenz96 arrays.

### DataFrames.jl / CSV.jl

Purpose:

- metadata tables;
- validation tables;
- system registry export.

Documentation checks:

- table writing workflow;
- type preservation for metadata fields;
- CSV escaping for parameter dictionaries.

### Plots.jl / Makie.jl

Purpose:

- diagnostic plots.

Documentation checks:

- current plotting backend used in `ODEs_dataset`;
- 3D trajectory plotting workflow;
- reproducible plot export.

---

## 9. Debugging and inspection plan

## 9.1 Mandatory printed or logged quantities

For every generated dataset object:

```text
benchmark_version
system_id
difficulty_level
split_id
parameter_regime
observation_mode
noise_level
d_x
M
R
τ
burn_in_time
solver_profile
```

For tensors:

$$

\operatorname{size}(\mathcal X),
\quad
\operatorname{size}(\mathcal Z),
\quad
\operatorname{size}(\mathcal Y).

$$

For full-state clean checks:

$$

\|\mathcal Z-\mathcal X\|_{\infty}=0,

$$

$$

\|\mathcal Y-\mathcal X\|_{\infty}=0.

$$

For window feasibility:

$$

M-L_{\mathrm H}+1,
\quad
M-L_{\mathrm{rec}}+1,
\quad
M-L_{\mathrm{roll}}+1.

$$

---

## 9.2 Mandatory tables

```text
reports/tables/hskl_baseline_ode_v1_system_summary.csv
```

Columns:

```text
system_id
layer
d_x
available_difficulty_levels
available_parameter_regimes
available_splits
```

```text
reports/tables/hskl_baseline_ode_v1_split_summary.csv
```

Columns:

```text
system_id
difficulty_level
parameter_regime
split_id
R_train
R_val
R_test
trajectory_id_overlap_count
```

```text
reports/tables/hskl_baseline_ode_v1_window_feasibility.csv
```

Columns:

```text
system_id
difficulty_level
M
L_H
L_rec
L_roll
S_H
S_rec
S_roll
window_feasible
```

```text
reports/tables/hskl_baseline_ode_v1_release_validation.csv
```

Columns:

```text
system_id
difficulty_level
split_id
parameter_regime
finite_check
shape_check
full_state_check
clean_noise_check
split_check
window_check
status
```

---

## 9.3 Mandatory plots

For 2D systems:

```text
reports/plots/hskl_baseline_ode_v1_<system_id>_phase_portrait.png
```

For 3D systems:

```text
reports/plots/hskl_baseline_ode_v1_<system_id>_3d_phase_portrait.png
```

For high-dimensional systems:

```text
reports/plots/hskl_baseline_ode_v1_lorenz96_coordinate_summary.png
```

For all systems:

```text
reports/plots/hskl_baseline_ode_v1_<system_id>_trajectory_overview.png
```

---

## 9.4 Failure counters

The validation log should count:

```text
nonfinite_count
shape_mismatch_count
split_overlap_count
full_state_violation_count
noise_violation_count
window_infeasible_count
empty_trajectory_count
constant_trajectory_count
metadata_missing_count
```

The HSKL Baseline Tasks Guide also emphasizes seed-level reporting and failure counts rather than only reporting best results in formal tasks. fileciteturn6file6

---

## 10. Expected outputs

## 10.1 Official data release

```text
data/releases/hskl_baseline_ode_v1/
```

Subfolders:

```text
raw/
processed/
metadata/
```

Main processed data location:

```text
data/releases/hskl_baseline_ode_v1/processed/<system_id>/<difficulty_level>/<split_id>/<parameter_regime>/full_state_clean/
```

---

## 10.2 Frozen configs

```text
configs/data/hskl_baseline_ode_v1_release.yaml
configs/data/hskl_baseline_ode_v1_systems.yaml
configs/data/hskl_baseline_ode_v1_parameter_regimes.yaml
configs/data/hskl_baseline_ode_v1_splits.yaml
configs/data/hskl_baseline_ode_v1_observation_full_state_clean.yaml
configs/windows/hskl_baseline_ode_v1_windows.yaml
configs/experiments/hskl_baseline_ode_v1_generation_smoke.yaml
configs/experiments/hskl_baseline_ode_v1_generation_formal.yaml
```

---

## 10.3 Metadata

```text
data/releases/hskl_baseline_ode_v1/metadata/release_manifest.json
data/releases/hskl_baseline_ode_v1/metadata/systems.csv
data/releases/hskl_baseline_ode_v1/metadata/parameter_regimes.csv
data/releases/hskl_baseline_ode_v1/metadata/splits.csv
data/releases/hskl_baseline_ode_v1/metadata/window_profiles.csv
```

---

## 10.4 Reports

```text
reports/tables/hskl_baseline_ode_v1_system_summary.csv
reports/tables/hskl_baseline_ode_v1_parameter_regimes.csv
reports/tables/hskl_baseline_ode_v1_split_summary.csv
reports/tables/hskl_baseline_ode_v1_window_feasibility.csv
reports/tables/hskl_baseline_ode_v1_release_validation.csv
reports/plots/hskl_baseline_ode_v1_<system_id>_trajectory_overview.png
reports/plots/hskl_baseline_ode_v1_<system_id>_phase_portrait.png
reports/logs/hskl_baseline_ode_v1_generation.log
reports/logs/hskl_baseline_ode_v1_validation.log
```

---

## 10.5 Tests

```text
test/unit/test_hskl_baseline_ode_v1_system_specs.jl
test/unit/test_hskl_baseline_ode_v1_full_state_clean.jl
test/unit/test_hskl_baseline_ode_v1_splits.jl
test/integration/test_hskl_baseline_ode_v1_generation_smoke.jl
test/regression/test_hskl_baseline_ode_v1_release_manifest.jl
```

---

## 10.6 Explicitly not produced

This dataset task should not produce:

```text
artifacts/checkpoints/
artifacts/operators/
artifacts/spectra/
artifacts/modes/
artifacts/predictions/
artifacts/embeddings/
```

Those belong to downstream HSKL training and evaluation, not to the ODE dataset release.

---

## 11. Failure points and debugging strategies

## 11.1 Full-state invariant fails

Symptom:

$$

\|\mathcal Z-\mathcal X\|_{\infty}>0.

$$

Likely cause:

- observation mapping accidentally applied;
- noise path not disabled;
- target and input arrays saved from different buffers.

Debugging strategy:

- inspect observation config;
- verify `observation_mode = full_state`;
- verify `noise_level = clean`;
- compare first trajectory coordinate-wise.

---

## 11.2 Window infeasibility

Symptom:

$$

M-L+1\le0.

$$

Likely cause:

- difficulty profile too short;
- rollout horizon too long;
- off-by-one confusion between $M$ and $M+1$.

Debugging strategy:

- print $M+1$, $L_{\mathrm H}$, $L_{\mathrm{rec}}$, $L_{\mathrm{roll}}$;
- verify trajectory stores indices $0,\dots,M$;
- update window profile, not downstream HSKL code.

---

## 11.3 Split leakage

Symptom:

```text
trajectory_id_overlap_count > 0
```

Likely cause:

- trajectory ids assigned after split;
- window-level split accidentally used;
- Split-P and Split-I mixed improperly.

Debugging strategy:

- construct split ids before window construction;
- test set intersection of train / val / test ids;
- store split table as release metadata.

---

## 11.4 Split-P parameter leakage

Symptom:

$$

\Pi_{\mathrm{train}}
\cap
\Pi_{\mathrm{test}}
\neq
\varnothing.

$$

Likely cause:

- same parameter regime reused across train and test;
- parameter values sampled continuously but not recorded exactly.

Debugging strategy:

- write parameter values to `parameter_regimes.csv`;
- compare exact parameter tuples;
- use named parameter regimes for first release.

---

## 11.5 Chaotic systems appear to fail visual rollout

Symptom: Lorenz63, Rössler, or Lorenz96 trajectories diverge rapidly from nearby references.

Likely cause:

- expected sensitivity to initial conditions;
- not necessarily dataset generation error.

Debugging strategy:

- inspect attractor range;
- compare statistics rather than long-term pointwise alignment;
- verify short-horizon continuity;
- check burn-in and sampling interval.

---

## 11.6 Linear systems appear unstable

Symptom: trajectories explode for supposedly stable linear systems.

Likely cause:

- wrong sign in $\gamma_j$;
- wrong block matrix orientation;
- too-large time step for saved discrete trajectory;
- parameter regime accidentally near-boundary or unstable.

Debugging strategy:

- inspect continuous eigenvalues;
- inspect discrete multipliers;
- verify `near_boundary` is marked as stress;
- plot coordinate norms.

---

## 11.7 Metadata incomplete

Symptom: generated arrays exist, but downstream HSKL cannot bind them.

Likely cause:

- missing `benchmark_version`;
- missing `system_id`;
- missing `difficulty_level`;
- missing `split_id`;
- missing `parameter_regime`;
- missing `window_profile`.

Debugging strategy:

- validate `release_manifest.json`;
- run registry consistency diagnostics;
- require every processed array folder to have a metadata record.

---

## 12. Stop before code

This Step 2 stops at the implementation blueprint level.

No Julia code, pseudocode, function signatures, package APIs, or script contents are provided here. The next step should be a separate implementation request.