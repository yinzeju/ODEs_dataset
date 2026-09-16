# Code Engineering Guide  
## `kdsm_duffing_diagnostic_v1` for ODEs_dataset

主任务名称：

```text
kdsm_duffing_diagnostic_v1
```

本文档是 **ODEs_dataset 项目内的数据生成代码工程指南**，不是 KDSM 项目的训练、诊断或干预工程指南。数学说明已明确：本数据集只负责从 Duffing 参数族生成 `state / observation / target / split / metadata`，不训练 KDSM，也不判断干预是否有效。fileciteturn4file12

---

## 1. Confirmed task summary

本任务目标是在 `ODEs_dataset/` 工程中新增一个专门服务下游 KDSM 诊断激发实验的 Duffing 数据 release：

```text
kdsm_duffing_diagnostic_v1
```

生成对象为：

$$

\mathfrak T_q^{\mathrm{Duff}}
\longmapsto
(
\mathcal X_{\mathrm{aug}},
\mathcal X_{\mathrm{phys}},
\mathcal U_{\mathrm{forc}},
\mathcal A_{\mathrm{forc}},
\mathcal Z,
\mathcal Y,
\mathbf t,
\mathrm{metadata}
).

$$

工程侧必须实现：

- Duffing 增广自治动力系统；
- `force_none`、`force_harmonic_1`、`force_harmonic_2`，并预留 `force_lorenz_readout`；
- D0–D9 数据对象配置；
- `obs_aug_full` 与 `obs_phys_only`；
- `target_phys`、`target_aug_full`、`target_poly9`、`target_energy5`；
- clean 与 noisy observation / target 版本；
- trajectory-level split；
- raw / processed / manifest / release 分层保存。

ODEs_dataset 的工程原则是“协议库 + 数据工厂 + 评测基座”，并要求动力系统、观测链、split、window、task、manifest 分层组织。fileciteturn2file1

---

## 2. Task decomposition

### Task A — Register the dataset family

Purpose: register `kdsm_duffing_diagnostic_v1` as an ODEs_dataset release-level dataset family.

Main responsibility:

- define release id;
- define object id naming rule;
- register D0–D9 object list;
- define difficulty levels: `bounded`, `default`;
- define default numerical specification.

The fixed object table must include D0–D9, including `kdsm_duffing__D8_highdim_target_poly9` and `kdsm_duffing__D9_noise_scan__noise_<level>`.fileciteturn4file0

---

### Task B — Implement Duffing augmented dynamics protocol

Purpose: provide a reusable dynamics layer for controlled Duffing systems written as autonomous augmented ODEs.

Mathematical object:

$$

x=(q,p,u) \in \mathbb R^{2+d_u},

$$

$$

\dot q=p,
\qquad
\dot p=-\delta p-\alpha q-\beta q^3+\gamma A_\nu(u),
\qquad
\dot u=h_\nu(u).

$$

Engineering requirement:

- physical state and forcing state must be separable after integration;
- `d_u=0,2,4,3` must be supported for none, one-frequency, two-frequency, and Lorenz-readout forcing;
- forcing signal must be saved as a scalar tensor even when `d_u=0`.

---

### Task C — Implement forcing generator registry

Purpose: decouple Duffing physical dynamics from forcing system definitions.

Required forcing ids:

```text
force_none
force_harmonic_1
force_harmonic_2
force_lorenz_readout
```

First release priority:

```text
force_none
force_harmonic_1
force_harmonic_2
```

`force_lorenz_readout` should be registered but may be marked optional / stress-test only.

---

### Task D — Implement D0–D9 SystemSpec configs

Purpose: encode every diagnostic Duffing object as a declarative system configuration.

Object list:

```text
kdsm_duffing__D0_near_linear_damped
kdsm_duffing__D1_single_well_hardening
kdsm_duffing__D2_amplitude_frequency_drift
kdsm_duffing__D3a_double_well_local_left
kdsm_duffing__D3b_double_well_local_right
kdsm_duffing__D3_double_well_local_mixed
kdsm_duffing__D4_double_well_cross_well
kdsm_duffing__D5_periodic_forced_stable
kdsm_duffing__D6_two_frequency_forced
kdsm_duffing__D7_chaotic_forced
kdsm_duffing__D8_highdim_target_poly9
kdsm_duffing__D9_noise_scan__noise_clean
kdsm_duffing__D9_noise_scan__noise_1em4
kdsm_duffing__D9_noise_scan__noise_1em3
kdsm_duffing__D9_noise_scan__noise_1em2
kdsm_duffing__D9_noise_scan__noise_1em1
```

