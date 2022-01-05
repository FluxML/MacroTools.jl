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

macro splitcombine2(fundef) # should be a no-op
    dict = splitdef(fundef)
    dict[:args] = map(arg->combineargdef(splitargdef(arg)), dict[:args])
    dict[:kwargs] = map(arg->combineargdef(splitargdef(arg)), dict[:kwargs])
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
    @test map(splitargdef, (:(f(a=2, x::Int=nothing, y::Any, args...))).args[2:end]) ==
        [Dict(:name=>:a, :is_splat=>false, :default=>2), Dict(:name=>:x, :type=>:Int, :is_splat=>false, :default=>:nothing),
         Dict(:name=>:y, :type=>:Any, :is_splat=>false), Dict(:name=>:args, :is_splat=>true)]
    @test splitarg(:(::Int)) == (nothing, :Int, false, nothing)
    @test splitargdef(:(::Int)) == Dict(:type=>:Int, :is_splat=>false)
    kwargs = splitdef(:(f(; a::Int = 1, b...) = 1))[:kwargs]
    @test map(splitarg, kwargs) ==
        [(:a, :Int, false, 1), (:b, :Any, true, nothing)]
    @test map(splitargdef, kwargs) ==
        [Dict(:name=>:a, :type=>:Int, :is_splat=>false, :default=>1), Dict(:name=>:b, :is_splat=>true)]
    args = splitdef(:(f(a::Int = 1) = 1))[:args]
    @test map(splitarg, args) == [(:a, :Int, false, 1)]
    @test map(splitargdef, args) == [Dict(:name=>:a, :type=>:Int, :is_splat=>false, :default=>1)]
    args = splitdef(:(f(a::Int ... = 1) = 1))[:args]
    @test map(splitarg, args) == [(:a, :Int, true, 1)]    # issue 165 
    @test map(splitargdef, args) == [Dict(:name=>:a, :type=>:Int, :is_splat=>true, :default=>1)]    # issue 165 

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
end

let
    @splitcombine2 foo(x) = x+2
    @test foo(10) == 12
    @splitcombine2 add(a, b=2; c=3, d=4)::Float64 = a+b+c+d
    @test add(1; d=10) === 16.0
    @splitcombine2 fparam(a::T) where {T} = T
    @test fparam([]) == Vector{Any}
    struct Orange end
    @splitcombine2 (::Orange)(x) = x+2
    @test Orange()(10) == 12
    @splitcombine2 fwhere(a::T) where T = T
    @test fwhere(10) == Int
    @splitcombine2 manywhere(x::T, y::Vector{U}) where T <: U where U = (T, U)
    @test manywhere(1, Number[2.0]) == (Int, Number)
    @splitcombine2 fmacro0() = @zeroarg
    @test fmacro0() == 1
    @splitcombine2 fmacro1() = @onearg 1
    @test fmacro1() == 2

    @splitcombine2 bar(; a::Int = 1, b...) = 2
    @test bar(a=3, x = 1, y = 2) == 2
    @splitcombine2 qux(a::Int... = 0) = sum(a)
    @test qux(1, 2, 3) == 6
    @test qux() == 0

    struct Foo{A, B}
        a::A
        b::B
    end
    # Parametric outer constructor
    @splitcombine2 Foo{A}(a::A) where A = Foo{A, A}(a,a)
    @test Foo{Int}(2) == Foo{Int, Int}(2, 2)

    @test (@splitcombine2 x -> x + 2)(10) === 12
    @test (@splitcombine2 (a, b=2; c=3, d=4) -> a+b+c+d)(1; d=10) === 16
    @test (@splitcombine2 ((a, b)::Tuple{Int,Int} -> a + b))((1, 2)) == 3
    @test (@splitcombine2 ((a::T) where {T}) -> T)([]) === Vector{Any}
    @test (@splitcombine2 ((x::T, y::Vector{U}) where T <: U where U) -> (T, U))(1, Number[2.0]) ==
          (Int, Number)
    @test (@splitcombine2 () -> @zeroarg)() == 1
    @test (@splitcombine2 () -> @onearg 1)() == 2
    @test (@splitcombine2 function (x) x + 2 end)(10) === 12
    @test (@splitcombine2 function (a::T) where {T} T end)([]) === Vector{Any}
    @test (@splitcombine2 function (x::T, y::Vector{U}) where T <: U where U
               (T, U)
           end)(1, Number[2.0]) == (Int, Number)
end

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

    @test_throws ArgumentError splitstructdef(:(call_ex(arg)))
end
