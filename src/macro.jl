allbindings(pat, bs) =
  isbinding(pat) || (isslurp(pat) && pat ≠ :__) ? push!(bs, bname(pat)) :
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

function makeclause(line, els = nothing)
  env = trymatch(:(pat_ -> yes_), line)
  env == nothing && error("Invalid match clause $line")
  pat, yes = env[:pat], env[:yes]
  pat = subor(pat)
  bs = allbindings(pat)
  pat = subtb(pat)
  quote
    env = trymatch($(Expr(:quote, pat)), ex)
    if env != nothing
      $(bindinglet(bs, esc(yes)))
    else
      $els
    end
  end
end

macro match(ex, lines)
  @assert isexpr(lines, :block)
  result = quote
    ex = $(esc(ex))
  end
  body = nothing
  for line in reverse(rmlines(lines).args)
    isline(result) && push!(result, line)
    body = makeclause(line, body)
  end
  push!(result.args, body)
  return result
end
