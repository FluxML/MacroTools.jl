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

# https://github.com/FluxML/MacroTools.jl/pull/149
let
  ex = :(sin(a, b))
  f = :sin
  @capture(ex, $f(args__))
  @test args == [:a, :b]
end

# hint to use `@capture_notb`
let
  ex = :(const GLOBAL_STRING = 10)
  @static if v"1.7.0-DEV" ≤ VERSION
    @test_throws ArgumentError macroexpand(@__MODULE__, :(@capture($ex, const GLOBAL_STRING = x_)))
  else
    # before v1.7, `macroexpand` throws `LoadError` instead of actual error
    @test_throws LoadError macroexpand(@__MODULE__, :(@capture($ex, const GLOBAL_STRING = x_)))
  end
end

# if we don't want to make `global_string` type bind syntax, we need to use `@capture_notb`
let
  ex = :(const global_string = 10)
  @capture_notb(ex, const global_string = x_)
  @test x === 10
end
