struct OrBind
  pat1
  pat2
end

or_(a, b) = OrBind(a, b)
or_(p...) = foldl(or_, p)

function match_inner(pat::OrBind, ex, env)
  env′ = trymatch(pat.pat1, ex)
  env′ == nothing ? match(pat.pat2, ex, env) : merge!(env, env′)
end

isor(ex) = isexpr(ex, :call) && ex.args[1] in (:or_, :|)

function ornew(ex)
  isor(ex) || return ex
  or_(ex.args[2:end]...)
end

subor(s) = s
subor(s::Symbol) = s
subor(s::Expr) = isor(s) ? subor(ornew(s)) : Expr(s.head, map(subor, s.args)...)
subor(s::OrBind) = OrBind(subor(s.pat1), subor(s.pat2))
