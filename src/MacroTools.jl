module MacroTools

export @match, @capture

include("match/match.jl")
include("match/types.jl")
include("match/union.jl")
include("match/macro.jl")

include("utils.jl")
include("structdef.jl")

include("examples/destruct.jl")
include("examples/threading.jl")
include("examples/forward.jl")

# Load and initialize animals symbols.
const animals = map(Symbol, eachline(joinpath(@__DIR__, "..", "animals.txt")))

end # module
