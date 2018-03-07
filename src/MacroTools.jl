__precompile__(true)
module MacroTools

using Compat
using Compat.Markdown
export @match, @capture

include("match.jl")
include("types.jl")
include("union.jl")
include("macro.jl")
include("utils.jl")

include("examples/destruct.jl")
include("examples/threading.jl")
include("examples/forward.jl")

const animals = Symbol[]

function __init__()
  animals_file = joinpath(dirname(@__FILE__), "..", "animals.txt")
  _animals = split(read(animals_file, String))
  resize!(animals, length(_animals))
  animals .= Symbol.(lowercase.(_animals))
  Compat.Random.shuffle!(animals)
end

end # module
