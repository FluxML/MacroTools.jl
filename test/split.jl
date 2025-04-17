using MacroTools: splitstructdef, combinestructdef

macro nothing_macro()
end
@test @expand(@nothing_macro) === nothing

macro splitcombine(fundef) # should be a no-op
    dict = splitdef(fundef)
    dict[:args] = map(arg->combinearg(splitarg(arg)...), dict[:args])
    dict[:kwargs] = map(arg->combinearg(splitarg(arg)...), dict[:kwargs])
    esc(MacroTools.combinedef(dict))
end

# Macros for testing that splitcombine doesn't break
# macrocalls in bodies
macro zeroarg()
   :(1)
end
macro onearg(x)
   :(1+$(esc(x)))
end

let
    # Ideally we'd compare the result against :(function f(x)::Int 10 end),
    # but it fails because of :line and :block differences
    @test longdef(:(f(x)::Int = 10)).head == :function
    @test longdef(:(f(x::T) where U where T = 2)).head == :function
    @test shortdef(:(function f(x)::Int 10 end)).head != :function
    @test map(splitarg, (:(f(a=2, x::Int=nothing, y::Any, args...))).args[2:end]) ==
        [(:a, :Any, false, 2), (:x, :Int, false, :nothing),
         (:y, :Any, false, nothing), (:args, :Any, true, nothing)]
    @test splitarg(:(::Int)) == (nothing, :Int, false, nothing)
    kwargs = splitdef(:(f(; a::Int = 1, b...) = 1))[:kwargs]
    @test map(splitarg, kwargs) ==
        [(:a, :Int, false, 1), (:b, :Any, true, nothing)]
    args = splitdef(:(f(a::Int = 1) = 1))[:args]
    @test map(splitarg, args) == [(:a, :Int, false, 1)]
    args = splitdef(:(f(a::Int ... = 1) = 1))[:args]
    @test map(splitarg, args) == [(:a, :Int, true, 1)]    # issue 165

    @splitcombine foo(x) = x+2
    @test foo(10) == 12
    @splitcombine add(a, b=2; c=3, d=4)::Float64 = a+b+c+d
    @test add(1; d=10) === 16.0
    @splitcombine fparam(a::T) where {T} = T
    @test fparam([]) == Vector{Any}
    struct Orange end
    @splitcombine (::Orange)(x) = x+2
    @test Orange()(10) == 12
    @splitcombine fwhere(a::T) where T = T
    @test fwhere(10) == Int
    @splitcombine manywhere(x::T, y::Vector{U}) where T <: U where U = (T, U)
    @test manywhere(1, Number[2.0]) == (Int, Number)
    @splitcombine fmacro0() = @zeroarg
    @test fmacro0() == 1
    @splitcombine fmacro1() = @onearg 1
    @test fmacro1() == 2

    @splitcombine bar(; a::Int = 1, b...) = 2
    @test bar(a=3, x = 1, y = 2) == 2
    @splitcombine qux(a::Int... = 0) = sum(a)
    @test qux(1, 2, 3) == 6
    @test qux() == 0

    struct Foo{A, B}
        a::A
        b::B
    end
    # Parametric outer constructor
    @splitcombine Foo{A}(a::A) where A = Foo{A, A}(a,a)
    @test Foo{Int}(2) == Foo{Int, Int}(2, 2)

    @test (@splitcombine x -> x + 2)(10) === 12
    @test (@splitcombine (a, b=2; c=3, d=4) -> a+b+c+d)(1; d=10) === 16
    @test (@splitcombine ((a, b)::Tuple{Int,Int} -> a + b))((1, 2)) == 3
    @test (@splitcombine ((a::T) where {T}) -> T)([]) === Vector{Any}
    @test (@splitcombine ((x::T, y::Vector{U}) where T <: U where U) -> (T, U))(1, Number[2.0]) ==
          (Int, Number)
    @test (@splitcombine () -> @zeroarg)() == 1
    @test (@splitcombine () -> @onearg 1)() == 2
    @test (@splitcombine function (x) x + 2 end)(10) === 12
    @test (@splitcombine function (a::T) where {T} T end)([]) === Vector{Any}
    @test (@splitcombine function (x::T, y::Vector{U}) where T <: U where U
               (T, U)
           end)(1, Number[2.0]) == (Int, Number)
           
    # Test for lambda expressions with keyword arguments
    @test (@splitcombine (a::Int; b=2) -> a + b)(1) === 3
    @test (@splitcombine (a::Int; b::Float64=2.0) -> Float64(a) + b)(1) === 3.0
    @test (@splitcombine (a::Int, x; b=2, c=3) -> a + b + c + x)(1, 4) === 10
    @test (@splitcombine (a::Int, x=2) -> a + x)(1) === 3
    @test (@splitcombine (a::Int, x=2; y) -> a + x + y)(1; y=3) === 6
    @test (@splitcombine (a, x::Int=2; y) -> a + x + y)(1; y=3) === 6
    @test (@splitcombine (a::Int, x::Int=2; y) -> a + x + y)(1; y=3) === 6

    # With tuple unpacking
    @test (@splitcombine (((a, b)::Tuple{Int, Int}, c; d=1) -> a + b + c + d))((1, 2), 3; d=4) === 10
    @test (@splitcombine ((c, (a, b); d=1) -> a + b + c + d))(3, (1, 2); d=4) === 10
    @test (@splitcombine ((c, (a, b); d) -> a + b + c + d))(3, (1, 2); d=4) === 10

    # Test for single varargs argument in lambda
    @test splitdef(Meta.parse("(args...) -> 0"))[:args] == [:(args...)]
    @test (@splitcombine (args...) -> sum(args))(1, 2, 3) == 6
    @test (@splitcombine (args::Int...) -> sum(args))(1, 2, 3) == 6
    @test (@splitcombine (args::Int...; y=2) -> sum(args) + y)(1, 2, 3) == 8
    @test (@splitcombine (arg, args::Int...; y=2) -> arg + sum(args) + y)(1, 2, 3) == 8
    @test (@splitcombine (::Int...) -> 1)(1, 2, 3) === 1

    # Splatted keyword arguments
    @test (@splitcombine (a::Int; kws...) -> a + sum(values(kws)))(1; b=2, c=3) == 6
    @test (@splitcombine (; kws...) -> sum(values(kws)))(b=2, c=3) == 5
    @test (@splitcombine (a::Int; b, kws...) -> a + b + sum(values(kws)))(1; b=2, c=3) == 6
    @test (@splitcombine (a::Int; b=2, kws...) -> a + b + sum(values(kws)))(1; c=3) == 6

    # Both splatted positional and keyword arguments
    @test (@splitcombine (a::Int, args::Int...; kws...) -> a + sum(args) + sum(values(kws)))(1, 2, 3; b=4, c=5) == 15
    @test (@splitcombine (a, ::Int...; b, kws...) -> a + sum(values(kws)))(1, 2, 3; b=4, c=5) == 1 + 5

    # Issue with longdef
    ex = longdef(:((a::Int; b=2) -> a + b))
    any_kw(ex) = ex isa Expr ? (any_kw(ex.head) || any(any_kw, ex.args)) : ex == :kw
    @test any_kw(ex)
    ## ^Ensure we get a :kw expression in the output AST
    @test eval(ex) isa Function
    ## Shouldn't have issues evaluating
end

@testset "combinestructdef, splitstructdef" begin
    ex = :(struct S end)
    @test ex |> splitstructdef |> combinestructdef |> Base.remove_linenums! ==
        :(struct S <: Any end) |> MacroTools.striplines

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
        :(mutable struct T <: Any end) |> MacroTools.striplines

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
        :((S(a::A) where A) = new{A}()) |> MacroTools.striplines |> MacroTools.flatten

    @test_throws ArgumentError splitstructdef(:(call_ex(arg)))
end
