# Duffing Augmented SNR10 Dataset Report

## Objective and Scope
This report records the `duffing_aug_snr10` data generation run for a forced single-degree-of-freedom Duffing oscillator with autonomous forcing-phase augmentation. The generated clean and 10 dB noisy views are strictly paired by trajectory, split, initial condition, forcing realization, phase state, and model time grid.

## Method
The physical state is `y = [x, v]`, and the learner input is `z = [x, v, u, cos(theta), sin(theta)]`. Clean targets remain `[x, v]` for both clean and noisy-input views. Physical states were integrated with a local adaptive DOPRI5 method using `RelTol = 1e-10` and `AbsTol = 1e-12`; the physical channels were anti-aliased by a shared zero-phase FIR filter before 4:1 decimation from 2000 Hz to 500 Hz. The forcing phase and forcing signal were evaluated analytically on the model grid to preserve the phase-circle and forcing-template constraints.

## Variables and Parameters
| Quantity | Value |
| --- | --- |
| Mass `m` | `1.0` |
| Damping `c` | `40.0` |
| Linear stiffness `k` | `3000.0` |
| Cubic stiffness `k_c` | `5.0e8` |
| Forcing amplitude | `20.0` |
| Base frequency | `0.5 Hz` |
| Model snapshots per trajectory | `2000` |
| Split counts | `Dict("test" => 128, "val" => 128, "train" => 512)` |

## Noise and Coordinate Policy
| Quantity | Value |
| --- | --- |
| Training power x | `1.2564427357413824e-6` |
| Training power v | `0.004943972455070052` |
| Noise std x | `0.00035446335998821975` |
| Noise std v | `0.02223504543523591` |
| Empirical SNR x | `9.993356463927531 dB` |
| Empirical SNR v | `9.9927816783009 dB` |
| Dataset normalization | `none`; raw physical coordinates |

## Validation
| Check | Result |
| --- | --- |
| All arrays finite | `true` |
| Phase circle max error | `2.220446049250313e-16` |
| Forcing consistency max error | `1.9255708139098715e-12` |
| Empirical SNR within 0.2 dB | `true` |
| Split isolated by trajectory | `true` |
| Windows cross trajectory boundary | `false` |
| Overall passed | `true` |

## Outputs
The clean and noisy physical-unit tensors are saved in JLD2 format. Metadata records the recommended `.mat` interface names from the task note, but this project run uses the existing `JLD2 + JSON` persistence stack to avoid adding a new MAT dependency.

## Limitations and Next Steps
The generated data are a formal local release object rather than a smoke artifact. Downstream KDSM-MP training should construct windows by trajectory-local indices using the recorded horizon set `{1,2,4,8,16,32,64,128}`.
