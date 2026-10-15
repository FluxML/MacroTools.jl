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

# Names containing underscores are read as expression types; macro names never
# are, and other names can be matched literally by interpolating them.
# https://github.com/FluxML/MacroTools.jl/issues/192
# https://github.com/FluxML/MacroTools.jl/pull/160
@testset "names containing underscores" begin
  m = @capture(:(@code_warntype f(1)), @code_warntype args__)
  @test m && args == [:(f(1))]
  ok = @capture(:(@code_warntype f(1)), @mac_ args__)
  @test ok && mac == Symbol("@code_warntype")
  @test !@capture(:(@show f(1)), @code_warntype args__)

  ex = :(global_string = 10)
  @test !@capture(ex, global_string = n_)
  m = @capture(ex, $(:global_string) = n_)
  @test m && n == 10
  name = :global_string
  m = @capture(ex, $name = n_)
  @test m && n == 10
  @test @match(:(my_func(1)), begin
    $(:my_func)(x_) => x
  end) == 1
end

# https://github.com/FluxML/MacroTools.jl/pull/200
module TestExplicitImport
using MacroTools: @capture
@capture(:(x = 2), _lhs = _rhs)
end
