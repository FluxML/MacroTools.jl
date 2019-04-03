using MacroTools: textmap, textwalk, @capture, isexpr
using Test

testrep(ex, text) = textmap(_ -> Expr(:file, ex), text)

# Replacement

@test testrep(:(b*2), "a*2") == "b*2"
@test testrep(:(b*2), "a * 2") == "b * 2"
@test testrep(:(2*b*c), "a * b * c") == "2 * b * c"
@test testrep(:(f(a, b)), "a * b") == "f(a, b)"

@test testrep(:((a+1)*2), "a * 2") == "(a + 1) * 2"
@test testrep(:((a+1)*2), "*(a, 2)") == "*(a + 1, 2)"

@test testrep(:(bar(uppercase("baz"))), """
  bar("baz")
  """) == """
  bar(uppercase("baz"))
  """

@test testrep(:(using Bar), "using Foo") == "using Bar"

# Insertion

@test testrep(:(f(a,b)), "f(a)") == "f(a, b)"
@test testrep(:(f(a)), "f()") == "f(a)"

@test testrep(:(f(a, b, c)), "f(a, b)") == "f(a, b, c)"
@test testrep(:(f(a, c, b)), "f(a, b)") == "f(a, c, b)"
@test testrep(:(f(c, a, b)), "f(a, b)") == "f(c, a, b)"
@test testrep(:(c(f, a, b)), "f(a, b)") == "c(f, a, b)"

@test testrep(:(f(a, b, c)), "f(a , b)") == "f(a , b , c)"
@test testrep(:(a+b+c), "a + b") == "a + b + c"
@test testrep(:(a+b+c), "a+b") == "a+b+c"

testrep(:(1; 2; 3), """
  begin
    1
    2
  end
  """) == """
  begin
    1
    2
    3
  end
  """

testrep(:(1; 2; 3), """
  begin
    1; 2
  end
  """) == """
  begin
    1; 2; 3
  end
  """

testrep(:(1; 2; 3), """
  begin
    1; 2;
  end
  """) == """
  begin
    1; 2; 3;
  end
  """

testrep(:(1; 2; 3), "(1; 2)") == "(1; 2; 3)"

# Deletion

@test testrep(:(f()), "f(a)") == "f()"
@test testrep(:(f()), "f(a,)") == "f()"

@test testrep(:(f(a, b)), "f(a, b, c)") == "f(a, b)"
@test testrep(:(f(a, c)), "f(a, b, c)") == "f(a, c)"
@test testrep(:(f(b, c)), "f(a, b, c)") == "f(b, c)"
@test testrep(:(a(b, c)), "f(a, b, c)") == "a(b, c)"

# Others

@test testrep(:(@foo a), "@foo a b") == "@foo a"
@test testrep(:(@foo a b c), "@foo a b") == "@foo a b c"
@test testrep(:(@foo a b c), "@foo(a, b)") == "@foo(a, b, c)"

@test testrep(:(a,), "(a, b)") == "(a)"
@test testrep(:(a,b,c), "a, b") == "a, b, c"