D3 has three saved variants: left well, right well, and mixed. D9 expands into one object per noise level.

---

### Task E — Implement observation and target specs

Purpose: generate all standardized processed objects.

Observation modes:

```text
obs_aug_full
obs_phys_only
```

Saved tensor names:

```text
observation_aug
observation_phys
observation_aug_noisy
observation_phys_noisy
```

Target modes:

```text
target_phys
target_aug
target_poly9
target_energy5
```

The math note requires at least these processed fields: `state_aug`, `state_phys`, `forcing_state`, `forcing_signal`, `time_grid`, observation tensors, target tensors, `split_roles`, and metadata.fileciteturn4file5

---

### Task F — Implement noise protocol

Purpose: create clean and noisy observation / target variants without corrupting ground-truth state trajectories.

Noise levels:

```text
noise_clean
noise_1em4
noise_1em3
noise_1em2
noise_1em1
```

Numerical rule:

$$

z_{m,\sigma}
=
z_m+\sigma D_z\epsilon_m,
\qquad
\epsilon_m\sim \mathcal N(0,I).

$$

Important engineering constraint:

- `state_aug`, `state_phys`, `forcing_state`, `forcing_signal`, and `time_grid` remain clean;
- noisy versions are additional processed tensors, not replacements;
- noise scaling matrix `D_z` must be saved or reproducible from metadata.

The math note fixes the same noise grid and states that noise is applied to specified observation / target versions, not to ground-truth trajectories.fileciteturn4file8

---

### Task G — Implement trajectory-level split

Purpose: produce official split roles before any downstream windowing.

Required split id:

```text
split_trajectory_I
```

Default counts:

```text
R_train = 48
R_val   = 8
R_test  = 8
```

Bounded / CI counts:

```text
R_train = 6
R_val   = 2
R_test  = 2
```

Engineering rule:

```text
split first, window later
```

ODEs_dataset also requires that train / val / test split be independent of scripts and that same-trajectory windows must not leak across subsets.fileciteturn4file13

---

### Task H — Save raw, processed, manifest, release objects

Purpose: preserve reproducibility and downstream usability.

ODEs_dataset should store:

- raw high-precision trajectory objects;
- processed fixed-sampling observation / target objects;
- official split information;
- metadata and release manifest.

This matches the long-term dataset policy: each system should store `raw`, `processed`, `splits`, and `metadata`, while freezing version, system id, split id, observation mode, difficulty level, and solver metadata.fileciteturn4file3

---

## 3. Sub-task specification

### A. Dataset family registration

Input:

- mathematical description file;
- ODEs_dataset object protocol;
- object id table D0–D9.

Output:

- release config;
- registry entry;
- object list;
- default and bounded generation plans.

Dependencies:

- none.

Diagnostic checks:

- every object id is unique;
- every object has one forcing id;
- every object has at least one observation mode and one target mode;
- D9 expands into five noise-specific objects.

---

### B. Dynamics implementation

Input:

- Duffing parameters $(\alpha,\beta,\delta,\gamma)$;
- forcing id;
- forcing parameters $\nu$;
- initial condition domain.

Output:

- augmented trajectory tensor;
- physical trajectory tensor;
- forcing state tensor;
- forcing scalar tensor.

Dependencies:

- forcing registry.

Diagnostic checks:

- `size(state_aug, 1) = 2 + d_u`;
- `size(state_phys, 1) = 2`;
- `size(forcing_state, 1) = d_u`;
- `size(forcing_signal, 1) = 1`;
- harmonic forcing radius remains close to 1;
- no NaN / Inf in trajectories;
- terminal amplitudes remain inside expected sanity bounds.

---

### C. Observation and target generation

Input:

- `state_aug`;
- `state_phys`;
- `forcing_state`;
- Duffing parameters.

Output:

- `observation_aug`;
- `observation_phys`;
- `target_phys`;
- `target_aug`;
- `target_poly9`;
- `target_energy5`.

Dependencies:

- raw / sampled trajectory object.

