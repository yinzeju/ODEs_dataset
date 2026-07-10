# Main subject name

`kdsm_basic_diagnostic_v1`

This is an **ODEs_dataset project task**, not a KDSM training task. The engineering goal is to generate and freeze a basic diagnostic dataset release containing clean 2D trajectory objects, observations, targets, split metadata, window metadata, manifests, diagnostics, and smoke/regression checks. ODEs_dataset should remain a data protocol and data factory, while KDSM training, losses, latent spectra, and decoder logic stay downstream. The ODEs_dataset guide explicitly separates system generation, observation processing, split/window construction, and metric reporting. fileciteturn2file0

---

## 1. Confirmed task summary

The dataset is `kdsm_basic_diagnostic_v1`. It should generate a controlled ladder:

$$

\text{discrete damped rotation}
\to
\text{continuous linear oscillator}
\to
\text{weak Duffing beta scan}
\to
\text{D0 reference near-linear Duffing}.

$$

The mathematical guide defines all base objects as 2D physical systems with

$$

x_{\mathrm{phys}}=(q,p)^\top,\qquad z_m=(q_m,p_m)^\top,\qquad y_m=(q_m,p_m)^\top,

$$

so all basic diagnostic objects satisfy

$$

d_z=2,\qquad d_y=2.

$$

The object list includes `kdsm_basic__L0_discrete_damped_rotation`, `kdsm_basic__L1_continuous_linear_oscillator`, five weak Duffing beta-scan objects, and `kdsm_basic__D0_reference_near_linear_damped`. fileciteturn3file12

The default generation protocol uses

$$

\tau=0.05,\qquad M_{\mathrm{traj}}=256,\qquad R_{\mathrm{train}}=48,\quad R_{\mathrm{val}}=8,\quad R_{\mathrm{test}}=8,

$$

with trajectory-level split before windowing. fileciteturn3file13

---

## 2. Task decomposition

### Sub-task A — Register dataset object family

Purpose: add `kdsm_basic_diagnostic_v1` as a named dataset family inside ODEs_dataset.

Input: mathematical object list and parameter definitions.

Output: system configs, release config, registry entries.

Dependency: none.

Diagnostic checks: all object ids unique; all state dimensions equal 2; no forcing channel appears.

---

### Sub-task B — Implement system-level generation support

Purpose: support one exact discrete map and two continuous-time ODE families.

Input:

$$

x_0=(q_0,p_0)^\top,\quad \tau,\quad M_{\mathrm{traj}},\quad R.

$$

Output:

$$

\mathcal X\in\mathbb R^{R\times(M_{\mathrm{traj}}+1)\times 2}.

$$

Dependency: Sub-task A.

Diagnostic checks: finite values, stable damping, correct shape, reproducible seeds, no NaN/Inf, no unintended forcing variables.

---

### Sub-task C — Add observation and target configs

Purpose: define `obs_phys`, `obs_aug_full`, and `target_phys`.

Input: raw state tensor $\mathcal X$.

Output:

$$

\mathcal Z^{\mathrm{phys}}=\mathcal X,\qquad
\mathcal Z^{\mathrm{aug\_full}}=\mathcal X,\qquad
\mathcal Y^{\mathrm{phys}}=\mathcal X.

$$

Dependency: Sub-task B.

Diagnostic checks: all three tensors have shape $R\times257\times2$; `obs_aug_full` is identical to `obs_phys` for all no-forcing objects.

---

### Sub-task D — Add split and amplitude metadata

Purpose: generate trajectory-level split roles and amplitude groups.

Input: initial conditions $x_0^{(r)}$.

Output:

$$

\texttt{split\_roles}\in\{\text{train},\text{val},\text{test}\}^{64},

$$

and amplitude group labels from

$$

A_0=\sqrt{q_0^2+p_0^2}.

$$

Dependency: Sub-task B.

Diagnostic checks: split counts are exactly 48/8/8; amplitude group counts are nonzero when possible; no window-level leakage.

---

### Sub-task E — Add window protocol metadata

Purpose: declare one-step and rollout window availability without moving KDSM training logic into ODEs_dataset.

Input: full trajectories and split roles.

Output: window metadata for one-step pairs and rollout horizons

$$

H=\{1,2,4,8,16\}.

$$

Dependency: Sub-task D.

Diagnostic checks: for every horizon $h$, valid start indices satisfy $s+h\le256$; windows are constructed only within split subsets. The ODEs_dataset guide requires split-before-windowing and forbids distributing neighboring windows from the same trajectory across train/test. fileciteturn3file17

