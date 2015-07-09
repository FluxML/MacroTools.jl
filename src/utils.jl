using Base.Meta

assoc!(d, k, v) = (d[k] = v; d)

isline(ex) = isexpr(ex, :line) || isa(ex, LineNumberNode)

rmlines(xs) = filter(x->!isline(x), xs)
rmlines(x::Expr) = Expr(x.head, rmlines(x.args)...)

function unblock(ex)
  isexpr(ex, :block) || return ex
  exs = filter(ex->!isline(ex), ex.args)
  length(exs) == 1 || return ex
  return unblock(exs[1])
end
