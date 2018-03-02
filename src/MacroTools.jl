__precompile__(true)
module MacroTools

using Compat
using Compat.Markdown
using Compat.Random
export @match, @capture

include("match.jl")
include("types.jl")
include("union.jl")
include("macro.jl")
include("utils.jl")

include("examples/destruct.jl")
include("examples/threading.jl")
include("examples/forward.jl")

animals_file = joinpath(dirname(@__FILE__), "..", "animals.txt")
const animals = shuffle(Symbol.(lowercase.(split(read(animals_file, String)))))

end # module
