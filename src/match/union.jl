struct OrBind
  pat1
  pat2
end

or_(a, b) = OrBind(a, b)
or_(p...) = foldl(or_, p)

function match_inner(pat::OrBind, ex, env)
  env′ = trymatch(pat.pat1, ex)
  env′ === nothing ? match(pat.pat2, ex, env) : merge!(env, env′)
end

function isor(ex)
  if isexpr(ex, :call)
    arg1 = ex.args[1]
    return arg1 isa Symbol && arg1 in (:or_, :|)  # "isa Symbol" check improves inferrability (#166)
  end
  return false
end

function ornew(ex)
  isor(ex) || return ex
  or_(ex.args[2:end]...)
end

subor(s) = s
subor(s::Symbol) = s
subor(s::Expr) = isor(s) ? subor(ornew(s)) : Expr(s.head, map(subor, s.args)...)
subor(s::OrBind) = OrBind(subor(s.pat1), subor(s.pat2))