Diagnostic checks:

- `observation_aug` equals `state_aug` for clean augmented full mode;
- `observation_phys` equals `state_phys`;
- `target_phys` equals `state_phys`;
- `target_aug` equals `state_aug`;
- `target_poly9` has first dimension 9;
- `target_energy5` has first dimension 5;
- energy target uses the same $\alpha,\beta$ as the trajectory object.

---

### D. Noise generation

Input:

- clean observation tensors;
- clean target tensors if noisy target mode is enabled;
- train split roles for scale estimation;
- noise level.

Output:

- noisy observation tensors;
- optional noisy target tensors;
- noise scale metadata.

Dependencies:

- clean processed tensors;
- split roles.

Diagnostic checks:

- clean tensors unchanged;
- noise RMS is close to configured $\sigma$ after channel scaling;
- same seed reproduces identical noisy tensors;
- different noise ids produce distinct objects.

---

### E. Split generation

Input:

- number of trajectories $R$;
- split seed;
- desired train / val / test counts.

Output:

- `split_roles ∈ {train,val,test}^R`;
- split metadata.

Dependencies:

- object-level trajectory count.

Diagnostic checks:

- exact counts match config;
- no missing trajectory role;
- no trajectory assigned to multiple roles;
- split seed recorded.

---

### F. Manifest and release generation

Input:

- system config;
- observation config;
- split config;
- generated object paths;
- solver metadata;
- random seeds;
- dimension summary.

Output:

- object-level manifest;
- release-level manifest;
- release index.

Dependencies:

- all generated data.

Diagnostic checks:

- every manifest path exists;
- manifest dimensions match actual stored tensors;
- config hash / generation hash is saved;
- release id equals `kdsm_duffing_diagnostic_v1`;
- object id in manifest matches file name.

---

## 4. Directory and file plan

All paths are under:

```text
ODEs_dataset/
```

### 4.1 Documentation files

```text
docs/notes/mathematical explanation/kdsm_duffing_diagnostic_v1_math.md
```

Role: store the mathematical note that defines the dataset.

```text
docs/notes/code explanation/kdsm_duffing_diagnostic_v1_code_engineering_guide.md
```

Role: store this code engineering guide.

```text
docs/notes/file explanation/kdsm_duffing_diagnostic_v1_file_explanation.md
```

Role: after implementation, explain generated files, object ids, and release layout.

```text
docs/spec/object_registry.md
```

Role: append the new dataset family, object ids, and release id.

```text
docs/spec/project_task_list.md
```

Role: append this task as an ODEs_dataset data-generation task.

---

### 4.2 Config files

```text
configs/systems/kdsm_duffing_diagnostic_v1_systems.toml
```

Role: declare D0–D9 Duffing object specs, parameters, forcing ids, initial condition domains, trajectory counts, time span, solver tolerance policy.

```text
configs/observations/kdsm_duffing_diagnostic_v1_observations.toml
```

Role: declare `obs_aug_full`, `obs_phys_only`, clean / noisy observation variants, target modes, and channel normalization / noise-scale policy.

```text
configs/splits/kdsm_duffing_diagnostic_v1_split_trajectory_I.toml
```

Role: declare trajectory-level split counts and seeds.

```text
configs/windows/kdsm_duffing_diagnostic_v1_windows.toml
```

Role: define downstream-ready one-step, rollout, and statistics window specs, without generating KDSM-specific training objects.

```text
configs/tasks/kdsm_duffing_diagnostic_v1_tasks.toml
```

Role: declare dataset task objects such as one-step forecast, rollout-ready target, reconstruction target, noise robustness task. These are ODEs_dataset task specs, not KDSM losses.

```text
configs/benchmarks/kdsm_duffing_diagnostic_v1_benchmark.toml
```

Role: group all object ids, observation ids, target ids, split id, and default difficulty levels.

```text
configs/releases/kdsm_duffing_diagnostic_v1_release.toml
```

Role: freeze release id, object list, version, expected data paths, and manifest policy.

---

### 4.3 Source files

```text
src/dynamics/kdsm_duffing_diagnostic_v1_dynamics.jl
```

Role: implement Duffing augmented vector field responsibilities and forcing-state dimension logic.

Planned `##` sections:

