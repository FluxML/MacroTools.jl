using MacroTools
using Test

@testset "MacroTools" begin

include("match.jl")
include("split.jl")
include("destruct.jl")
include("utils.jl")
include("flatten_try.jl")

end
