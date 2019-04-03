# Utilities

## Function definitions

Function definitions pose a problem to pattern matching, since there are a lot
of different ways to define a function. For example, a pattern that captures
`f(x) = 2x` will not match

```julia
function f(x)
  return 2x
end
```

There are a couple of ways to handle this. One way is to use `longdef` or `shortdef`
to normalise function definitions to short form, before matching it.

```julia
julia> ex = :(function f(x) 2x end)
:(function f(x)
      #= none:1 =#
      2x
  end)

julia> MacroTools.shortdef(ex)
:(f(x) = begin
          #= none:1 =#
          2x
      end)
```

More generally it's also possible to use `splitdef` and `combinedef` to handle
the full range of function syntax.

`splitdef(def)` matches a function definition of the form

```julia
function name{params}(args; kwargs)::rtype where {whereparams}
   body
end
```

and returns `Dict(:name=>..., :args=>..., etc.)`. The definition can be rebuilt by
calling `MacroTools.combinedef(dict)`, or explicitly with

```julia
rtype = get(dict, :rtype, :Any)
all_params = [get(dict, :params, [])..., get(dict, :whereparams, [])...]
:(function $(dict[:name]){$(all_params...)}($(dict[:args]...);
                                            $(dict[:kwargs]...))::$rtype
      $(dict[:body])
  end)
```

`splitarg(arg)` matches function arguments (whether from a definition or a function call)
such as `x::Int=2` and returns `(arg_name, arg_type, slurp, default)`. `default` is
`nothing` when there is none. For example:

```julia
> map(splitarg, (:(f(y, a=2, x::Int=nothing, args...))).args[2:end])
4-element Array{Tuple{Symbol,Symbol,Bool,Any},1}:
 (:y, :Any, false, nothing)  
 (:a, :Any, false, 2)        
 (:x, :Int, false, :nothing)
 (:args, :Any, true, nothing)
```

## Other Utilities

```@docs
MacroTools.isexpr
MacroTools.rmlines
MacroTools.unblock
MacroTools.namify
MacroTools.inexpr
MacroTools.gensym_ids
MacroTools.alias_gensyms
MacroTools.@expand
MacroTools.isdef
MacroTools.flatten
MacroTools.prettify
```
