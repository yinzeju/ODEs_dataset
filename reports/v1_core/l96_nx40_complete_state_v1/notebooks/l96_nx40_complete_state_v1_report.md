# Lorenz96 Nx40 Complete-State v1 Dataset Report

## Objective and Scope

This report records the formal generation of `l96_nx40_complete_state_v1`, a complete-state Lorenz96 dataset for high-dimensional autonomous chaotic dynamics. The dataset contains only raw physical-coordinate trajectories, trajectory-level splits, and acceptance diagnostics. It does not include standardization, normalization, model training, learned dictionaries, kernels, controls, partial observations, or noise injection.

The learning object is `z_m = y_m = x_m in R^40`, sampled from the numerical flow `F_num^tau` with `tau = 0.05`.

## Method and Configuration

| Quantity | Value |
| --- | --- |
| State dimension | 40 |
| Forcing `F0` | 8.0 |
| RK4 internal step `dt_internal` | 0.005 |
| Save stride `q_save` | 10 |
| Learning interval `tau` | 0.05 |
| Burn-in time / steps | 100.0 / 20000 |
| One-step pairs per trajectory | 2048 |
| Snapshots per trajectory | 2049 |
| Trajectories train / val / test | 288 / 96 / 96 |
| Master seed | 20260624 |
| Maximum rollout horizon | 64 |

The vector field uses periodic indexing:

$$
\frac{dx_j}{dt} = (x_{j+1} - x_{j-2})x_{j-1} - x_j + F_0,\qquad j=1,\ldots,40.
$$

Initial states are sampled as `F0 * ones(40) + 0.01 * xi`, where each trajectory uses a spawned trajectory seed recorded in `metadata.json` and `splits.json`.

## Dataset and Splits

| Split | Trajectories | Tensor shape | One-step pairs | Valid h_max windows |
| --- | ---: | --- | ---: | ---: |
| train | 288 | [288, 2049, 40] | 589824 | 571680 |
| val | 96 | [96, 2049, 40] | 196608 | 190560 |
| test | 96 | [96, 2049, 40] | 196608 | 190560 |

The split is trajectory-level. No trajectory is shared across train, validation, and test.

## Validation Protocol and Results

| Check | Result |
| --- | --- |
| Shape check | true |
| Finite-value check | true |
| Periodic boundary check | true |
| RK4 step-size consistency accepted | true |
| Mean relative RK difference `epsilon_RK` | 1.211238743001693e-8 |
| Maximum relative RK difference | 4.1958652308413425e-8 |
| Overall acceptance | true |

## Energy Diagnostics

| Metric | Value |
| --- | ---: |
| State range min | -11.52720539159384 |
| State range max | 18.198655602563182 |
| State span | 29.725860994157024 |
| Mean trajectory energy mean | 9.374898777483443 |
| Min trajectory energy mean | 9.097517858433712 |
| Max trajectory energy mean | 9.702719003438807 |
| Max absolute late-minus-early trajectory energy | 0.7282889597776361 |

| Split | Energy mean | Energy std | Energy min | Energy max |
| --- | ---: | ---: | ---: | ---: |
| train | 9.366912326517387 | 0.9420729959169019 | 5.974516437541213 | 13.606097454423864 |
| val | 9.382485684323743 | 0.9345106837223903 | 5.898998859936392 | 13.36728492177268 |
| test | 9.391271223541303 | 0.9467483096131774 | 6.094226385751368 | 13.361393453708905 |

The early/late energy diagnostic is recorded for quality inspection only. It was not used to remove trajectories.

## Reproducibility Notes

The generated dataset root is `data/releases/l96_nx40_complete_state_v1/`. Split tensors are JLD2 files with layout `trajectory_by_time_by_state`, and metadata, split, and diagnostic files are JSON. The generation log and report-local CSV tables are stored under `reports/v1_core/l96_nx40_complete_state_v1/`.

Main generated files:

- `dataset_root`: `D:\MyVault\Projects\Julia\ODEs_dataset\data\releases\l96_nx40_complete_state_v1`
- `diagnostics_summary`: `D:\MyVault\Projects\Julia\ODEs_dataset\data\releases\l96_nx40_complete_state_v1\diagnostics\diagnostics_summary.json`
- `energy_table`: `D:\MyVault\Projects\Julia\ODEs_dataset\reports\v1_core\l96_nx40_complete_state_v1\tables\trajectory_energy_statistics.csv`
- `integration_check`: `D:\MyVault\Projects\Julia\ODEs_dataset\data\releases\l96_nx40_complete_state_v1\diagnostics\integration_check.json`
- `log`: `D:\MyVault\Projects\Julia\ODEs_dataset\reports\v1_core\l96_nx40_complete_state_v1\logs\generate_l96_nx40_complete_state_v1.log`
- `metadata`: `D:\MyVault\Projects\Julia\ODEs_dataset\data\releases\l96_nx40_complete_state_v1\metadata.json`
- `report`: `D:\MyVault\Projects\Julia\ODEs_dataset\reports\v1_core\l96_nx40_complete_state_v1\notebooks\l96_nx40_complete_state_v1_report.md`
- `splits`: `D:\MyVault\Projects\Julia\ODEs_dataset\data\releases\l96_nx40_complete_state_v1\splits.json`
- `summary_table`: `D:\MyVault\Projects\Julia\ODEs_dataset\reports\v1_core\l96_nx40_complete_state_v1\tables\diagnostics_summary.csv`
- `test_trajectories`: `D:\MyVault\Projects\Julia\ODEs_dataset\data\releases\l96_nx40_complete_state_v1\test\trajectories.jld2`
- `train_trajectories`: `D:\MyVault\Projects\Julia\ODEs_dataset\data\releases\l96_nx40_complete_state_v1\train\trajectories.jld2`
- `trajectory_statistics`: `D:\MyVault\Projects\Julia\ODEs_dataset\data\releases\l96_nx40_complete_state_v1\diagnostics\trajectory_statistics.json`
- `val_trajectories`: `D:\MyVault\Projects\Julia\ODEs_dataset\data\releases\l96_nx40_complete_state_v1\val\trajectories.jld2`

## Limitations and Next Steps

This release contains only the clean complete-state, fixed-forcing Lorenz96 configuration. Downstream tasks should derive one-step and rollout windows by index inside each split and should apply any needed preprocessing outside this dataset release.
