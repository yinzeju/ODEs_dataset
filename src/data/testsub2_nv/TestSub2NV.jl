module TestSub2NV

using LinearAlgebra, SparseArrays, Random, SHA, Dates
using SciMLBase: ODEFunction, ODEProblem, solve, successful_retcode, DiscreteCallback, u_modified!
using OrdinaryDiffEqRosenbrock: Rodas5P
using OrdinaryDiffEqTsit5: Tsit5
using LinearSolve: KLUFactorization
using JLD2: jldopen
import JSON

include("triangular_shell.jl")
include("models.jl")
include("integration.jl")
include("release.jl")

end