```text
## Purpose and mathematical object
## Duffing parameter validation
## Forcing state dimension rules
## Augmented Duffing vector-field construction
## Physical-state extraction
## Forcing-state extraction
## Forcing-signal evaluation
## Numerical sanity checks
```

```text
src/dynamics/kdsm_duffing_diagnostic_v1_forcing.jl
```

Role: define forcing generator responsibilities.

Planned `##` sections:

```text
## Purpose and forcing registry boundary
## force_none specification
## force_harmonic_1 specification
## force_harmonic_2 specification
## force_lorenz_readout optional specification
## Forcing initial-condition construction
## Forcing readout validation
## Forcing invariant checks
```

```text
src/generators/kdsm_duffing_diagnostic_v1_generator.jl
```

Role: orchestrate trajectory generation from configs.

Planned `##` sections:

```text
## Purpose and generation pipeline
## Load system and release configs
## Build object-level generation plan
## Sample trajectory parameters and initial conditions
## Integrate augmented Duffing trajectories
## Assemble raw trajectory tensors
## Trigger processed-object generation
## Trigger split and manifest generation
## Write generation logs and status summary
```

```text
src/observations/kdsm_duffing_diagnostic_v1_observations.jl
```

Role: construct clean observations and targets.

Planned `##` sections:

```text
## Purpose and observation-chain boundary
## Build observation_aug
## Build observation_phys
## Build target_phys
## Build target_aug
## Build target_poly9
## Build target_energy5
## Target and observation dimension checks
```

```text
src/observations/kdsm_duffing_diagnostic_v1_noise.jl
```

Role: apply noise protocol to observation / target variants.

Planned `##` sections:

```text
## Purpose and noise protocol
## Select clean source tensors
## Estimate channel scales from train trajectories
## Generate seeded Gaussian perturbations
## Build noisy observation tensors
## Build optional noisy target tensors
## Save noise-scale metadata
## Noise reproducibility checks
```

```text
src/splits/kdsm_duffing_diagnostic_v1_splits.jl
```

Role: generate `split_trajectory_I`.

Planned `##` sections:

```text
## Purpose and split protocol
## Validate trajectory count
## Construct train validation test roles
## Apply deterministic split seed
## Save split_roles
## Split leakage checks
```

```text
src/datasets/kdsm_duffing_diagnostic_v1_dataset_objects.jl
```

Role: define dataset object assembly responsibilities.

Planned `##` sections:

```text
## Purpose and dataset-object boundary
## Raw trajectory object assembly
## Processed object assembly
## Observation and target object packing
## Split attachment
## Metadata attachment
## Object-level consistency checks
```

```text
src/manifests/kdsm_duffing_diagnostic_v1_manifests.jl
```

Role: generate object-level and release-level manifests.

Planned `##` sections:

```text
## Purpose and manifest boundary
## Object manifest schema
## Release manifest schema
## Solver metadata capture
## Random seed and config hash capture
## Tensor dimension summary
## Object path validation
## Manifest consistency checks
```

```text
src/io/kdsm_duffing_diagnostic_v1_io.jl
```

Role: manage paths and data serialization.

Planned `##` sections:

```text
## Purpose and storage boundary
## Raw data path rules
## Processed data path rules
## Manifest path rules
## Release index path rules
## Tensor save policy
## Tensor load policy
## Overwrite and append-only checks
```

```text
src/registries/kdsm_duffing_diagnostic_v1_registry.jl
```

Role: register system, observation, split, task, benchmark, release ids.

Planned `##` sections:

```text
## Purpose and registry boundary
## Register dataset family
## Register system objects D0 to D9
## Register forcing ids
## Register observation ids
## Register target ids
## Register split id
## Register release id
## Registry uniqueness checks
```

```text
src/diagnostics/kdsm_duffing_diagnostic_v1_data_checks.jl
```

Role: compute dataset-generation diagnostics only.

Planned `##` sections:

```text
## Purpose and data diagnostics boundary
## Tensor shape diagnostics
## Finite-value diagnostics
## Harmonic forcing radius diagnostics
## Energy target sanity diagnostics
## Noise RMS diagnostics
## Split count diagnostics
## Metadata completeness diagnostics
## Release summary diagnostics
```

Important: this file checks data quality only. It must not compute KDSM training diagnostics such as learned spectrum, Koopman loss, learned Gram matrix, or intervention success.

