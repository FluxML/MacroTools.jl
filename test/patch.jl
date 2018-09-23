using MacroTools: textwalk
using Test

@test textwalk(x -> x==:a ? :b : x, "a*2") == "b*2"
@test textwalk(x -> x==:a ? :b : x, "a * 2") == "b * 2"
@test textwalk(x -> x == :a ? 2 : x, "a * b * c") == "2 * b * c"
@test textwalk(x -> x == :* ? :f : x, "a * b") == "f(a, b)"

@test textwalk(x -> x isa String ? :(uppercase($x)) : x, """
  bar("baz")
  """) == """
  bar(uppercase("baz"))
  """
