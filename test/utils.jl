using MacroTools: isdef

@testset "utils" begin
    ex1 = :(function foo(a) return a; end)
    @test isdef(ex1)
    ex2 = :(function bar(a)::Int return 1; end)
    @test isdef(ex2)
    ex3 = :(f(a) = a)
    @test isdef(ex3)
    ex4 = :(f(a)::Int = 1)
    @test isdef(ex4)
end