---

### 4.4 Experiment entry files

```text
experiments/smoke_tests/kdsm_duffing_diagnostic_v1_bounded_generation.jl
```

Role: generate bounded CI-scale data.

Planned `##` sections:

```text
## Purpose and bounded generation scope
## Load bounded release config
## Generate selected smoke objects
## Run data quality checks
## Save bounded manifests
## Print bounded release summary
```

```text
experiments/baseline_forecasting/kdsm_duffing_diagnostic_v1_release_generation.jl
```

Role: generate the full default release. The folder name is acceptable because ODEs_dataset already uses experiment categories; the script itself is a data release generation entry, not a learning baseline.

Planned `##` sections:

```text
## Purpose and full release scope
## Load default release config
## Generate all D0 to D9 objects
## Run release-level checks
## Save release manifests
## Save release index
## Print full release summary
```

---

### 4.5 Data output paths

Raw objects:

```text
data/raw/kdsm_duffing_diagnostic_v1/<object_id>/raw_trajectories.<ext>
```

Processed objects:

```text
data/processed/kdsm_duffing_diagnostic_v1/<object_id>/processed_tensors.<ext>
```

Object manifests:

```text
data/manifests/kdsm_duffing_diagnostic_v1/<object_id>/manifest.toml
```

Release manifest:

```text
data/releases/kdsm_duffing_diagnostic_v1/release_manifest.toml
```

Release index:

```text
data/releases/kdsm_duffing_diagnostic_v1/release_index.toml
```

Bounded CI release:

```text
data/releases/kdsm_duffing_diagnostic_v1_bounded/release_manifest.toml
```

---

### 4.6 Reports and logs

```text
reports/v1_core/kdsm_duffing_diagnostic_v1/tables/kdsm_duffing_diagnostic_v1_generation_summary.csv
```

Role: object-level summary table.

```text
reports/v1_core/kdsm_duffing_diagnostic_v1/tables/kdsm_duffing_diagnostic_v1_dimension_summary.csv
```

Role: tensor dimension table.

```text
reports/v1_core/kdsm_duffing_diagnostic_v1/tables/kdsm_duffing_diagnostic_v1_noise_summary.csv
```

Role: noise-level diagnostic table.

```text
reports/v1_core/kdsm_duffing_diagnostic_v1/plots/kdsm_duffing_diagnostic_v1_phase_portraits/
```

Role: optional phase portraits for selected objects.

```text
reports/v1_core/kdsm_duffing_diagnostic_v1/plots/kdsm_duffing_diagnostic_v1_forcing_signals/
```

Role: optional forcing signal plots.

```text
reports/v1_core/kdsm_duffing_diagnostic_v1/logs/kdsm_duffing_diagnostic_v1_generation.log
```

Role: human-readable generation log.

---

### 4.7 Test files

```text
test/unit/kdsm_duffing_diagnostic_v1_dynamics_test.jl
```

Checks:

- Duffing derivative dimension;
- forcing dimension;
- forcing readout shape;
- harmonic radius sanity.

```text
test/unit/kdsm_duffing_diagnostic_v1_observations_test.jl
```

Checks:

- observation and target dimensions;
- `target_poly9` dimension 9;
- `target_energy5` dimension 5;
- clean physical target consistency.

```text
test/unit/kdsm_duffing_diagnostic_v1_noise_test.jl
```

Checks:

- clean tensor immutability;
- seeded reproducibility;
- noise RMS scale.

```text
test/unit/kdsm_duffing_diagnostic_v1_split_test.jl
```

Checks:

- split counts;
- role validity;
- deterministic split.

```text
test/integration/kdsm_duffing_diagnostic_v1_bounded_generation_test.jl
```

Checks:

- bounded end-to-end generation;
- raw / processed / manifest paths exist;
- all required fields are saved.

```text
test/regression/kdsm_duffing_diagnostic_v1_release_regression_test.jl
```

Checks:

- object count;
- tensor dimensions;
- split sizes;
- manifest keys;
- release index stability.

Reference outputs:

```text
test/reference_outputs/kdsm_duffing_diagnostic_v1_bounded/
```

Role: small reference release for regression comparison.

---

## 5. Module / component responsibilities

### `src/dynamics/`

Responsible for ODE right-hand side and forcing-system mechanics only.

