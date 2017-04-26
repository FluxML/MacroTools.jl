using MacroTools
using Base.Test

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
  ex = :(type Foo
           x::Int
           y
         end)
  @capture(ex, type T_ fields__ end)
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

macro nothing_macro()
end
@test @expand(@nothing_macro) === nothing

let
    # Ideally we'd compare the result against :(function f(x)::Int 10 end),
    # but it fails because of :line and :block differences
    @test longdef(:(f(x)::Int = 10)).head == :function
    @test shortdef(:(function f(x)::Int 10 end)).head != :function
    name, args, kwargs, body, rtype = parsedef(:(foo(a, b::Int=2; c=3)::Int = a+b))
    @test (name, args, kwargs, body, rtype) ==
        (:foo, [:a, Expr(:kw, :(b::Int), 2)], [Expr(:kw, :c, 3)],
         MacroTools.striplines(quote a+b end), :Int)
    # == isn't defined on Nullables
    @test map(arg->parsearg(arg)[1:2], args) == [(:a, :Any), (:b, :Int)]
    @test isnull(parsearg(args[1])[3])
end

include("destruct.jl")
