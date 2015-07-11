type MatchError
  pat
  ex
end

nomatch(pat, ex) = throw(MatchError(pat, ex))

isbinding(s) = false
isbinding(s::Symbol) = Base.ismatch(r"[^_]_(_str)?$", string(s))

function bname(s::Symbol)
  symbol(Base.match(r"^@?(.*?)_+(_str)?$", string(s)).captures[1])
end

function match_inner(pat, ex, env)
  pat == ex || nomatch(pat, ex)
  return env
end

match_inner(pat::QuoteNode, ex::QuoteNode, env) =
  match(pat.value, ex.value, env)

isslurp(s) = false
isslurp(s::Symbol) = s == :__ || Base.ismatch(r"[^_]__$", string(s))

function slurprange(pat)
  slurps = length(filter(isslurp, pat))
  slurps == 0 && return 0,0
  slurps > 1 && error("Pattern may only contain one slurp.")

  left, right = 1, 1
  while !isslurp(pat[left]) left += 1 end
  while !isslurp(pat[end+1-right]) right += 1 end
  return left, right
end

inrange(i, range, len) =
  range ≠ (0,0) && i ≥ range[1] && i ≤ len+1-range[2]

function match_inner(pat::Expr, ex::Expr, env)
  match(pat.head, ex.head, env)
  pat, ex = rmlines(pat), rmlines(ex)
  sr = slurprange(pat.args)
  slurp = Any[]
  i = 1
  for p in pat.args
    i > length(ex.args) &&
      (isslurp(p) ? (env[bname(p)] = slurp) : nomatch(pat, ex))

    while inrange(i, sr, length(ex.args))
      push!(slurp, ex.args[i])
      i += 1
    end

    if isslurp(p)
      p ≠ :__ && (env[bname(p)] = slurp)
    else
      match(p, ex.args[i], env)
      i += 1
    end
  end
  i == length(ex.args)+1 || nomatch(pat, ex)
  return env
end

blockunify(a, b) =
  isexpr(a, :block) && !isexpr(b, :block) ? (a, Expr(:block, b)) :
  !isexpr(a, :block) && isexpr(b, :block) ? (Expr(:block, a), b) :
  (a, b)

function normalise(ex)
  ex = unblock(ex)
  isa(ex, QuoteNode) && (ex = Expr(:quote, ex.value))
  return ex
end

function match(pat, ex, env)
  pat, ex = normalise(pat), normalise(ex)
  pat == :_ && return env
  isbinding(pat) && return assoc!(env, bname(pat), ex)
  pat, ex = blockunify(pat, ex)
  return match_inner(pat, ex, env)
end

match(pat, ex) = match(pat, ex, Dict())

function ismatch(pat, ex)
  try
    match(pat, ex)
    return true
  catch e
    isa(e, MatchError) ? (return false) : rethrow()
  end
end

function trymatch(pat, ex)
  try
    match(pat, ex)
  catch e
    isa(e, MatchError) ? (return) : rethrow()
  end
end
