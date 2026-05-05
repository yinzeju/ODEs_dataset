# HSKL Baseline ODE v1 Release Manifest Schema

The manifest is written to `data/releases/hskl_baseline_ode_v1/metadata/release_manifest.json`.

Required top-level fields:

- `benchmark_version`
- `created_at`
- `formal_difficulty_levels`
- `observation_mode`
- `noise_level`
- `profiles`
- `systems`
- `objects`
- `generated_files`
- `failure_counters`

Each object records the system id, difficulty level, split id, parameter regime, tensor shape, split counts, window feasibility, validation status, and relative paths to raw and processed JLD2 files.
