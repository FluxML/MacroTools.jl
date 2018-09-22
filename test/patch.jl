using MacroTools: textwalk
using Test

@test textwalk(x -> x isa String ? :(uppercase($x)) : x, """
  bar("baz")
  """) == """
  bar(uppercase("baz"))
  """
