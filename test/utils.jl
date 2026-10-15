using MacroTools: isdef, flatten, striplines, @qq

@testset "animals" begin
    @test MacroTools.animals isa Vector{Symbol}
    @test length(MacroTools.animals) == 214
    @test allunique(MacroTools.animals)
    @test all(islowercase ∘ first ∘ string, MacroTools.animals)
    @test !issorted(MacroTools.animals)
end

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
    ex7 = :(f(a)::Int = 1)
    @test isdef(ex7)
    ex8 = :(f(a::T) where T = a)
    @test isdef(ex8)
    ex9 = :(f(a::T)::Int where T = 1)
    @test isdef(ex9)
    ex10 = :(f(a::S, b::T)::Union{S,T} where {S,T} = rand() < 0.5 ? a : b)
    @test isdef(ex10)
    @test !isdef(:(f()))
    @test !isdef(:ix)
    @test isdef(:(function f end))  # This is an arbitrary decision. Arguably it could be called a
                                    # function declaration, and have `isdef` return false.
    @test isdef(:(x -> x+2))
    @test isdef(:(function (y) y - 4 end))

    # #204: a block wrapping a single definition is a definition, as in `splitdef`
    @test isdef(quote f(x) = x end)
    @test isdef(quote function f(x) x end end)
    @test isdef(quote x -> x + 2 end)
    @test isdef(quote function f end end)
    @test isdef(quote begin function f(x) x end end end)
    @test !isdef(quote f(x) = x; g(x) = x end)
    @test !isdef(quote x end)
end

@testset "rmlines & rmdocs" begin
    ex1 = quote
        foo(x) = x + 1
    end
    ex2 = quote
        "My own documentation"
        foo(x) = x + 1

        "This is a docstring"
        bar(x) = x + 2
    end
    ex3 = quote
        foo(x) = x + 1
        bar(x) = x + 2
    end
    @test !any(isline, MacroTools.striplines(ex1).args)
    @test !any(isline, MacroTools.striplines(ex2).args)
    @test MacroTools.striplines(MacroTools.stripdocs(ex2)) == MacroTools.striplines(ex3)
end


@testset "flatten" begin
    @test flatten(quote begin; begin; f(); g(); end; begin; h(); end; f(); end; end) |> striplines == quote f(); g(); h(); f() end |> striplines
end

@testset "prettify" begin
    # Test that prettify resolves function references to their names
    @test MacroTools.prettify(:($sin(2))) == :(sin(2))
    @test MacroTools.prettify(:($cos(x))) == :(cos(x))
end

@testset "flatten/prettify do blocks" begin # #84: the body of a `do` must stay a block
    ex = MacroTools.prettify(quote map(1:N) do n; f(n); end end)
    @test isexpr(ex, :do) && isexpr(ex.args[2].args[2], :block)
    @test ex.args[2].args[2].args == [:(f(n))]
    @test occursin("f(n)", string(ex))
    @test string(MacroTools.prettify(quote map(xs) do x; x end end)) == "map(xs) do x\n    x\nend"
    @test string(MacroTools.prettify(quote map(xs) do x; begin g(x); end; begin h(x); k(x); end; end end)) ==
        "map(xs) do x\n    g(x)\n    h(x)\n    k(x)\nend"
    @test flatten(striplines(:(f() do; g(); end))).args[2].args[2] == Expr(:block, :(g()))
    @test isexpr(flatten(striplines(:(f() do; end))).args[2].args[2], :block)
    @test eval(MacroTools.prettify(quote map(1:3) do n; abs2(n); end end)) == [1, 4, 9]
end

@testset "flatten/prettify struct, module and macro bodies" begin # they must stay blocks
    for ex in (:(struct A; x; end), :(module M; f() = 1; end), :(baremodule M; x = 1; end),
               :(macro m(x); x; end), :(struct A; begin x; end; end))
        p = MacroTools.prettify(ex)
        @test isexpr(p.args[end], :block)
        @test Core.eval(Module(), p) isa Any # evaluates without a syntax error
    end
    @test MacroTools.prettify(:(struct A; begin x; end; end)).args[3] == Expr(:block, :x)
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

## Test for @qq

macro my_fff_def(a)
    @qq function fff() $a end
end

@my_fff_def begin   # line where fff() is defined
    function g()    # line where fff()() is defined
        22
    end
end

@test which(fff,()).line == which(fff(),()).line - 1
