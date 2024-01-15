export @esc, isexpr, isline, iscall, rmlines, unblock, block, inexpr, namify, isdef,
  longdef, shortdef, @expand, makeif, prettify, combinedef, splitdef, splitarg, combinearg

"""
    assoc!(d, k, v)

is the same as `d[k] = v` but returns `d` rather than `v`.
"""
assoc!(d, k, v) = (d[k] = v; d)

"""
    @esc x y

is the same as:
```julia
x = esc(x)
y = esc(y)
```
"""
macro esc(xs...)
  :($([:($x = esc($x)) for x in map(esc, xs)]...);)
end

"""
    @q [expression]

Like the `quote` keyword but doesn't insert line numbers from the construction
site. e.g. compare `@q begin end` with `quote end`. Line numbers of interpolated
expressions are preserverd.

See also: [`rmlines`](@ref)
"""
macro q(ex)
  # use esc here, so we don't rely on https://github.com/JuliaLang/julia/issues/37540 for
  # interpolation to work
  esc(Expr(:quote, striplines(ex)))
end

struct Flag end

to_flag(ex) = MacroTools.prewalk(x->x isa LineNumberNode ? Flag() : x, ex)
to_line(l::LineNumberNode, ex) = MacroTools.prewalk(x->x isa Flag ? l : x, ex)

"""
    @qq [expression]

Like the `quote` keyword but replace construction site line numbers with __source__.
Line numbers of interpolated expressions are preserved. The result is that line numbers will be
attributed to the macro usage site, instead of the macro source code.

Only works inside of a macro definition.

See also: [`@q`](@ref)
"""
macro qq(ex)
    # This was a difficult macro to write; the round-trip to Flag appears to be necessary.
    # Crucially, we want interpolated expressions to preserve their line numbers.
    esc(:($MacroTools.to_line(__source__, $(Expr(:quote, to_flag(ex))))))
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

iscall(ex, f) = isexpr(ex, :call) && ex.args[1] == f

"""
    rmlines(x)

Remove the line nodes from a block or array of expressions.

Compare `quote end` vs `rmlines(quote end)`

### Examples

To work with nested blocks:

```julia
prewalk(rmlines, ex)
```

See also: [`@q`](@ref)
"""
rmlines(x) = x
function rmlines(x::Expr)
  # Do not strip the first argument to a macrocall, which is
  # required.
  if x.head === :macrocall && length(x.args) >= 2
    Expr(x.head, x.args[1], nothing, filter(x->!isline(x), x.args[3:end])...)
  else
    Expr(x.head, filter(x->!isline(x), x.args)...)
  end
end

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
An easy way to get the (function/type) name out of
expressions like `foo{T}` or `Bar{T} <: Vector{T}`.
"""
namify(s::Symbol) = s
namify(ex::Expr) = namify(ex.args[1])

walk(x, inner, outer) = outer(x)
walk(x::Expr, inner, outer) = outer(Expr(x.head, map(inner, x.args)...))

"""
    postwalk(f, expr)

Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *after* they have been transformed by the walk.

See also: [`prewalk`](@ref).
"""
postwalk(f, x) = walk(x, x -> postwalk(f, x), f)

"""
    prewalk(f, expr)

Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *before* they have been transformed by the walk, and the
walk will be applied to whatever `f` returns.

This makes `prewalk` somewhat prone to infinite loops; you probably want to try
[`postwalk`](@ref) first.
"""
prewalk(f, x)  = walk(f(x), x -> prewalk(f, x), identity)

replace(ex, s, s′) = prewalk(x -> x == s ? s′ : x, ex)

"""
    inexpr(expr, x)

Simple expression match; will return `true` if the expression `x` can be found
inside `expr`.

```julia
inexpr(:(2+2), 2) == true
```
"""
function inexpr(ex, x)
  result = false
  MacroTools.postwalk(ex) do y
    if y == x
      result = true
    end
    return y
  end
  return result
end

isgensym(s::Symbol) = occursin("#", string(s))
isgensym(s) = false

function gensymname(x::Symbol)
  m = Base.match(r"##(.+)#\d+", String(x))
  m === nothing || return m.captures[1]
  m = Base.match(r"#\d+#(.+)", String(x))
  m === nothing || return m.captures[1]
  return "x"
end

"""
    gensym_ids(expr)

