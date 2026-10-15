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
  pat = subor(subtb(pat))
  quote
    env = trymatch($(esc(Expr(:quote, pat))), ex)
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

"""
    @match ex begin
      pattern1 => result1
      pattern2 => result2
      ...
    end

Match the expression `ex` against each pattern in turn, using the same syntax as
[`@capture`](@ref), and evaluate the `result` of the first one that matches.
A pattern's bindings are only visible within its own `result`. If no pattern
matches, `@match` returns `nothing`; use `_ => default` as the last clause to
provide a fallback.

```julia
julia> @match :(f(x, y)) begin
         f_(a_) => (f, a)
         f_(a_, b_) => (f, a, b)
         _ => :other
       end
(:f, :x, :y)
```

Since `=>` is right-associative, a pattern that is itself a pair needs
parentheses: `(a_ => b_) => result`, not `a_ => b_ => result`.
"""
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

"""
    @capture(ex, pattern)

Match the expression `ex` against `pattern`, returning `true` if it matches and
`false` otherwise. Each binding in the pattern is assigned to a variable of the
same name (without underscores) in the enclosing scope. In the pattern:

- `x_` matches any single expression;
- `xs__` matches (slurps) a sequence of expressions into a vector;
- `x_T` only matches an expression of type `T`, or an `Expr` with head `:T`
  (e.g. `x_Symbol`, `x_call`);
- `\$y` matches the value of `y`;
- `p1 | p2` matches either `p1` or `p2`, trying `p1` first.

Bindings that are not part of the match (because it failed, or because they are
in a branch of `|` that wasn't taken) are set to `nothing`.

```julia
julia> @capture(:(f(a, b)), f_(xs__))
true

julia> f, xs
(:f, Any[:a, :b])
```

See also: [`@match`](@ref)
"""
macro capture(ex, pat)
  bs = allbindings(pat)
  pat = subor(subtb(pat))
  quote
    env = trymatch($(esc(Expr(:quote, pat))), $(esc(ex)))
    if env === nothing
      $([:($(esc(b)) = nothing) for b in bs]...)
      false
    else
      $([:($(esc(b)) = get(env, $(esc(Expr(:quote, b))), nothing)) for b in bs]...)
      true
    end
  end
end