---

### Sub-task F — Save raw, processed, manifest, and release outputs

Purpose: create reproducible dataset artifacts.

Input: tensors, metadata, configs, diagnostics.

Output: raw files, processed files, manifests, release index.

Dependency: Sub-tasks A–E.

Diagnostic checks: raw/processed separation, manifest completeness, hash consistency, reload test.

---

### Sub-task G — Add smoke, integration, and regression tests

Purpose: prevent future changes from breaking the diagnostic dataset.

Input: small-generation configs and frozen reference statistics.

Output: passing tests and reference outputs.

Dependency: Sub-tasks A–F.

Diagnostic checks: shapes, split counts, object ids, parameter values, reproducibility, finite statistics.

---

## 3. Directory and file plan

### Documentation

| Target path | Role |
|---|---|
| `docs/notes/code explanation/kdsm_basic_diagnostic_v1_code_engineering_guide.md` | This code-engineering guide. |
| `docs/notes/file explanation/kdsm_basic_diagnostic_v1_file_guide.md` | Post-generation file guide explaining generated files and fields. |
| `docs/spec/object_registry.md` | Add registry entry for `kdsm_basic_diagnostic_v1`. |
| `docs/spec/project_task_list.md` | Add task record, status, and validation summary. |

### Configs

| Target path | Role |
|---|---|
| `configs/systems/kdsm_basic_diagnostic_v1_systems.toml` | All 8 system object definitions and parameters. |
| `configs/observations/kdsm_basic_diagnostic_v1_observations.toml` | `obs_phys`, `obs_aug_full`, `target_phys` observation/target protocol. |
| `configs/splits/kdsm_basic_diagnostic_v1_split_trajectory_I.toml` | Fixed 48/8/8 trajectory-level split protocol. |
| `configs/windows/kdsm_basic_diagnostic_v1_windows.toml` | One-step and rollout horizon metadata for $H=\{1,2,4,8,16\}$. |
| `configs/tasks/kdsm_basic_diagnostic_v1_tasks.toml` | Dataset-side task declarations: one-step, rollout, reconstruction target availability. |
| `configs/benchmarks/kdsm_basic_diagnostic_v1_benchmark.toml` | Complete benchmark bundle linking systems, observations, splits, windows, tasks. |
| `configs/releases/kdsm_basic_diagnostic_v1_release.toml` | Release manifest input listing all generated objects and frozen config ids. |

### Source responsibilities

| Target path | Responsibility |
|---|---|
| `src/dynamics/kdsm_basic_diagnostic_systems.jl` | System definitions: discrete rotation, linear oscillator, weak Duffing family. |
| `src/generators/kdsm_basic_diagnostic_generator.jl` | Dataset generation orchestration from configs. |
| `src/observations/kdsm_basic_diagnostic_observations.jl` | Identity observation/target construction and consistency checks. |
| `src/splits/kdsm_basic_diagnostic_splits.jl` | 48/8/8 trajectory-level split creation. |
| `src/windows/kdsm_basic_diagnostic_windows.jl` | One-step and rollout window index metadata. |
| `src/diagnostics/kdsm_basic_diagnostic_data_checks.jl` | Dataset-side checks: shape, finite values, amplitudes, energy-like summaries, split counts. |
| `src/manifests/kdsm_basic_diagnostic_manifest.jl` | Object-level and release-level manifest construction. |
| `src/registries/kdsm_basic_diagnostic_registry.jl` | Register object ids, config ids, task ids, release id. |
| `src/io/kdsm_basic_diagnostic_io.jl` | Save/reload raw, processed, manifest, release index files. |

### Experiment entry

| Target path | Role |
|---|---|
| `experiments/smoke_tests/run_kdsm_basic_diagnostic_v1_smoke.jl` | Minimal generation of a small subset for fast validation. |
| `experiments/baseline_forecasting/run_kdsm_basic_diagnostic_v1_data_checks.jl` | Full dataset generation and data-side diagnostic report. |

### Tests

| Target path | Role |
|---|---|
| `test/unit/test_kdsm_basic_diagnostic_system_specs.jl` | Check system config parsing and object ids. |
| `test/unit/test_kdsm_basic_diagnostic_observations.jl` | Check `obs_phys`, `obs_aug_full`, `target_phys` identity relations. |
| `test/unit/test_kdsm_basic_diagnostic_splits.jl` | Check split counts and trajectory-level grouping. |
| `test/unit/test_kdsm_basic_diagnostic_windows.jl` | Check valid one-step and rollout window indices. |
| `test/integration/test_kdsm_basic_diagnostic_generation.jl` | End-to-end small generation and reload. |
| `test/regression/test_kdsm_basic_diagnostic_reference_stats.jl` | Compare frozen reference statistics after future changes. |

