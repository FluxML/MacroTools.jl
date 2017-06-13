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

let
  ex = :(x[1])
  @test @match(ex, begin
    v_ref => v
  end) == ex

  @test @match(ex, begin
    v_call => v
  end) === nothing

  @test @match(:(x(1)), begin
    v_call => v
  end) == :(x(1))

  @test @match(:(x(1)), begin
    v_ref => v
  end) === nothing

  @test @match(ex, begin
    (v_ref | 
     (v_ref <= ub_)) => (v, ub)
  end) == (ex, nothing)

  @test @match(:(x <= 2), begin
    (v_ref | 
     (v_ref <= ub_)) => (v, ub)
  end) == nothing

  @test @match(:(x(3) <= 2), begin
    (v_call | 
     (v_ref <= ub_)) => (v, ub)
  end) == (:(x(3) <= 2), nothing)  # only the first pattern matches

  @test @match(:(x(3) <= 2), begin
    ((v_ref <= ub_) |
     v_call ) => (v, ub)
  end) == (:(x(3) <= 2), nothing)

  @test @match(:(x[1] <= 2), begin
    (v_ref | 
     (v_ref <= ub_)) => (v, ub)
  end) == (:(x[1]), :(2))
end

include("destruct.jl")
