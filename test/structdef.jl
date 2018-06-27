using MacroTools: splitstructdef, combinestructdef

@testset "combinestructdef, splitstructdef" begin
    ex = :(struct S end)
    @test ex |> splitstructdef |> combinestructdef |> Base.remove_linenums! == 
        :(struct S <: Any end)
    
    @test splitstructdef(ex) == Dict(
        :constructors => Any[],
        :mutable => false,
        :params => Any[],
        :name => :S,
        :fields => Any[],
        :supertype => :Any)

    ex = :(mutable struct T end)
    @test splitstructdef(ex)[:mutable] === true
    @test ex |> splitstructdef |> combinestructdef |> Base.remove_linenums! == 
        :(mutable struct T <: Any end)

    ex = :(struct S{A,B} <: AbstractS{B}
                               a::A
                           end)
    @test splitstructdef(ex) == Dict(
        :constructors => Any[],
        :mutable => false,
        :params => Any[:A, :B],
        :name => :S,
        :fields => Any[(:a, :A)],
        :supertype => :(AbstractS{B}),)

    @test ex |> splitstructdef |> combinestructdef |> Base.remove_linenums! == 
        ex |> Base.remove_linenums!

    ex = :(struct S{A} <: Foo; S(a::A) where {A} = new{A}() end)
    @test ex |> splitstructdef |> combinestructdef |>
        Base.remove_linenums! |> MacroTools.flatten ==
        ex |> Base.remove_linenums! |> MacroTools.flatten

    constructors = splitstructdef(ex)[:constructors]
    @test length(constructors) == 1
    @test first(constructors) ==
        :((S(a::A) where A) = new{A}()) |> MacroTools.flatten

end
