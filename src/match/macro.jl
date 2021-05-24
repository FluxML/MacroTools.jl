function allbindings(context, pat, bs)
  if isa(pat, QuoteNode)
    return allbindings(context, pat.value, bs)
  end
  return isbinding(pat) || (isslurp(pat) && pat ≠ :__) ? push!(bs, bname(pat)) :
  isa(pat, TypeBind) ? push!(bs, pat.name) :
  isa(pat, OrBind) ? (allbindings(context, pat.pat1, bs); allbindings(context, pat.pat2, bs)) :
  istb(context, pat) ? push!(bs, tbname(pat)) :
  isexpr(pat, :$) ? bs :
  isa(pat, Expr) ? map(pat -> allbindings(context, pat, bs), [pat.head, pat.args...]) :
  bs
end

allbindings(context, pat) = (bs = Any[]; allbindings(context, pat, bs); bs)

function bindinglet(bs, body)
  ex = :(let $(esc(:env)) = env, $((:($(esc(b)) = get(env, $(Expr(:quote, b)), nothing)) for b in bs)...)
           $body
         end)
  return ex
end

function makeclause(context, pat, yes, els = nothing)
  bs = allbindings(context, pat)
  pat = subtb(context, subor(pat))
  quote
    env = trymatch($(Expr(:quote, pat)), ex)
    if env != nothing
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
    env == nothing && error("Invalid match clause $l")
    pat, yes = env[:pat], env[:yes]
    push!(clauses, (pat, :($line;$yes)))
  end
  return clauses
end

macro match(ex, lines) _match(__module__, ex, lines) end
macro match_notb(ex, lines) _match(nothing, ex, lines) end
function _match(context, ex, lines)
  @assert isexpr(lines, :block)
  result = quote
    ex = $(esc(ex))
  end

  body = @static VERSION < v"0.7.0-" ?
         foldr((clause, body) -> makeclause(context, clause..., body),
                 nothing, clauses(lines)) :
         foldr((clause, body) -> makeclause(context, clause..., body),
                 clauses(lines); init=nothing)

  push!(result.args, body)
  return result
end

macro capture(ex, pat) _capture(__module__, ex, pat) end
macro capture_notb(ex, pat) _capture(nothing, ex, pat) end
function _capture(context, ex, pat)
  bs = allbindings(context, pat)
  pat = subtb(context, subor(pat))
  return quote
    $([:($(esc(b)) = nothing) for b in bs]...)
    env = trymatch($(esc(Expr(:quote, pat))), $(esc(ex)))
    if env == nothing
      false
    else
      $([:($(esc(b)) = get(env, $(esc(Expr(:quote, b))), nothing)) for b in bs]...)
      true
    end
  end
end