Replaces gensyms with unique ids (deterministically).

```julia
julia> x, y = gensym("x"), gensym("y")
(Symbol("##x#363"), Symbol("##y#364"))

julia> MacroTools.gensym_ids(:(\$x+\$y))
:(x_1 + y_2)
```
"""
function gensym_ids(ex)
  counter = 0
  syms = Dict{Symbol, Symbol}()
  prewalk(ex) do x
    isgensym(x) ?
      get!(()->Symbol(gensymname(x), "_", counter+=1), syms, x) :
      x
  end
end

"""
    alias_gensyms(expr)

Replaces gensyms with animal names.
This makes gensym'd code far easier to follow.

```julia
julia> x, y = gensym("x"), gensym("y")
(Symbol("##x#363"), Symbol("##y#364"))

julia> MacroTools.alias_gensyms(:(\$x+\$y))
:(porcupine + gull)
```
"""
function alias_gensyms(ex)
  left = copy(animals)
  syms = Dict{Symbol, Symbol}()
  prewalk(ex) do x
    isgensym(x) ? get!(()->pop!(left), syms, x) : x
  end
end

"""
More convenient macro expansion, e.g.

```julia
@expand @time foo()
```
"""
macro expand(ex)
  :(alias_gensyms(macroexpand($(__module__), $(ex,)[1])))
end


"Test for function definition expressions. `function f end` and anonymous functions are considered
as function definitions and return true."
isdef(ex::Expr) = isshortdef(ex) || ex.head == :function || ex.head == :->
isdef(ex) = false

isshortdef(ex) = (@capture(ex, (fcall_ = body_)) &&
                  (@capture(gatherwheres(fcall)[1],
                            (f_(args__) |
                             f_(args__)::rtype_))))

function longdef1(ex)
  if @capture(ex, (arg_ -> body_))
    Expr(:function, arg isa Symbol ? :($arg,) : arg, body)
  elseif isshortdef(ex)
    @assert @capture(ex, (fcall_ = body_))
    Expr(:function, fcall, body)
  else
    ex
  end
end
longdef(ex) = prewalk(longdef1, ex)

function shortdef1(ex)
  @match ex begin
    function f_(args__) body_ end => @q $f($(args...)) = $(body.args...)
    function f_(args__) where T__ body_ end => @q $f($(args...)) where $(T...) = $(body.args...)
    function f_(args__)::rtype_ body_ end => @q $f($(args...))::$rtype = $(body.args...)
    function f_(args__)::rtype_ where T__ body_ end => @q ($f($(args...))::$rtype) where $(T...) = $(body.args...)
    function (args__,) body_ end => @q ($(args...),) -> $(body.args...)
    ((args__,) -> body_) => ex
    (arg_ -> body_) => @q ($arg,) -> $(body.args...)
    _ => ex
  end
end
shortdef(ex) = prewalk(shortdef1, ex)

"""
```julia
gatherwheres(:(f(x::T, y::U) where T where U)) == (:(f(x::T, y::U)), (:U, :T))
```
"""
function gatherwheres(ex)
  if @capture(ex, (f_ where {params1__}))
    f2, params2 = gatherwheres(f)
    (f2, (params1..., params2...))
  else
    (ex, ())
  end
end

"""    splitdef(fdef)

Match any function definition

```julia
function name{params}(args; kwargs)::rtype where {whereparams}
   body
end
```

and return `Dict(:name=>..., :args=>..., etc.)`. The definition can be rebuilt by
calling `MacroTools.combinedef(dict)`.

