# HSKL Baseline ODE v1 Observation Protocol

This release is full-state and clean only.

For every saved trajectory,

```math
z_m = x_m,
\qquad
y_m = x_m,
\qquad
d_z = d_y = d_x.
```

No sensor matrix, nonlinear observation map, stochastic perturbation, denoising target, or noisy input is applied.
