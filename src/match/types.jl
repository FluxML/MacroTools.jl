struct TypeBind
  name::Symbol
  ts::Set{Any}
end

istb(::Nothing, _) = false
istb(::Module, _) = false
function istb(context::Module, s::Symbol)
  (endswith(string(s), "_") || endswith(string(s), "_str")) && return false
  occursin("_", string(s)) || return false
  ts = map(Symbol, split(string(s), "_"))
  popfirst!(ts)
  return all(s->istype(context, s), ts)
end

function istype(context::Module, s::Symbol)
  if string(s)[1] in 'A':'Z'
    if isdefined(context, s) && isa(getfield(context, s), Type)
      return true
    else
      throw(ArgumentError("""
      the syntax to specify expression type syntax is used, but the given type isn't defined:
      if you want to ignore the syntaxes to specify expression type, use `@capture_notb` or `@match_notb` instead
      """))
    end
  end
  return true
end

tbname(s::Symbol) = Symbol(split(string(s), "_")[1])
tbname(s::TypeBind) = s.name

totype(s::Symbol) = string(s)[1] in 'A':'Z' ? s : Expr(:quote, s)

function tbnew(context::Module, s::Symbol)
  istb(context, s) || return s
  ts = map(Symbol, split(string(s), "_"))
  name = popfirst!(ts)
  ts = map(totype, ts)
  Expr(:$, :(MacroTools.TypeBind($(Expr(:quote, name)), Set{Any}([$(ts...)]))))
end

match_inner(b::TypeBind, ex, env) =
  isexpr(ex, b.ts...) ? (env[tbname(b)] = ex; env) : @nomatch(b, ex)

subtb(::Nothing, s) = s
subtb(context::Module, s) = s
subtb(context::Module, s::Symbol) = tbnew(context, s)
subtb(context::Module, s::Expr) = isexpr(s, :line) ? s : Expr(subtb(context, s.head), map(s->subtb(context, s), s.args)...)