Must not:

- construct KDSM windows;
- define Koopman features;
- compute KDSM losses;
- interpret diagnostic success.

---

### `src/observations/`

Responsible for deterministic observation and target maps.

Must ensure:

$$

\mathcal Z_{\mathrm{aug}}\in\mathbb R^{d_x\times(M+1)\times R},

$$

$$

\mathcal Z_{\mathrm{phys}}\in\mathbb R^{2\times(M+1)\times R},

$$

$$

\mathcal Y_{\mathrm{poly9}}\in\mathbb R^{9\times(M+1)\times R},

$$

$$

\mathcal Y_{\mathrm{energy5}}\in\mathbb R^{5\times(M+1)\times R}.

$$

---

### `src/generators/`

Responsible for end-to-end generation orchestration.

Must preserve:

```text
config → sample initial conditions → integrate → observe → split → save → manifest
```

ODEs_dataset’s standard generation pipeline follows the same order: system sampling, trajectory generation, observation-chain processing, trajectory-level saving, split generation, window derivation, task instantiation, and manifest writing.fileciteturn4file13

---

### `src/splits/`

Responsible only for trajectory-level role assignment.

Must not:

- split windows;
- shuffle samples across trajectories;
- assign a single trajectory to multiple roles.

---

### `src/windows/`

This task only needs to provide config compatibility for downstream one-step / rollout / statistics windows. The data release does not need to materialize every possible KDSM window unless explicitly configured.

---

### `src/tasks/`

Responsible for ODEs_dataset benchmark task wrappers.

Allowed task meanings:

- one-step prediction task;
- rollout-ready sequence task;
- reconstruction / target-readout task;
- noise robustness task.

Not allowed:

- KDSM loss function;
- KDSM intervention rule;
- learned-spectrum evaluation.

---

### `src/diagnostics/`

Responsible for data-generation diagnostics:

- shapes;
- finite values;
- split counts;
- forcing sanity;
- noise magnitude;
- target consistency;
- manifest completeness.

Not responsible for KDSM module diagnostics.

---

## 6. Data flow and dimensions

### 6.1 Raw augmented trajectory

For object $o$, trajectory $r=1,\dots,R$, time index $m=0,\dots,M$:

$$

x_m^{(r)}=(q_m^{(r)},p_m^{(r)},u_m^{(r)}).

$$

Stored as:

```text
state_aug
```

with shape:

$$

(2+d_u)\times(M+1)\times R.

$$

---

### 6.2 Physical trajectory

Stored as:

```text
state_phys
```

with shape:

$$

2\times(M+1)\times R.

$$

---

### 6.3 Forcing state and forcing signal

Stored as:

```text
forcing_state
```

with shape:

$$

d_u\times(M+1)\times R.

$$

Stored as:

```text
forcing_signal
```

with shape:

$$

1\times(M+1)\times R.

$$

For `force_none`, `d_u=0`; the engineering choice should still keep `forcing_signal` as a valid zero tensor with first dimension 1.

---

### 6.4 Observations

```text
observation_aug
```

shape:

$$

(2+d_u)\times(M+1)\times R.

$$

```text
observation_phys
```

shape:

$$

2\times(M+1)\times R.

$$

Noisy versions keep the same shapes.

---

### 6.5 Targets

```text
target_phys
```

shape:

$$

2\times(M+1)\times R.

$$

```text
target_aug
```

shape:

$$

(2+d_u)\times(M+1)\times R.

$$

```text
target_poly9
```

shape:

$$

9\times(M+1)\times R.

$$

```text
target_energy5
```

shape:

$$

5\times(M+1)\times R.

$$

---

### 6.6 Split roles

```text
split_roles
```

shape:

$$

R.

$$

Values:

```text
train
val
test
```

---

### 6.7 Default scale

Default release:

```text
R = 64
M + 1 = 2049
tau = 0.05 or 0.1
train / val / test = 48 / 8 / 8
```

Bounded release:

```text
R = 10
M + 1 = 129
train / val / test = 6 / 2 / 2
```

These are exactly the recommended first-version and bounded CI sizes in the math note.fileciteturn3file2

---

## 7. Package and documentation plan

Candidate Julia package categories only; no API should be assumed before implementation.

### ODE integration

Candidates:

