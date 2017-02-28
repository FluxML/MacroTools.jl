__precompile__(true)
module MacroTools

using Compat

export @match, @capture, @simplematch, @simplecapture

include("match.jl")
include("types.jl")
include("union.jl")
include("macro.jl")
include("utils.jl")

include("examples/destruct.jl")
include("examples/threading.jl")

end # module
