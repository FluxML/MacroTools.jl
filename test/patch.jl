using MacroTools: textwalk, @capture, isexpr
using Test

@test textwalk(x -> x==:a ? :b : x, "a*2") == "b*2"
@test textwalk(x -> x==:a ? :b : x, "a * 2") == "b * 2"
@test textwalk(x -> x == :a ? 2 : x, "a * b * c") == "2 * b * c"
@test textwalk(x -> x == :* ? :f : x, "a * b") == "f(a, b)"

@test textwalk(x -> x == :a ? :(a+1) : x, "a * 2") == "(a + 1) * 2"
@test textwalk(x -> x == :a ? :(a+1) : x, "*(a, 2)") == "*(a + 1, 2)"

@test textwalk(x -> x isa String ? :(uppercase($x)) : x, """
  bar("baz")
  """) == """
  bar(uppercase("baz"))
  """

@test textwalk(x -> isexpr(x, :call) ? :(f(a, b, c)) : x, "f(a, b)") == "f(a, b, c)"
@test textwalk(x -> isexpr(x, :call) ? :(f(a, c, b)) : x, "f(a, b)") == "f(a, c, b)"
@test textwalk(x -> isexpr(x, :call) ? :(f(c, a, b)) : x, "f(a, b)") == "f(c, a, b)"
@test textwalk(x -> isexpr(x, :call) ? :(c(f, a, b)) : x, "f(a, b)") == "c(f, a, b)"
