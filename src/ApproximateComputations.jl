module ApproximateComputations

include("FittingFunctionApproximation.jl")
include("ASTReplacementApproximation.jl")


### Fitting functions exports
# Exporting the approximation wrapper type
export Approximation, Get

# Exporting function generation results types
export GeneratedFunctionType, ErrorResultsContainer

# Exporting getters for function result type
export GetAbsoluteError, GetMeanDifference, GetMedianDifference, GetMedianBenchmarkTime, GetMeanBenchmarkTime

# Exporting function selection functions
export GetFastestAcceptable, FilterFunctionList, GetFunctionName

# Export function visualisation plotting functions
export PlotApproximationFunctionResults, PlotApproximationFunctionDiff, PlotApproximationFunctionDiffHist, PlotMedianError, PlotMedianRuntime, PlotRuntimeErrorPair

# Export main function for generating replacement functions
export GenerateAllApproximationFunctions


### AST Replacement Exports
export Operator, Variable, TreeMember, ResetGlobalID, GetGlobalID
export EmulateTree, FullUnwrap, UnwrapTree, WrapTree, ReplaceSubTree, GetAllTrees, UpdateEnvironmentForFunction, print

end