```text
OrdinaryDiffEq.jl / DifferentialEquations.jl ecosystem
SciMLBase.jl
```

Purpose:

- solve non-stiff and possibly chaotic Duffing ODEs;
- control tolerances;
- save sampled states on the fixed grid.

Documentation to check:

- ODE problem construction workflow;
- in-place vs out-of-place RHS conventions;
- fixed sampling / save-at behavior;
- solver tolerance options;
- event / divergence handling if needed;
- reproducibility under seeded initial conditions.

---

### Configuration

Candidates:

```text
TOML stdlib
JSON3.jl
YAML.jl
```

Purpose:

- read `configs/`;
- freeze generation configs;
- write manifests.

Documentation to check:

- nested array / dictionary serialization;
- numeric precision preservation;
- stable key ordering if config hashes are used.

---

### Data storage

Candidates:

```text
JLD2.jl
HDF5.jl
Arrow.jl for tables if needed
CSV.jl for summary tables
```

Purpose:

- store high-dimensional tensors;
- store manifest-adjacent table summaries;
- support later downstream loading from Koopman / KDSM projects.

Documentation to check:

- array dimension preservation;
- zero-row / zero-dimension array handling for `d_u=0`;
- metadata storage;
- compression options;
- cross-version compatibility.

---

### Tables and summaries

Candidates:

```text
DataFrames.jl
CSV.jl
```

Purpose:

- generation summary;
- dimension summary;
- noise summary;
- split summary.

Documentation to check:

- stable CSV writing;
- missing-value handling;
- column type stability.

---

### Plotting

Candidates:

```text
Plots.jl
CairoMakie.jl
Makie.jl
```

Purpose:

- optional phase portraits;
- forcing signal plots;
- noise sanity plots.

Documentation to check:

- non-interactive file output;
- backend setup;
- reproducible figure dimensions.

---

### Testing

Candidates:

```text
Test stdlib
Aqua.jl optional
```

Purpose:

- unit / integration / regression checks.

Documentation to check:

- testset organization;
- approximate numeric comparison;
- CI runtime control.

---

## 8. Debugging and inspection plan

### 8.1 Shape checks

For every object, print and save:

```text
object_id
d_u
size(state_aug)
size(state_phys)
size(forcing_state)
size(forcing_signal)
size(observation_aug)
size(observation_phys)
size(target_phys)
size(target_aug)
size(target_poly9)
size(target_energy5)
length(time_grid)
length(split_roles)
```

---

### 8.2 Split checks

For every object:

```text
count(train)
count(val)
count(test)
unique(split_roles)
split_seed
```

Failure if:

- counts do not match config;
- any trajectory role is missing;
- role values are outside allowed set.

---

### 8.3 Dynamics checks

For every object:

```text
maximum(abs, state_aug)
minimum / maximum q
minimum / maximum p
finite-value count
NaN count
Inf count
```

For harmonic forcing:

```text
max |c^2+s^2-1|
max |c1^2+s1^2-1|
max |c2^2+s2^2-1|
```

For double-well objects:

```text
left / right / mixed trajectory metadata counts
```

For D2:

```text
amplitude_shell counts
```

---

### 8.4 Target checks

For every object:

```text
target_phys == state_phys sanity
target_aug == state_aug sanity
target_poly9 first two channels equal q,p
target_energy5 first two channels equal q,p
energy channel consistency
```

---

### 8.5 Noise checks

For every noisy object:

```text
noise_level
noise_seed
channel_scale_min
channel_scale_max
empirical_noise_rms_by_channel
relative_noise_rms_by_channel
```

Failure if:

- clean source changed;
- empirical noise scale is grossly inconsistent with $\sigma$;
- noise seed missing;
- noisy tensor has wrong shape.

---

### 8.6 Manifest checks

For every object manifest:

```text
release_id
object_id
regime_id
forcing_id
obs_modes
target_modes
duffing_params
forcing_params
tau
M
R
noise_level
split_protocol
intended_diagnostics
solver_metadata
random_seed
data_paths
```

The math note requires these metadata fields, including release id, object id, forcing id, observation and target modes, Duffing parameters, forcing parameters, numerical scale, noise level, split protocol, and intended diagnostic tags.fileciteturn3file0

---

## 9. Expected outputs

### Formal release outputs

