using MacroTools
using Compat
using Compat.Test

let
  x = @match :(2+3) begin
    (a_+b_) => (a, b)
    (a_-b_) => (b, a)
  end
  @test x == (2, 3)
end

let
  x = @match :(2-3) begin
    (a_+b_) => (a, b)
    (a_-b_) => (b, a)
  end
  @test x == (3, 2)
end

let
  x = @match :(2/3) begin
    (a_+b_) => (a, b)
    (a_-b_) => (b, a)
  end
  @test x == nothing
end

let
  x = @match :(2/3) begin
    (a_+b_) => (a, b)
    (a_-b_) => (b, a)
    _ => :default
  end
  @test x == :default
end

let
  ex = :(mutable struct Foo
           x::Int
           y
         end)
  @capture(ex, mutable struct T_ fields__ end)
  @test T == :Foo
  @test fields == [:(x::Int), :y]

  @capture(ex, mutable struct T_ fields__ end)
  @test T == :Foo
  @test fields == [:(x::Int), :y]
end

let
  ex = :(f(x))
  @capture(ex, f_(xs__))
  @test f == :f
  @test xs == [:x]
end

let
  ex = :(f(x, y, z))
  @capture(ex, f_(x_, xs__))
  @test f == :f
  @test x == :x
  @test xs == [:y, :z]
end

let
  ex = quote
    function foo(a, b)
      return a+b
    end
  end
  @assert @capture(shortdef(ex), f_(args__) = body_)
end

let
  ex = :(a = b)
  @capture(ex, a_ = b_)
  @test (a, b) == (:a, :b)
end

let
  ex = :(f(a = b))
  @capture(ex, f(a_ = b_))
  @test (a, b) == (:a, :b)
  @capture(ex, f(x_))
  @test isexpr(x, :kw)
end

let
  ex = :(@foo(a,b))
  @capture(ex, @foo(a_,b_))
  @test (a, b) == (:a, :b)
end

macro nothing_macro()
end
@test @expand(@nothing_macro) === nothing

macro splitcombine(fundef) # should be a no-op
    dict = splitdef(fundef)
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
    @test map(splitarg, (:(f(a=2, x::Int=nothing, y, args...))).args[2:end]) ==
        [(:a, :Any, false, 2), (:x, :Int, false, :nothing),
         (:y, :Any, false, nothing), (:args, :Any, true, nothing)]
    @test splitarg(:(::Int)) == (nothing, :Int, false, nothing)

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

    struct Foo{A, B}
        a::A
        b::B
    end
    # Parametric outer constructor
    @splitcombine Foo{A}(a::A) where A = Foo{A, A}(a,a)
    @test Foo{Int}(2) == Foo{Int, Int}(2, 2)
end

include("destruct.jl")
include("structdef.jl")