---

## 4. Dataset object output paths

For each object id below, save raw, processed, and manifest outputs.

| Object id | Raw output | Processed output | Manifest |
|---|---|---|---|
| `kdsm_basic__L0_discrete_damped_rotation` | `data/raw/kdsm_basic_diagnostic_v1/kdsm_basic__L0_discrete_damped_rotation/raw_trajectories.jld2` | `data/processed/kdsm_basic_diagnostic_v1/kdsm_basic__L0_discrete_damped_rotation/processed_tensors.jld2` | `data/manifests/kdsm_basic_diagnostic_v1/kdsm_basic__L0_discrete_damped_rotation_manifest.toml` |
| `kdsm_basic__L1_continuous_linear_oscillator` | `data/raw/kdsm_basic_diagnostic_v1/kdsm_basic__L1_continuous_linear_oscillator/raw_trajectories.jld2` | `data/processed/kdsm_basic_diagnostic_v1/kdsm_basic__L1_continuous_linear_oscillator/processed_tensors.jld2` | `data/manifests/kdsm_basic_diagnostic_v1/kdsm_basic__L1_continuous_linear_oscillator_manifest.toml` |
| `kdsm_basic__BETA_0000_linear_duffing` | `data/raw/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0000_linear_duffing/raw_trajectories.jld2` | `data/processed/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0000_linear_duffing/processed_tensors.jld2` | `data/manifests/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0000_linear_duffing_manifest.toml` |
| `kdsm_basic__BETA_0001_weak_duffing` | `data/raw/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0001_weak_duffing/raw_trajectories.jld2` | `data/processed/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0001_weak_duffing/processed_tensors.jld2` | `data/manifests/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0001_weak_duffing_manifest.toml` |
| `kdsm_basic__BETA_0010_weak_duffing` | `data/raw/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0010_weak_duffing/raw_trajectories.jld2` | `data/processed/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0010_weak_duffing/processed_tensors.jld2` | `data/manifests/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0010_weak_duffing_manifest.toml` |
| `kdsm_basic__BETA_0050_weak_duffing` | `data/raw/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0050_weak_duffing/raw_trajectories.jld2` | `data/processed/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0050_weak_duffing/processed_tensors.jld2` | `data/manifests/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0050_weak_duffing_manifest.toml` |
| `kdsm_basic__BETA_0100_weak_duffing` | `data/raw/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0100_weak_duffing/raw_trajectories.jld2` | `data/processed/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0100_weak_duffing/processed_tensors.jld2` | `data/manifests/kdsm_basic_diagnostic_v1/kdsm_basic__BETA_0100_weak_duffing_manifest.toml` |
| `kdsm_basic__D0_reference_near_linear_damped` | `data/raw/kdsm_basic_diagnostic_v1/kdsm_basic__D0_reference_near_linear_damped/raw_trajectories.jld2` | `data/processed/kdsm_basic_diagnostic_v1/kdsm_basic__D0_reference_near_linear_damped/processed_tensors.jld2` | `data/manifests/kdsm_basic_diagnostic_v1/kdsm_basic__D0_reference_near_linear_damped_manifest.toml` |

Release-level files:

| Target path | Role |
|---|---|
| `data/releases/kdsm_basic_diagnostic_v1/release_index.toml` | Lists all object manifests and processed tensor files. |
| `data/releases/kdsm_basic_diagnostic_v1/kdsm_basic_diagnostic_v1_manifest.toml` | Frozen release-level metadata. |
| `data/releases/kdsm_basic_diagnostic_v1/checksums.toml` | Hashes for raw, processed, and manifest files. |

---

## 5. Planned `##` sections for Julia files

No code is written here. These are only intended section titles.

### `src/dynamics/kdsm_basic_diagnostic_systems.jl`

- `## Dataset family constants and object ids`
- `## Discrete damped rotation specification`
- `## Continuous linear oscillator specification`
- `## Weak Duffing beta-scan specifications`
- `## Parameter validation rules`
- `## True-spectrum metadata rules`

### `src/generators/kdsm_basic_diagnostic_generator.jl`

