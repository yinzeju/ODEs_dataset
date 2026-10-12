# Run only the explicitly authorized NLC6 population. No qualification campaign.
"--execute" in ARGS || error("Explicit execution flag required")
include(joinpath(@__DIR__,"..","..","src","data","dataset21_naca","Dataset21NACA.jl"))
include(joinpath(@__DIR__,"..","..","src","data","dataset21_nlc6","Dataset21NLC6.jl"))
Base.include(Dataset21NACA,joinpath(Dataset21NACA.ROOT,"src/data/dataset21_naca/gpu.jl"))
Base.include(Dataset21NLC6,joinpath(Dataset21NACA.ROOT,"src/data/dataset21_nlc6/campaign.jl"))
index=findfirst(==("--config"),ARGS)
config_path=index===nothing ? joinpath(Dataset21NACA.ROOT,"configs/releases/dataset21_nlc6_v1.json") : abspath(ARGS[index+1])
Base.invokelatest(Dataset21NLC6.run_campaign,config_path)
