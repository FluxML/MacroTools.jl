export @esc, isexpr, isline, rmlines, unblock, block, inexpr, namify, isdef,
  longdef, shortdef, @expand, makeif, prettify

assoc!(d, k, v) = (d[k] = v; d)

"""
    @esc x y

is the same as

    x = esc(x)
    y = esc(y)
"""
macro esc(xs...)
  :($([:($x = esc($x)) for x in map(esc, xs)]...);)
end

"""
    @q [expression]

Like the `quote` keyword but doesn't insert line numbers from the construction
site. e.g. compare `@q begin end` with `quote end`. Line numbers of interpolated
expressions are preserverd.
"""
macro q(ex)
  Expr(:quote, striplines(ex))
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

Compare `quote end` vs `rmlines(quote end)`
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

"""
    macroexpand(::Module, expr)

In its uniquely cheeky and loveable fashion, MacroTools extends this function
to work in any module. May be useful for checking that `esc`s are done
correctly.
"""
Base.macroexpand(m::Module, ex) =
  eval(m, :(macroexpand($(Expr(:quote, ex)))))

walk(x, inner, outer) = outer(x)
walk(x::Expr, inner, outer) = outer(Expr(x.head, map(inner, x.args)...))

"""
    postwalk(f, expr)

Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *after* they have been transformed by the walk. See also
`prewalk`.
"""
postwalk(f, x) = walk(x, x -> postwalk(f, x), f)

"""
    prewalk(f, expr)

Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *before* they have been transformed by the walk, and the
walk will be applied to whatever `f` returns.

This makes `prewalk` somewhat prone to infinite loops; you probably want to try
`postwalk` first.
"""
prewalk(f, x)  = walk(f(x), x -> prewalk(f, x), identity)

replace(ex, s, s′) = prewalk(x -> x == s ? s′ : x, ex)

"""
    inexpr(expr, x)

Simple expression match; will return `true` if the expression `x` can be found
inside `expr`.

    inexpr(:(2+2), 2) == true
"""
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

"""
    alias_gensyms(expr)

Replaces gensyms with animal names. This makes gensym'd code far easier to
follow.
"""
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
  :(alias_gensyms(macroexpand($(ex,)[1])))
end

"Test for function definition expressions."
isdef(ex) = ismatch(or_(:(function _(__) _ end),
                        :(f_(__) = _)),
                    ex)

function longdef(ex)
  prewalk(ex) do ex
    @match ex begin
      (f_(args__) = body_) => @q function $f($(args...)) $body end
      ((args__,) -> body_) => @q function ($(args...),) $body end
      (arg_ -> body_) => @q function ($arg,) $body end
      _ => ex
    end
  end
end

function shortdef(ex)
  prewalk(ex) do ex
    @match ex begin
      function f_(args__) body_ end => @q $f($(args...)) = $body
      function (args__,) body_ end => @q ($(args...),) -> $body
      ((args__,) -> body_) => ex
      (arg_ -> body_) => @q ($arg,) -> $body
      _ => ex
    end
  end
end

function flatten1(ex)
  isexpr(ex, :block) || return ex
  #ex′ = :(;)
  ex′ = Expr(:block)
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

"""
    prettify(ex)

Makes generated code generaly nicer to look at.
"""
prettify(ex; lines = false) =
  ex |> flatten |> unresolve |> resyntax |> alias_gensyms |> (lines ? identity : striplines)
