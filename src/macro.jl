allbindings(pat, bs) =
  isbinding(pat) || (isslurp(pat) && pat ≠ :__) ? push!(bs, bname(pat)) :
  isa(pat, TypeBind) ? push!(bs, pat.name) :
  isa(pat, OrBind) ? (allbindings(pat.pat1, bs); allbindings(pat.pat2, bs)) :
  istb(pat) ? push!(bs, tbname(pat)) :
  isexpr(pat, :$) ? bs :
  isa(pat, Expr) ? map(pat -> allbindings(pat, bs), [pat.head, pat.args...]) :
  bs

allbindings(pat) = (bs = Any[]; allbindings(pat, bs); bs)

function bindinglet(bs, body)
  ex = :(let $(esc(:env)) = env
           $body
         end)
  for b in bs
    push!(ex.args, :($(esc(b)) = get(env, $(Expr(:quote, b)), nothing)))
  end
  return ex
end

function makeclause(pat, yes, els = nothing; bind_types = true)
  bs = allbindings(pat)
  pat = subor(pat)
  if bind_types
    pat = subtb(pat)
  end
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

function make_match(ex, lines; bind_types = true)
  @assert isexpr(lines, :block)
  result = quote
    ex = $(esc(ex))
  end
  body = foldr((clause, body) -> makeclause(clause..., body; bind_types = bind_types),
               nothing, clauses(lines))
  push!(result.args, body)
  return result
end

macro match(ex, lines)
  make_match(ex, lines)
end

macro simplematch(ex, lines)
  make_match(ex, lines; bind_types = false)
end

function make_capture(ex, pat; bind_types = true)
  bs = allbindings(pat)
  pat = subor(pat)
  if bind_types
    pat = subtb(pat)
  end
  quote
    $([:($(esc(b)) = nothing) for b in bs]...)
    env = trymatch($(Expr(:quote, pat)), $(esc(ex)))
    if env == nothing
      false
    else
      $([:($(esc(b)) = get(env, $(Expr(:quote, b)), nothing)) for b in bs]...)
      true
    end
  end
end

macro capture(ex, pat)
  make_capture(ex, pat)
end

macro simplecapture(ex, pat)
  make_capture(ex, pat; bind_types = false)
end