```text
data/releases/kdsm_duffing_diagnostic_v1/release_manifest.toml
data/releases/kdsm_duffing_diagnostic_v1/release_index.toml
```

### Object-level outputs

For each object id:

```text
data/raw/kdsm_duffing_diagnostic_v1/<object_id>/raw_trajectories.<ext>
data/processed/kdsm_duffing_diagnostic_v1/<object_id>/processed_tensors.<ext>
data/manifests/kdsm_duffing_diagnostic_v1/<object_id>/manifest.toml
```

### Report outputs

```text
reports/v1_core/kdsm_duffing_diagnostic_v1/tables/kdsm_duffing_diagnostic_v1_generation_summary.csv
reports/v1_core/kdsm_duffing_diagnostic_v1/tables/kdsm_duffing_diagnostic_v1_dimension_summary.csv
reports/v1_core/kdsm_duffing_diagnostic_v1/tables/kdsm_duffing_diagnostic_v1_noise_summary.csv
reports/v1_core/kdsm_duffing_diagnostic_v1/logs/kdsm_duffing_diagnostic_v1_generation.log
```

### Optional figure outputs

```text
reports/v1_core/kdsm_duffing_diagnostic_v1/plots/kdsm_duffing_diagnostic_v1_phase_portraits/
reports/v1_core/kdsm_duffing_diagnostic_v1/plots/kdsm_duffing_diagnostic_v1_forcing_signals/
```

### Regression outputs

```text
test/reference_outputs/kdsm_duffing_diagnostic_v1_bounded/
```

---

## 10. Failure points and debugging strategies

### Failure 1 — `force_none` creates shape inconsistency

Symptom:

- `forcing_state` cannot be saved because $d_u=0$.

Strategy:

- explicitly support zero-dimensional forcing state;
- always save `forcing_signal` as $1\times(M+1)\times R$;
- validate all object schemas on `D0`.

---

### Failure 2 — harmonic forcing radius drifts

Symptom:

$$

c^2+s^2 \not\approx 1.

$$

Strategy:

- tighten solver tolerances;
- check RHS sign convention;
- check initial phase construction;
- compare sampled forcing signal against expected sinusoidal range.

---

### Failure 3 — D4–D7 accidentally saved only physical observations

Symptom:

- downstream sees non-autonomous projection but metadata claims augmented input.

Strategy:

- require `observation_aug` for all forced objects;
- save `observation_phys` only as negative control;
- include `recommended_downstream_input = observation_aug` in manifest for D4–D7. The math note explicitly recommends augmented observations for forced objects and physical observations as negative control.fileciteturn3file3

---

### Failure 4 — noise contaminates ground-truth trajectories

Symptom:

- `state_aug` or `target_phys` changes across noise variants.

Strategy:

- generate noise only in processed observation / optional noisy target layer;
- compare clean hash before and after noise generation;
- keep D9 clean base object reproducible.

---

### Failure 5 — split leakage

Symptom:

- same trajectory appears in train and test windows downstream.

Strategy:

- save split roles at trajectory level;
- never split windows in the raw data generator;
- include split-role check in integration tests.

---

### Failure 6 — D8 target dimension not saved correctly

Symptom:

- `target_poly9` is not $9\times(M+1)\times R$.

Strategy:

- test polynomial target construction independently;
- verify first two rows equal $q,p$;
- save target dimension in manifest;
- mark `intended_diagnostics = ["rank", "rec"]`.

---

### Failure 7 — chaotic D7 trajectories diverge or become numerically unusable

Symptom:

- NaN / Inf;
- huge amplitudes;
- solver failure.

Strategy:

- record solver return status;
- enforce finite-value checks;
- optionally shorten bounded release horizon;
- keep default and stress-test tolerances separate in config.

---

### Failure 8 — object registry conflicts with existing Duffing configs

Symptom:

- duplicate system id or release id.

Strategy:

- use full prefix `kdsm_duffing__`;
- reserve `kdsm_duffing_diagnostic_v1` as release id;
- append-only registration in `docs/spec/object_registry.md`.

---

## 11. Stop before code

This guide stops at the code-engineering plan. It defines the ODEs_dataset-side configuration, files, data flow, diagnostics, release outputs, and failure checks for `kdsm_duffing_diagnostic_v1`.

No Julia code is included here.