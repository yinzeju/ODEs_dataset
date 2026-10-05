# SKDM9 Beam extension

## Task summary

The SKDM9 learning task requested a separate certified long-trajectory Beam population. The extension is complete and remains independent of the active TestSub2 release. This producer does not train or evaluate models; B, pure MLP SKDM and PyKoopman formal comparisons were not executed in the consumer project.

## Entry points and sources

`experiments/data_generation/skdm9_beam_campaign.py` freezes and supervises `generate_skdm9_beam.jl`; `src/data/skdm9_beam_extension.jl` verifies the published CPU source capsule and reuses its equations, analytic Jacobian and Rodas5P/UMFPACK integration. `experiments/smoke_tests/skdm9_beam_extension.jl` covers the one-trajectory producer path.

## Data and flow

The immutable base binding is `add4a54bd864922b9c3c7cc3374ffe9ca6611d74bed638e54061fc1244938ba8`. Static midpoint transverse release amplitudes span0.0015–0.0025m, initial velocities are zero. The144 ordered amplitudes are split within six-point strata: offsets0,1,4,5 Train;2 Validation;3 Test. This is a narrow one-family amplitude grid, not broad arbitrary-state or velocity coverage.

Base capsule → independent generation configuration → certified raw trajectories → extension learner manifest → external learning project's Train-only reference and window adapter. `data/extensions/skdm9_beam_h512_v1` stores96/24/24 trajectories, each66 states and8193 frames. No large data is committed. Existing active pointers remain unchanged.

## Validation and report

The consumer's `runs/skdm_9/data_completion_verification.json` independently checked144 source/state hashes, disjoint splits, all worker exits and full counts. Maximum refinement error2.2150035506378005e-11 and energy error2.1969606742827447e-12 passed the1e-7 gates. Its learner manifest SHA is `bc5a9b8cc971da3b3459412d02b0a6f83150231c4fdbc7fdf447613327bcf46e`. A compact receipt is retained under this repository's `reports/skdm_9_TestSub2NV_beam_extension/evidence.json`.

The task-level Chinese report and paired numerical appendix are maintained once in the consumer project: `../InvSub/202609/reports/skdm/skdm_9_ssmlearn_beam_metric_comparison/`. They cover generation, reference, completed learners and unexecuted comparisons. Focused closeout checks verify this source scope and saved receipt, without regenerating trajectories or running Pkg.test.
