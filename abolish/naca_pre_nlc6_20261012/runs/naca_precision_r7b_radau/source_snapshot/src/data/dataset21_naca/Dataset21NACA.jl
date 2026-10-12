# SPDX-License-Identifier: GPL-3.0-only
module Dataset21NACA

using LinearAlgebra, SparseArrays, SHA, Random, Statistics
import Arpack, FFTW, HDF5, JLD2, JSON

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const UPSTREAM_COMMIT = "de6cbc71427d23827feb9efd313cb63a1fc52ff8"
portable_relative(path,root)=replace(relpath(path,root),'\\'=>'/')

filehash(path) = open(path, "r") do io
    bytes2hex(sha256(io))
end
function writejson(path, value)
    mkpath(dirname(path))
    temporary = path * ".tmp"
    open(temporary, "w") do io
        print(io, JSON.json(value), '\n')
    end
    mv(temporary, path; force=true)
    return path
end

# Isolated adaptation of the existing translation; frozen Dataset-2 code is unchanged.
include("allman.jl")
include("mesh.jl")
include("mechanics.jl")
include("newmark.jl")
include("radau.jl")
include("qualification.jl")
include("campaign.jl")

export read_mesh, assemble, run_stage, load_config
end
