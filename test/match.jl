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

# Bindings may reuse the name of the subject or of an interpolated variable
# https://github.com/FluxML/MacroTools.jl/issues/94
@testset "bindings shadowing inputs" begin
  ex = :(1 + 2)
  m = @capture(ex, ex_ + b_)
  @test m && (ex, b) == (1, 2)
  ex = :(f(x))
  @test !@capture(ex, ex_ + b_)
  @test ex === nothing && b === nothing
  x = :x
  m = @capture(:(f(1, x)), f(x_, $x))
  @test m && x == 1
  ex = :(1 + 2)
  @test @match(ex, begin ex_ + b_ => (ex, b) end) == (1, 2)
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

# https://github.com/FluxML/MacroTools.jl/issues/36
# https://github.com/FluxML/MacroTools.jl/issues/180
@testset "type binds inside unions" begin
  ex = :(x[1])
  @test @match(ex, begin v_ref => v end) == ex
  @test @match(ex, begin v_call => v end) === nothing
  @test @match(:(x(1)), begin v_call => v end) == :(x(1))
  @test @match(:(x(1)), begin v_ref => v end) === nothing

  @test @match(ex, begin
    (v_ref | (v_ref <= ub_)) => (v, ub)
  end) == (ex, nothing)
  @test @match(:(x <= 2), begin
    (v_ref | (v_ref <= ub_)) => (v, ub)
  end) === nothing
  @test @match(:(x[1] <= 2), begin
    (v_ref | (v_ref <= ub_)) => (v, ub)
  end) == (:(x[1]), 2)
  # the first matching branch wins
  @test @match(:(x(3) <= 2), begin
    (v_call | (v_ref <= ub_)) => (v, ub)
  end) == (:(x(3) <= 2), nothing)
  @test @match(:(x(3) <= 2), begin
    ((v_ref <= ub_) | v_call) => (v, ub)
  end) == (:(x(3) <= 2), nothing)
  @test @match(:x, begin
    (v_Symbol | (v_Symbol <= ub_)) => v
  end) == :x

  m = @capture(:(myvariable = 2), (lhs_Symbol = rhs_) | someotherpat)
  @test m && (lhs, rhs) == (:myvariable, 2)
  m = @capture(:x, (a_Symbol) | (a_::b_))
  @test m && a == :x
  m = @capture(4, (x_Int | x_String))
  @test m && x == 4
  m = @capture("a", (x_Int | x_String))
  @test m && x == "a"
  @test !@capture(4.0, (x_Int | x_String))
  # three-way unions, nested in a larger expression
  m = @capture(:(f(:a)), f(x_Symbol | x_quote | x_Int))
  @test m && x == Expr(:quote, :a)
end

@testset "interpolation inside unions" begin
  f = :sin
  m = @capture(:(sin(1)), $f(x_) | cos(x_))
  @test m && x == 1
  m = @capture(:(cos(2)), $f(x_) | cos(x_))
  @test m && x == 2
  @test !@capture(:(tan(2)), $f(x_) | cos(x_))
end

@testset "interpolated values are not rewritten" begin
  my_func = :my_func
  m = @capture(:(my_func(1)), $(my_func)(x_))
  @test m && x == 1
  a, b = 1, 2
  @test @capture(:(f(3)), f($(a | b)))
end

# https://github.com/FluxML/MacroTools.jl/issues/193
@testset "unions match whatever their branches match" begin
  ex = :(begin; x = 2; y = 3; end)
  @test @capture(ex, begin body_ end)
  m = @capture(ex, begin body_ end | for i_ in iter_ forbody_ end)
  @test m && body == ex
  ex = :(begin; x = 2; end)
  m = @capture(ex, begin body_ end | for i_ in iter_ forbody_ end)
  @test m && body == ex
  ex = :(for i in 1:3; f(i); end)
  m = @capture(ex, for i_ in iter_ forbody_ end | begin body_ end)
  @test m && (i, iter, body) == (:i, :(1:3), nothing)
end

# Interpolations and type binds in `@match` are evaluated in the caller's scope
module TestMatchScope
using MacroTools, Test
struct Foo end
matchname(ex, name) = @match ex begin
  $name => :same
  _ => :different
end
matchfoo(ex) = @match ex begin
  (x_Foo | f(x_Foo)) => x
  _ => nothing
end
@testset "@match scope" begin
  @test matchname(:a, :a) === :same
  @test matchname(:a, :b) === :different
  @test matchfoo(Foo()) === Foo()
  @test matchfoo(Expr(:call, :f, Foo())) === Foo()
  @test matchfoo(:(f(1))) === nothing
end
end
