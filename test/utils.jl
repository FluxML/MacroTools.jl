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

@testset "flatten" begin
    @test flatten(quote begin; begin; f(); g(); end; begin; h(); end; f(); end; end) |> striplines == quote f(); g(); h(); f() end |> striplines
end

@testset "flatten try" begin # see julia#50710 and MacroTools#194 # only tests that do not include `else` -- for the full set of tests see flatten_try.jl
    exs = [
        quote try; f(); catch; end; end,
        quote try; f(); catch; finally; end; end,
        quote try; f(); catch E; finally; end; end,
        quote try; f(); catch E; 3+3; finally; 4+4; end; end,
    ]
    for ex in exs
        @test flatten(ex) |> striplines == ex |> striplines
    end
end
