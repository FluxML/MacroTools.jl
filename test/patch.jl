using MacroTools: textmap, textwalk, @capture, isexpr
using Test

testrep(ex, text) = textmap(_ -> Expr(:file, ex), text)

# Replacement

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

# Insertion

@test testrep(:(f(a,b)), "f(a)") == "f(a, b)"
@test testrep(:(f(a)), "f()") == "f(a)"

@test testrep(:(f(a, b, c)), "f(a, b)") == "f(a, b, c)"
@test testrep(:(f(a, c, b)), "f(a, b)") == "f(a, c, b)"
@test testrep(:(f(c, a, b)), "f(a, b)") == "f(c, a, b)"
@test testrep(:(c(f, a, b)), "f(a, b)") == "c(f, a, b)"

# Deletion

@test testrep(:(f()), "f(a)") == "f()"
@test testrep(:(f()), "f(a,)") == "f()"

@test testrep(:(f(a, b)), "f(a, b, c)") == "f(a, b)"
@test testrep(:(f(a, c)), "f(a, b, c)") == "f(a, c)"
@test testrep(:(f(b, c)), "f(a, b, c)") == "f(b, c)"
@test testrep(:(a(b, c)), "f(a, b, c)") == "a(b, c)"
