using Pkg
Pkg.add("Literate")


using Literate
Literate.notebook("ApproximateComputations_Readme.jl", "."; execute=false)