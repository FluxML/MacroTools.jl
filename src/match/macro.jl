function allbindings(pat, bs)
  if isa(pat, QuoteNode)
    return allbindings(pat.value, bs)
  end
  return isbinding(pat) || (isslurp(pat) && pat !== :__) ? push!(bs, bname(pat)) :
  isa(pat, TypeBind) ? push!(bs, pat.name) :
  isa(pat, OrBind) ? (allbindings(pat.pat1, bs); allbindings(pat.pat2, bs)) :
  istb(pat) ? push!(bs, tbname(pat)) :
  isexpr(pat, :$) ? bs :
  isa(pat, Expr) ? map(pat -> allbindings(pat, bs), [pat.head, pat.args...]) :
  bs
end

allbindings(pat) = (bs = Any[]; allbindings(pat, bs); bs)

function bindinglet(bs, body)
  ex = :(let $(esc(:env)) = env, $((:($(esc(b)) = get(env, $(Expr(:quote, b)), nothing)) for b in bs)...)
           $body
         end)
  return ex
end

function makeclause(pat, yes, els = nothing)
  bs = allbindings(pat)
  pat = subtb(subor(pat))
  quote
    env = trymatch($(Expr(:quote, pat)), ex)
    if env !== nothing
      $(bindinglet(bs, esc(yes)))
    else
      $els
    end
  end
end

function clauses(ex)
  line = nothing
  clauses = []
  for l in ex.args
    isline(l) && (line = l; continue)
    env = trymatch(:(pat_ => yes_), l)
    env === nothing && error("Invalid match clause $l")
    pat, yes = env[:pat], env[:yes]
    push!(clauses, (pat, :($line;$yes)))
  end
  return clauses
end

macro match(ex, lines)
  @assert isexpr(lines, :block)
  result = quote
    ex = $(esc(ex))
  end

  body = foldr((clause, body) -> makeclause(clause..., body),
               clauses(lines); init=nothing)

  push!(result.args, body)
  return result
end

macro capture(ex, pat)
  bs = allbindings(pat)
  pat = subtb(subor(pat))
  quote
    $([:($(esc(b)) = nothing) for b in bs]...)
    env = trymatch($(esc(Expr(:quote, pat))), $(esc(ex)))
    if env === nothing
      false
    else
      $([:($(esc(b)) = get(env, $(esc(Expr(:quote, b))), nothing)) for b in bs]...)
      true
    end
  end
end
