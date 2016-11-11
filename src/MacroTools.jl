__precompile__(true)
module MacroTools

using Compat

export @match, @capture

include("match.jl")
include("types.jl")
include("union.jl")
include("macro.jl")
include("utils.jl")

include("examples/destruct.jl")
include("examples/threading.jl")

end # module
