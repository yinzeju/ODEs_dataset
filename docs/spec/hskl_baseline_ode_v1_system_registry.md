# HSKL Baseline ODE v1 System Registry

| system_id | layer | d_x | tau | burn_in_time | parameter_regimes |
| --- | --- | ---: | ---: | ---: | --- |
| `linear_diagonal` | `unit_internal` | 4 | 0.05 | 0.0 | `stable`, `mixed_decay`, `near_boundary` |
| `linear_rotation_contraction` | `unit_internal` | 4 | 0.05 | 0.0 | `low_frequency`, `medium_frequency`, `weakly_damped` |
| `linear_jordan_nonnormal` | `unit_internal` | 2 | 0.05 | 0.0 | `weak_nonnormal`, `strong_nonnormal`, `jordan_stress` |
| `damped_linear_oscillator` | `core` | 2 | 0.02 | 0.0 | `undamped`, `weak_damping`, `moderate_damping` |
| `van_der_pol` | `core` | 2 | 0.02 | 10.0 | `near_linear`, `limit_cycle`, `relaxation` |
| `duffing` | `core` | 2 | 0.02 | 0.0 | `single_well`, `double_well`, `transition` |
| `lotka_volterra` | `core` | 2 | 0.01 | 0.0 | `standard`, `mild_interaction`, `strong_interaction` |
| `fitzhugh_nagumo` | `core` | 2 | 0.02 | 20.0 | `excitable`, `oscillatory` |
| `lorenz63` | `stress` | 3 | 0.01 | 10.0 | `standard` |
| `rossler` | `stress` | 3 | 0.02 | 50.0 | `standard` |
| `lorenz96` | `stress` | 40 | 0.01 | 10.0 | `forcing_low`, `forcing_standard`, `forcing_high` |
