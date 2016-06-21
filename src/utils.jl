export @esc, isexpr, isline, rmlines, unblock, block, inexpr, namify, isdef,
  longdef, shortdef, @expand, makeif, prettify

assoc!(d, k, v) = (d[k] = v; d)

macro esc(xs...)
  :($([:($x = esc($x)) for x in map(esc, xs)]...);)
end

"""
    isexpr(x, ts...)

Convenient way to test the type of a Julia expression.
Expression heads and types are supported, so for example
you can call

    isexpr(expr, String, :string)

to pick up on all string-like expressions.
"""
isexpr(x::Expr) = true
isexpr(x) = false
isexpr(x::Expr, ts...) = x.head in ts
isexpr(x, ts...) = any(T->isa(T, Type) && isa(x, T), ts)

isline(ex) = isexpr(ex, :line) || isa(ex, LineNumberNode)

"""
    rmlines(x)

Remove the line nodes from a block or array of expressions.
"""
rmlines(x) = x
rmlines(x::Expr) = Expr(x.head, filter(x->!isline(x), x.args)...)

striplines(ex) = prewalk(rmlines, ex)

"""
    unblock(expr)

Remove outer `begin` blocks from an expression, if the block is
redundant (i.e. contains only a single expression).
"""
function unblock(ex)
  isexpr(ex, :block) || return ex
  exs = rmlines(ex).args
  length(exs) == 1 || return ex
  return unblock(exs[1])
end

block(ex) = isexpr(ex, :block) ? ex : :($ex;)

"""
An easy way to get pull the (function/type) name out of
expressions like `foo{T}` or `Bar{T} <: Vector{T}`.
"""
namify(s::Symbol) = s
namify(ex::Expr) = namify(ex.args[1])

Base.macroexpand(m::Module, ex) =
  eval(m, :(macroexpand($(Expr(:quote, ex)))))

walk(x, inner, outer) = outer(x)
walk(x::Expr, inner, outer) = outer(Expr(x.head, map(inner, x.args)...))

postwalk(f, x) = walk(x, x -> postwalk(f, x), f)
prewalk(f, x)  = walk(f(x), x -> prewalk(f, x), identity)

replace(ex, s, s′) = prewalk(x -> x == s ? s′ : x, ex)

function inexpr(ex, x)
  result = false
  MacroTools.postwalk(ex) do y
    y == x && (result = true)
  end
  return result
end

global const animals = split(readstring(joinpath(dirname(@__FILE__), "..", "animals.txt")))

isgensym(s::Symbol) = contains(string(s), "#")
isgensym(s) = false

function alias_gensyms(ex)
  syms = Dict{Symbol, Symbol}()
  s(x) = get!(syms, x, lowercase(rand(filter(s->!(s in values(syms)), animals))))
  prewalk(ex) do x
    isgensym(x) ? s(x) : x
  end
end

"""
More convenient macro expansion, e.g.

    @expand @time foo()
"""
macro expand(ex)
  ex = postwalk(ex) do ex
    isexpr(ex, :$) ? Expr(:quote, ex) : ex
  end
  :(alias_gensyms(macroexpand($(Expr(:quote, ex)))))
end

"Test for function definition expressions."
isdef(ex) = ismatch(or_(:(function _(__) _ end),
                        :(f_(__) = _)),
                    ex)

function longdef(ex)
  prewalk(ex) do ex
    @match ex begin
      (f_(args__) = body_) => :(function $f($(args...)) $body end)
      ((args__,) -> body_) => :(function ($(args...),) $body end)
      (arg_ -> body_) => :(function ($arg,) $body end)
      _ => ex
    end
  end
end

function shortdef(ex)
  prewalk(ex) do ex
    @match ex begin
      function f_(args__) body_ end => :($f($(args...)) = $body)
      function (args__,) body_ end => :(($(args...),) -> $body)
      (arg_ -> body_) => :(($arg,) -> $body)
      _ => ex
    end
  end
end

function flatten1(ex)
  isexpr(ex, :block) || return ex
  ex′ = quote end
  for x in ex.args
    isexpr(x, :block) ? append!(ex′.args, x.args) : push!(ex′.args, x)
  end
  return ex′
end

flatten(ex) = postwalk(flatten1, ex)

function makeif(clauses, els = nothing)
  foldr((c, ex)->:($(c[1]) ? $(c[2]) : $ex), els, clauses)
end

unresolve1(x) = x
unresolve1(f::Function) = methods(f).mt.name

unresolve(ex::Expr) = prewalk(unresolve1, ex)

function resyntax(ex)
  prewalk(ex) do x
    @match x begin
      setfield!(x_, :f_, x_.f_ + v_) => :($x.$f += $v)
      setfield!(x_, :f_, v_) => :($x.$f = $v)
      getindex(x_, i__) => :($x[$(i...)])
      tuple(xs__) => :($(xs...),)
      ctranspose(x_) => :($x')
      transpose(x_) => :($x.')
      _ => x
    end
  end
end

prettify(ex) = ex |> flatten |> unresolve |> resyntax |> alias_gensyms |> striplines