- `## Load frozen generation configs`
- `## Initialize reproducible trajectory seeds`
- `## Generate raw state trajectories`
- `## Attach initial-condition and amplitude metadata`
- `## Build processed observation and target tensors`
- `## Run dataset-side diagnostics`
- `## Save raw, processed, and manifest outputs`

### `src/observations/kdsm_basic_diagnostic_observations.jl`

- `## Define identity physical observation`
- `## Define no-forcing augmented observation alias`
- `## Define physical target tensor`
- `## Validate observation-target dimensions`
- `## Validate identity relations for no-forcing objects`

### `src/splits/kdsm_basic_diagnostic_splits.jl`

- `## Define trajectory-level split protocol`
- `## Generate deterministic train-val-test roles`
- `## Validate split counts`
- `## Prevent window-level leakage`

### `src/windows/kdsm_basic_diagnostic_windows.jl`

- `## Define one-step window metadata`
- `## Define decoded rollout horizon metadata`
- `## Validate horizon start indices`
- `## Attach split-local window counts`

### `src/diagnostics/kdsm_basic_diagnostic_data_checks.jl`

- `## Shape and dtype checks`
- `## Finite-value and range checks`
- `## Split and amplitude-group summaries`
- `## Linear-system analytic consistency checks`
- `## Duffing beta-scan monotonic metadata checks`
- `## Diagnostic table assembly`

### `src/manifests/kdsm_basic_diagnostic_manifest.jl`

- `## Object-level manifest fields`
- `## Release-level manifest fields`
- `## Config hash and data checksum fields`
- `## Reproducibility metadata`
- `## Manifest validation checks`

### `src/io/kdsm_basic_diagnostic_io.jl`

- `## Resolve dataset output paths`
- `## Save raw trajectory files`
- `## Save processed tensor files`
- `## Save manifest and release files`
- `## Reload and verify saved objects`

---

## 6. Data flow and dimensions

For every object:

$$

R=64,\qquad M_{\mathrm{traj}}=256,\qquad d_x=d_z=d_y=2.

$$

Raw state tensor:

$$

\mathcal X\in\mathbb R^{64\times257\times2}.

$$

Processed observation tensors:

$$

\texttt{obs\_phys}\in\mathbb R^{64\times257\times2},

$$

$$

\texttt{obs\_aug\_full}\in\mathbb R^{64\times257\times2}.

$$

Target tensor:

$$

\texttt{target\_phys}\in\mathbb R^{64\times257\times2}.

$$

Split roles:

$$

\texttt{split\_roles}\in\{\text{train},\text{val},\text{test}\}^{64}.

$$

Amplitude metadata:

$$

\texttt{amplitude\_group}\in\{\text{small},\text{mid},\text{large},\text{out\_of\_band}\}^{64}.

$$

One-step sample count per split:

$$

N_{\mathrm{1step,train}}=48\times256,

$$

$$

N_{\mathrm{1step,val}}=8\times256,

$$

$$

N_{\mathrm{1step,test}}=8\times256.

$$

For rollout horizon $h$, valid start count per trajectory is

$$

256-h+1

$$

if windows include starts $s=0,\dots,256-h$. The configured horizons are $H=\{1,2,4,8,16\}$, matching the KDSM diagnostic horizon requirement in the dataset math guide. fileciteturn3file13

---

## 7. Package and documentation plan

Potential Julia packages, to be checked against official documentation before implementation:

| Package direction | Why needed | Documentation checks before coding |
|---|---|---|
| `DifferentialEquations.jl` / `OrdinaryDiffEq.jl` | Continuous linear oscillator and Duffing integration. | Solver choice, tolerance fields, dense output or fixed-save time handling, reproducibility behavior. |
| `LinearAlgebra` | Matrix exponential for analytic linear oscillator metadata; rotation matrix construction; norms. | `exp` behavior for small dense matrices and complex eigenvalue handling. |
| `Random` | Reproducible initial condition sampling and split seeds. | RNG construction and seed isolation across objects. |
| `Statistics` | Basic channel means, standard deviations, amplitude summaries. | Standard deviation conventions and dimensional reductions. |
| `JLD2.jl` or `HDF5.jl` | Tensor storage for raw and processed data. | Nested metadata support, array layout, compression, cross-version stability. |
| `TOML.jl` / config reader package | Config and manifest parsing. | Exact TOML read/write behavior and type preservation. |
| `DataFrames.jl` + `CSV.jl` | Diagnostic tables and summary reports. | Table schema stability and CSV writing options. |
| `Plots.jl`, `Makie.jl`, or `CairoMakie.jl` | Optional phase plots and trajectory sanity plots. | Static figure export workflow and headless environment behavior. |
| `Test` | Unit, integration, and regression tests. | Testset organization and reference-output comparisons. |

