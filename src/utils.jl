export isexpr, isline, rmlines, unblock, namify, isdef, @expand

assoc!(d, k, v) = (d[k] = v; d)

"""
    isexpr(x, ts...)

Convenient way to test the type of a Julia expression.
Expression heads and types are supported, so for example
you can call

    isexpr(expr, String, :string)

to pick up on all string-like expressions.
"""
isexpr(x::Expr) = true
isexpr(x) = false
isexpr(x::Expr, ts...) = x.head in ts
isexpr(x, ts...) = any(T->isa(T, Type) && isa(x, T), ts)

isline(ex) = isexpr(ex, :line) || isa(ex, LineNumberNode)

"""
    rmlines(x)

Remove the line nodes from a block or array of expressions.
"""
rmlines(xs) = filter(x->!isline(x), xs)
rmlines(x::Expr) = Expr(x.head, rmlines(x.args)...)

"""
    unblock(expr)

Remove outer `begin` blocks from an expression, if the block is
redundant (i.e. contains only a single expression).
"""
function unblock(ex)
  isexpr(ex, :block) || return ex
  exs = rmlines(ex).args
  length(exs) == 1 || return ex
  return unblock(exs[1])
end

"""
An easy way to get pull the (function/type) name out of
expressions like `foo{T}` or `Bar{T} <: Vector{T}`.
"""
namify(s::Symbol) = s
namify(ex::Expr) = namify(ex.args[1])

Base.macroexpand(m::Module, ex) =
  eval(m, :(macroexpand($(Expr(:quote, ex)))))

subs(ex::Expr, s, s′) =
  ex == s ? s′ :
    Expr(ex.head, map(ex -> subs(ex, s, s′), ex.args)...)

subs(ex, s, s′) = ex == s ? s′ : ex

"""
More convenient macro expansion, e.g.

    @expand @time foo()
"""
macro expand(ex)
  :(macroexpand($(Expr(:quote, ex))))
end

"Test for function definition expressions."
isdef(ex) = ismatch(or_(:(function _(__) _ end),
                        :(f_(__) = _)),
                    ex)
