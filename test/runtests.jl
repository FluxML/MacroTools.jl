using MacroTools
using Compat, Compat.Test

@testset "MacroTools" begin

include("match.jl")
include("split.jl")
include("destruct.jl")
include("patch.jl")

end