No package API, constructor, keyword, or file format behavior should be assumed from memory.

---

## 8. Debugging and inspection plan

Save or print the following for every object:

- object id;
- parameter values;
- tensor shapes for `X`, `obs_phys`, `obs_aug_full`, `target_phys`;
- time grid length and step size;
- split counts;
- one-step pair counts;
- rollout window counts for $h=1,2,4,8,16$;
- amplitude group counts;
- min/max/mean/std of $q$ and $p$;
- maximum absolute state value;
- number of NaN/Inf entries;
- for L0, deviation from the discrete rotation recurrence;
- for L1, optional deviation from analytic $\exp(\tau A_{\mathrm{lin}})$ recurrence;
- for Duffing beta scan, object-level beta ordering and parameter consistency.

Dataset-side reports:

| Target path | Content |
|---|---|
| `reports/unit_internal/kdsm_basic_diagnostic_v1/tables/kdsm_basic_diagnostic_v1_object_summary.csv` | Object ids, parameters, tensor shapes, split counts. |
| `reports/unit_internal/kdsm_basic_diagnostic_v1/tables/kdsm_basic_diagnostic_v1_window_counts.csv` | One-step and rollout window counts. |
| `reports/unit_internal/kdsm_basic_diagnostic_v1/tables/kdsm_basic_diagnostic_v1_state_statistics.csv` | State ranges, means, stds, finite checks. |
| `reports/unit_internal/kdsm_basic_diagnostic_v1/plots/kdsm_basic_diagnostic_v1_phase_portraits.pdf` | Optional phase portraits for each object. |
| `reports/unit_internal/kdsm_basic_diagnostic_v1/logs/kdsm_basic_diagnostic_v1_generation.log` | Generation and validation log. |

---

## 9. Expected outputs

The final dataset release should contain:

1. Eight raw trajectory files.
2. Eight processed tensor files.
3. Eight object-level manifests.
4. One release-level manifest.
5. One release index.
6. One checksum file.
7. Config files for systems, observations, splits, windows, tasks, benchmark bundle, and release.
8. Smoke/integration/regression tests.
9. Human-readable diagnostic tables and optional plots.

The dataset must expose the weak Duffing beta ladder

$$

\beta\in\{0,10^{-4},10^{-3},5\times10^{-3},10^{-2},2\times10^{-2}\},

$$

with fixed $\alpha=1$, $\delta=0.08$, and $\gamma=0$. fileciteturn3file10

---

## 10. Failure points and debugging strategies

### Failure: linear systems fail downstream

Dataset-side diagnosis: first verify L0 recurrence and L1 analytic metadata. If these are correct, the issue likely belongs to downstream KDSM or data-loading logic.

### Failure: `obs_aug_full` has wrong dimension

Expected: since all objects are unforced, `obs_aug_full` must remain 2D and equal to `obs_phys`. Any dimension above 2 indicates leakage from the previous forced Duffing dataset design.

### Failure: split leakage

Expected: split must be assigned at trajectory level before any window construction. Regenerate split roles and window indices; never shuffle windows globally.

### Failure: beta scan does not show increasing nonlinearity metadata

Check parameter registry, object id mapping, and Duffing RHS parameters. The beta value in the config, manifest, and object id must agree.

### Failure: amplitude groups are empty or badly imbalanced

Check initial condition sampler. The default square $[-1,1]^2$ may not evenly populate all radial bands; this is acceptable only if recorded. For more balanced analysis, use a sampler that targets amplitude bands explicitly.

### Failure: raw and processed files disagree

Reload both, compare $\mathcal X$, `obs_phys`, `obs_aug_full`, and `target_phys`. For this dataset, all processed tensors should be identity-derived from raw state.

### Failure: manifests cannot reproduce generation

Manifest must include dataset version, object id, parameter values, seed policy, trajectory count, trajectory length, sampling interval, split id, observation ids, target ids, generator commit hash or equivalent project state, and file checksums. ODEs_dataset’s release manifest protocol requires version, registry versions, generator commit hash, and notes. fileciteturn2file0

---

## 11. Stop before code

This is the complete code-engineering plan for `kdsm_basic_diagnostic_v1` inside **ODEs_dataset**. It stops before implementation and does not include Julia code.