See also: [`combinedef`](@ref)
"""
function splitdef(fdef)
  error_msg = "Not a function definition: $(repr(fdef))"
  @assert(@capture(longdef1(fdef),
                   function (fcall_ | fcall_) body_ end),
          "Not a function definition: $fdef")
  fcall_nowhere, whereparams = gatherwheres(fcall)
  func = args = kwargs = rtype = nothing
  if @capture(fcall_nowhere, ((func_(args__; kwargs__)) |
                              (func_(args__; kwargs__)::rtype_) |
                              (func_(args__)) |
                              (func_(args__)::rtype_)))
  elseif isexpr(fcall_nowhere, :tuple)
    if length(fcall_nowhere.args) > 1 && isexpr(fcall_nowhere.args[1], :parameters)
      args = fcall_nowhere.args[2:end]
      kwargs = fcall_nowhere.args[1].args
    else
      args = fcall_nowhere.args
    end
  elseif isexpr(fcall_nowhere, :(::))
    args = Any[fcall_nowhere]
  else
    throw(ArgumentError(error_msg))
  end
  if func !== nothing
    @assert(@capture(func, (fname_{params__} | fname_)), error_msg)
    di = Dict(:name=>fname, :args=>args,
              :kwargs=>(kwargs===nothing ? [] : kwargs), :body=>body)
  else
    params = nothing
    di = Dict(:args=>args, :kwargs=>(kwargs===nothing ? [] : kwargs), :body=>body)
  end
  if rtype !== nothing; di[:rtype] = rtype end
  if whereparams !== nothing; di[:whereparams] = whereparams end
  if params !== nothing; di[:params] = params end
  di
end

"""
    combinedef(dict::Dict)

`combinedef` is the inverse of [`splitdef`](@ref). It takes a `splitdef`-like Dict
and returns a function definition.

This function approximately does the following (but more sophisticated to avoid
emitting parts that did not actually appear in the original function definition.)

```julia
rtype = get(dict, :rtype, :Any)
all_params = [get(dict, :params, [])..., get(dict, :whereparams, [])...]
:(function \$(dict[:name]){\$(all_params...)}(\$(dict[:args]...);
                                            \$(dict[:kwargs]...))::\$rtype
      \$(dict[:body])
  end)
```

"""
function combinedef(dict::Dict)
  rtype = get(dict, :rtype, nothing)
  params = get(dict, :params, [])
  wparams = get(dict, :whereparams, [])
  body = block(dict[:body])
  if haskey(dict, :name)
    name = dict[:name]
    name_param = isempty(params) ? name : :($name{$(params...)})
    # We need the `if` to handle parametric inner/outer constructors like
    # SomeType{X}(x::X) where X = SomeType{X}(x, x+2)
    if isempty(wparams)
      if rtype==nothing
        @q(function $name_param($(dict[:args]...);
                                $(dict[:kwargs]...))
          $(body.args...)
          end)
      else
        @q(function $name_param($(dict[:args]...);
                                $(dict[:kwargs]...))::$rtype
          $(body.args...)
          end)
      end
    else
      if rtype==nothing
        @q(function $name_param($(dict[:args]...);
                                $(dict[:kwargs]...)) where {$(wparams...)}
          $(body.args...)
          end)
      else
        @q(function $name_param($(dict[:args]...);
                                $(dict[:kwargs]...))::$rtype where {$(wparams...)}
          $(body.args...)
          end)
      end
    end
  else
    if isempty(dict[:kwargs])
      arg = :($(dict[:args]...),)
    else
      arg = Expr(:tuple, Expr(:parameters, dict[:kwargs]...), dict[:args]...)
    end
    if isempty(wparams)
      if rtype==nothing
        @q($arg -> $body)
      else
        @q(($arg::$rtype) -> $body)
      end
    else
      if rtype==nothing
        @q(($arg where {$(wparams...)}) -> $body)
      else
        @q(($arg::$rtype where {$(wparams...)}) -> $body)
      end
    end
  end
end

"""
    combinearg(arg_name, arg_type, is_splat, default)

`combinearg` is the inverse of [`splitarg`](@ref).
"""
function combinearg(arg_name, arg_type, is_splat, default)
    @assert arg_name !== nothing || arg_type !== nothing
    a = arg_name===nothing ? :(::$arg_type) :
        arg_type==:Any && is_splat ? arg_name :   # see #177 and julia#43625
            :($arg_name::$arg_type)
    a2 = is_splat ? Expr(:..., a) : a
    return default === nothing ? a2 : Expr(:kw, a2, default)
end

"""
    splitarg(arg)

