# HSKL Baseline ODE v1 Registry

`hskl_baseline_ode_v1` is a full-state, clean ODE release for formal HSKL baseline data binding.

Fixed fields:

- `benchmark_version = "hskl_baseline_ode_v1"`
- `observation_mode = "full_state"`
- `noise_level = "clean"`
- `array_layout = "state_dim_by_time_by_trajectory"`

Allowed system ids:

- `linear_diagonal`
- `linear_rotation_contraction`
- `linear_jordan_nonnormal`
- `damped_linear_oscillator`
- `van_der_pol`
- `duffing`
- `lotka_volterra`
- `fitzhugh_nagumo`
- `lorenz63`
- `rossler`
- `lorenz96`

Allowed split ids:

- `split_i_initial_condition`
- `split_p_parameter`

`split_o_observation` is excluded from this release because all saved observations are full state.
