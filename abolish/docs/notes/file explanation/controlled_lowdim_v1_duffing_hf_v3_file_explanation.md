# controlled_lowdim_v1 DUF-HF v3 File Explanation

## Task Summary

This task completed the `controlled_lowdim_v1` release and its trajectory-visualization deliverable, then synchronized the mathematical protocol with the implemented DUF-HF v3 profile. The DUF-HF source now emphasizes 9 Hz direct excitation and 17.5 Hz parametric excitation. The pure bilinear branch uses

$$
m\dot p=-dp-k\left[1-\rho_kc_{\mathrm{HF}}(t)\right]x-k_cx^3,
\qquad
\rho_k=12,
$$

with no additive force. AUG and ADD remain two learner views of the same additive physical trajectories.

The initial head-to-tail persistence test did not detect locally collapsed middle intervals. DUF-HF v3 therefore adds a 0.5 s sliding-window diagnostic with a 0.1 s stride and freezes the smallest candidate that passes every physical gate. The final candidate is $\rho_k=12$.

## Run Entry Points and Scripts

- `experiments/smoke_tests/run_controlled_lowdim_v1_smoke.jl` exercises the original four controlled bases on a minimal dataset.
- `experiments/smoke_tests/run_controlled_lowdim_v1_duffing_hf_bilinear_pilot.jl` evaluates the DUF-HF v3 bilinear candidate bank.
- `experiments/data_generation/generate_controlled_lowdim_v1_dataset.jl` generates the original twelve formal objects.
- `experiments/data_generation/generate_controlled_lowdim_v1_duffing_hf_dataset.jl` generates the three formal DUF-HF v3 objects after confirming the frozen pilot selection.
- `experiments/visualization/plot_controlled_lowdim_v1_trajectories.jl` validates the release manifest and creates two trajectory figures per object plus the consolidated report.

## Core Source, Configurations, and Documentation

- `src/data/controlled_lowdim_v1_generation.jl` implements the shared controlled low-dimensional dataset pipeline.
- `src/data/controlled_lowdim_v1_duffing_hf_generation.jl` implements the weighted phase-locked multisine, matched AUG/ADD views, pure bilinear stiffness modulation, physical candidate gates, formal generation, metadata, and reload checks.
- `configs/releases/controlled_lowdim_v1.json` freezes the original twelve-object release configuration.
- `configs/releases/controlled_lowdim_v1_duffing_hf.json` freezes DUF-HF artifact v3, source v2, base v3, $\rho_k=12$, and the continuous-window acceptance contract.
- `docs/notes/mathematical explanation/controlled_lowdim_v1.md` defines the synchronized fifteen-object mathematical protocol, including the DUF-HF energy balance, time-varying potential, weighted source, learner-interface distinction, and formal physical gates.

## Generated Data, Artifacts, Reports, and Logs

The current formal release is stored under `data/releases/controlled_lowdim_v1`. It contains 15 clean objects; the DUF-HF subset contains 768 trajectories per role with 2,000 state samples and 1,999 transitions per trajectory. The three DUF-HF metadata files identify artifact v3 and report successful formal diagnostics.

The report `reports/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization/odes_dataset_controlled_lowdim_v1_cld_v1_trajectory_visualization.md` embeds 30 figures: one two-component physical-state figure and one control/source figure for each of the 15 objects. Its tables retain the v1/v2/v3 BIL comparison and the v3 candidate scan.

The obsolete `runs/smoke_tests/controlled_lowdim_v1` smoke dataset and the superseded `controlled_lowdim_v1_duffing_hf_bilinear_pilot.json` v2 pilot were removed. The v3 formal release and `controlled_lowdim_v1_duffing_hf_bilinear_window_pilot.json` were preserved.

## Script-to-Script Data Flow

The release configuration is loaded by the source modules. The training-side DUF-HF pilot generates matched additive and bilinear trajectories for each candidate depth, evaluates physical gates, and writes the selected depth. The formal DUF-HF generator requires that pilot output, verifies that its selection matches the frozen configuration, generates the 768-trajectory release, and writes JLD2 data, metadata, parameters, trajectory manifests, generation reports, and the merged release manifest. The visualization entry point reads only the formal clean datasets and metadata, selects one continuously persistent matched DUF-HF trajectory, writes the plots and evidence tables, and assembles the report.

## Validation Commands and Results

- `julia --project=. experiments/smoke_tests/run_controlled_lowdim_v1_duffing_hf_bilinear_pilot.jl`: passed. Candidate 10 failed the continuous-window gate at `0.421875`; candidate 12 was the smallest complete pass at `0.96875`.
- `julia --project=. experiments/visualization/plot_controlled_lowdim_v1_trajectories.jl`: passed. It rendered 30 figures and verified 30 report image references.
- Focused JLD2 and metadata validation: passed. The release manifest reports 15 clean objects, all three DUF-HF objects are v3 and passed, and the AUG--ADD physical-state maximum absolute difference is `0.0`.
- Formal DUF-HF BIL evidence: continuous-window passing fraction `0.9765625`, median minimum-window relative RMS `0.5705570395729`, median work-to-damping ratio `0.9964579033746501`, median tail high-frequency energy ratio `0.35627498424223386`, BIL--ADD relative Frobenius difference `2.504586730040984`, and maximum absolute state `1.02295426328833`.
- Documentation/configuration/metadata consistency validation: passed. Artifact version, parameter versions, candidate depth, weighted frequencies, harmonic weights, acceptance thresholds, Markdown delimiters, and report figure counts are consistent.