Match function arguments (whether from a definition or a function call) such as
`x::Int=2` and return `(arg_name, arg_type, is_splat, default)`. `arg_name` and
`default` are `nothing` when they are absent. For example:

```julia
julia> map(splitarg, (:(f(a=2, x::Int=nothing, y, args...))).args[2:end])
4-element Array{Tuple{Symbol,Symbol,Bool,Any},1}:
 (:a, :Any, false, 2)
 (:x, :Int, false, :nothing)
 (:y, :Any, false, nothing)
 (:args, :Any, true, nothing)
```

See also: [`combinearg`](@ref)
"""
function splitarg(arg_expr)
    if @capture(arg_expr, arg_expr2_ = default_)
      # This assert will only be triggered if a `nothing` literal was somehow spliced into the Expr.
      # A regular `nothing` default value is a `Symbol` when it gets here. See #178
      @assert default !== nothing "splitarg cannot handle `nothing` as a default. Use a quoted `nothing` if possible. (MacroTools#35)"
    else
       arg_expr2 = arg_expr
    end
    is_splat = @capture(arg_expr2, arg_expr3_...)
    is_splat || (arg_expr3 = arg_expr2)
    (arg_name, arg_type) = (@match arg_expr3 begin
        ::T_ => (nothing, T)
        name_::T_ => (name, T)
        x_ => (x, :Any)
    end)::NTuple{2,Any} # the pattern `x_` matches any expression
    return (arg_name, arg_type, is_splat, default)
end


function flatten1(ex)
  isexpr(ex, :block) || return ex
  #ex′ = :(;)
  ex′ = Expr(:block)
  for x in ex.args
    isexpr(x, :block) ? append!(ex′.args, x.args) : push!(ex′.args, x)
  end
  # Don't use `unblock` to preserve line nos.
  return length(ex′.args) == 1 ? ex′.args[1] : ex′
end

# Helpers for flattening try blocks
bflatten(x) = x
function bflatten(x::Expr) # flatten down to a block (i.e. a `begin symbol end` is turned into `begin symbol end`, unlike `flatten` which would just return the symbol)
    fx = flatten(x)
    return isexpr(fx, :block) || !isexpr(x, :block) ? fx : Expr(:block,fx)
end

"""
    flatten(ex)

Flatten any redundant blocks into a single block, over the whole expression.
"""
function flatten end

flatten(x) = x
function flatten(x::Expr)
  if isexpr(x, :try) # begin _ end can be turned to _ everywhere in julia _except_ in try blocks. See #196 for details
    3 <= length(x.args) <= 5 || error("Misformed `try` block.")
    isa(x.args[2], Symbol) || x.args[2] == false || error("Misformed `try` block.")
    return Expr(x.head, map(bflatten, x.args)...)
    # args[2] can be a symbol or false
    # args[3] can be a block (or false if there is no catch, which requires an else or finally)
    # args[4] can be a block (or false if there is no finally but there is an else) if it exists
    # args[5] can only be a block if it exists
  else
    return flatten1(Expr(x.head, map(flatten, x.args)...))
  end
end

function makeif(clauses, els = nothing)
  foldr((c, ex)->:($(c[1]) ? $(c[2]) : $ex), clauses; init=els)
end

unresolve1(x) = x
unresolve1(f::Function) = methods(f).mt.name

unresolve(ex) = prewalk(unresolve1, ex)

function resyntax(ex)
  prewalk(ex) do x
    @match x begin
      setfield!(x_, :f_, x_.f_ + v_) => :($x.$f += $v)
      setfield!(x_, :f_, v_) => :($x.$f = $v)
      getindex(x_, i__) => :($x[$(i...)])
      tuple(xs__) => :($(xs...),)
      adjoint(x_) => :($x')
      _ => x
    end
  end
end

"""
    prettify(ex)

Makes generated code generaly nicer to look at.
"""
prettify(ex; lines = false, alias = true) =
  ex |> (lines ? identity : striplines) |> flatten |> unresolve |> resyntax |> (alias ? alias_gensyms : identity)
