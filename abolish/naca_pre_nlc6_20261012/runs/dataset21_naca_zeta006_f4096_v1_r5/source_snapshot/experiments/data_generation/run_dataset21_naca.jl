# File: experiments/data_generation/run_dataset21_naca.jl
# This entry point does nothing unless the operator explicitly supplies --execute.
function parse_options(args)
    if isempty(args) || "--help" in args
        println("Usage: julia --project=configs/environments/dataset21_naca run_dataset21_naca.jl --execute --stage prepare|qualify|generate|verify [--config FILE] [--gmsh EXECUTABLE]")
        return nothing
    end
    "--execute" in args || error("Execution is disabled. Await the user's launch instruction before using --execute.")
    options=Dict("--config"=>joinpath(@__DIR__,"..","..","configs","releases","dataset21_naca_v1.json"),
        "--stage"=>"","--gmsh"=>"gmsh")
    i=1
    while i<=length(args)
        if args[i]=="--execute";i+=1;continue;end
        haskey(options,args[i]) || error("Unknown option $(args[i])")
        i<length(args) || error("Missing option value")
        options[args[i]]=args[i+1];i+=2
    end
    options["--stage"] in ("prepare","qualify","generate","verify") || error("An explicit stage is required")
    return options
end

options=parse_options(ARGS)
if options!==nothing
    include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
    cfg=Dataset21NACA.load_config(options["--config"])
    Dataset21NACA.BLAS.set_num_threads(1)
    if options["--stage"] in ("qualify","generate") && cfg["compute"]["backend"]!="cpu"
        try
            Base.include(Dataset21NACA,joinpath(@__DIR__,"..","..","src","data","dataset21_naca","gpu.jl"))
        catch exception
            cfg["compute"]["backend"]=="gpu" && rethrow()
            # Dependency loading failure is visible; numerical parity failures never fall back silently.
            @warn "CUDA could not be loaded; auto mode will use CPU" exception
        end
    end
    # CUDA is an optional module loaded above. Enter its newly defined methods
    # at the execution boundary (required by Julia 1.12 binding world ages).
    Base.invokelatest(Dataset21NACA.run_stage,options["--stage"],cfg;gmsh=options["--gmsh"])
end
