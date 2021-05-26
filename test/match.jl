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

# configurable "slurp" pattern
let
  try
    pat = :(__init__())

    @test isempty(MacroTools.IGNORED_SLURP_PATTERNS) # `IGNORED_SLURP_PATTERNS` should be empty by default
    @test (@capture(:(foo()), $pat), @capture(:(__init__()), $pat)) == (true, true)

    push!(MacroTools.IGNORED_SLURP_PATTERNS, :__init__)
    @test (@capture(:(foo()), $pat), @capture(:(__init__()), $pat)) == (false, true)
  finally
    empty!(MacroTools.IGNORED_SLURP_PATTERNS) # clean up
  end
end
