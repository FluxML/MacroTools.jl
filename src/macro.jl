allbindings(pat, bs) =
  isbinding(pat) || isslurp(pat) ? push!(bs, bname(pat)) :
  isexpr(pat, :$) ? bs :
  isa(pat, Expr) ? map(pat -> allbindings(pat, bs), [pat.head, pat.args...]) :
  bs

allbindings(pat) = (bs = Any[]; allbindings(pat, bs); bs)

function bindinglet(bs, body)
  ex = :(let $(esc(:env)) = env
           $body
         end)
  for b in bs
    push!(ex.args, :($(esc(b)) = env[$(Expr(:quote, b))]))
  end
  return ex
end

function makeclause(line)
  env = trymatch(:(pat_ -> yes_), line)
  env == nothing && error("Invalid match clause $line")
  pat, yes = env[:pat], env[:yes]
  quote
    env = trymatch($(Expr(:quote, pat)), ex)
    if env != nothing
      result = $(bindinglet(allbindings(pat), esc(yes)))
      @goto done
    end
  end
end

macro match (ex, lines)
  @assert isexpr(lines, :block)
  result = quote
    ex = $(esc(ex))
    result = nothing
  end
  for line in rmlines(lines).args
    isline(result) && push!(result, line)
    push!(result.args, makeclause(line))
  end
  push!(result.args, (quote
                        @label done
                        result
                      end).args...)
  return result
end
