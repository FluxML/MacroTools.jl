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

# Like type binds, unions are spliced into the pattern as `$(OrBind(...))`, with
# each branch quoted, so that interpolations and type binds inside the branches
# get evaluated along with the rest of the pattern (#36).
ornew(a, b) = Expr(:$, :($OrBind($(Expr(:quote, a)), $(Expr(:quote, b)))))

subor(s) = s
function subor(s::Expr)
  isexpr(s, :$) && return s
  isor(s) || return Expr(s.head, map(subor, s.args)...)
  foldl(ornew, map(subor, s.args[2:end]))
end
