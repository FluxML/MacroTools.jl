export isexpr, isline, rmlines, unblock, @expand

assoc!(d, k, v) = (d[k] = v; d)

isexpr(x::Expr) = true
isexpr(x) = false
isexpr(x::Expr, ts...) = x.head in ts
isexpr(x, ts...) = any(T->isa(T, Type) && isa(x, T), ts)

isline(ex) = isexpr(ex, :line) || isa(ex, LineNumberNode)

rmlines(xs) = filter(x->!isline(x), xs)
rmlines(x::Expr) = Expr(x.head, rmlines(x.args)...)

function unblock(ex)
  isexpr(ex, :block) || return ex
  exs = rmlines(ex).args
  length(exs) == 1 || return ex
  return unblock(exs[1])
end

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
macro expand (ex)
  :(macroexpand($(Expr(:quote, ex))))
end
