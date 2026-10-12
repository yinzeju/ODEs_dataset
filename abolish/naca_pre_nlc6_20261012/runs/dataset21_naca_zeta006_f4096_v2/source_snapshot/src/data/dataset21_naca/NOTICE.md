# Source attribution

This directory adapts the NACA wing finite-element formulation from
SSMTool / YetAnotherFEcode, by Shobhit Jain, Jacopo Marconi, Paolo Tiso and
contributors. The pinned SSMTool commit is
`de6cbc71427d23827feb9efd313cb63a1fc52ff8`.

The accompanying `LICENSE` reproduces the pinned repository's GPL version 3
license. New files in this module are marked `GPL-3.0-only`.
The source receipt in `configs/references/naca_sources.json` identifies every
retrieved reference and its SHA-256. Original reference files remain unmodified
in the ignored project source cache and can be fetched by the supplied helper.

`allman.jl` is an isolated adaptation of this project's earlier Julia Allman
translation. Membrane stabilization, bending energy, lumped mass, reference-frame
rotation and nonlinear in-plane shear terms follow the upstream implementation.
The new code adds bending strain recovery, arbitrary wing mesh assembly,
full-state Newmark integration, GPU element force/tangent kernels and dataset
qualification. It does not execute SSM reduction or approximate the truth model
with a truncated modal basis.

The original `ImplicitNewmark.m` defaults to algorithmic damping `alpha=0.005`.
This implementation deliberately uses the user's protocol choice `alpha=0`,
equivalently `beta=1/4, gamma=1/2`, with explicit Newton failure and refinement
gates. This numerical-method choice is not a claim of byte-for-byte MATLAB replay.
