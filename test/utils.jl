using MacroTools: isdef, flatten, striplines

@testset "utils" begin
    ex1 = :(function foo(a) return a; end)
    @test isdef(ex1)
    ex2 = :(function bar(a)::Int return 1; end)
    @test isdef(ex2)
    ex3 = :(function foo(a::T) where T return a; end)
    @test isdef(ex3)
    ex4 = :(function bar(a::T)::Int where T return 1; end)
    @test isdef(ex4)
    ex5 = :(function bar(a::S, b::T)::Union{S,T} where {S,T} if rand() < 0.5 return a; end; return b; end)
    @test isdef(ex5)

    ex6 = :(f(a) = a)
    @test isdef(ex6)
    ex7 = :(f(a)::Int == 1)
    @test isdef(ex7)
    ex8 = :(f(a::T) where T = a)
    @test isdef(ex8)
    ex9 = :(f(a::T)::Int where T = 1)
    @test isdef(ex9)
    ex10 = :(f(a::S, b::T)::Union{S,T} where {S,T} = rand() < 0.5 ? a : b)
    @test isdef(ex10)
end

@testset "flatten try" begin # see julia#50710 and MacroTools#194
    exs = [
        quote try; f(); catch; end; end,
        quote try; f(); catch; else; finally; end; end,
        quote try; f(); catch E; else; finally; end; end,
        quote try; f(); catch; finally; end; end,
        quote try; f(); catch E; finally; end; end,
        quote try; f(); catch E; 3+3; finally; 4+4; end; end,
        quote try; f(); catch E; 3+3; else; 2+2; finally; 4+4; end; end,
    ]
    for ex in exs
        #@show ex
        @test flatten(ex) |> striplines == ex |> striplines
    end
    exs_bad = [
        quote try; f(); finally; end; end,
        quote try; f(); catch; false; finally; end; end |> MacroTools.striplines, # without striplines the error might not be trigger thanks to spurious line numbers
        quote try; f(); catch; else; end; end,
        quote try; f(); catch; else; finally; false; end; end |> MacroTools.striplines, # without striplines the error might not be trigger thanks to spurious line numbers
        quote try; f(); catch; 3+3; else; 2+2; end; end,
        quote try; f(); catch E; else; end; end,
        quote try; f(); catch E; 3+3; else; 2+2; end; end,
    ]
    for ex in exs_bad
        @test_throws ErrorException flatten(ex)
    end
    @test 123 == eval(MacroTools.flatten(MacroTools.striplines(:(try error() catch; 123 finally end))))
    @test 123 == eval(MacroTools.flatten(:(try error() catch; 123 finally end)))
    @test 234 == eval(MacroTools.flatten(MacroTools.striplines(:(try 1+1 catch; false; else 234; finally end))))
    @test 234 == eval(MacroTools.flatten(:(try 1+1 catch; false; else 234; finally end)))
end
