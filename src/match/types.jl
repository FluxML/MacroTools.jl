struct TypeBind
  name::Symbol
  ts::Set{Any}
end

istb(s) = false
istb(s::Symbol) = !(endswith(string(s), "_") ||
                    endswith(string(s), "_str")) &&
                    occursin("_", string(s))

tbname(s::Symbol) = Symbol(split(string(s), "_")[1])
tbname(s::TypeBind) = s.name

totype(s::Symbol) = string(s)[1] in 'A':'Z' ? s : Expr(:quote, s)

function tbnew(s::Symbol)
  istb(s) || return s
  ts = map(Symbol, split(string(s), "_"))
  name = popfirst!(ts)
  ts = (totype(t) for t in ts)
  Expr(:$, :(MacroTools.TypeBind($(Expr(:quote, name)), Set{Any}([$(ts...)]))))
end

match_inner(b::TypeBind, ex, env) =
  isexpr(ex, b.ts...) ? (env[tbname(b)] = ex; env) : @nomatch(b, ex)

subtb(s) = s
subtb(s::Symbol) = tbnew(s)
subtb(s::Expr) = isexpr(s, :line) ? s : Expr(subtb(s.head), map(subtb, s.args)...)
