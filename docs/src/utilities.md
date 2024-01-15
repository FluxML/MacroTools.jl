# Utilities

## Function definitions

Function definitions pose a problem to pattern matching, since there are a lot
of different ways to define a function. For example, a pattern that captures
`f(x) = 2x` will not match the following syntax:

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

```@docs
MacroTools.splitdef
MacroTools.combinedef
MacroTools.splitarg
MacroTools.combinearg
```

## Other Utilities

```@docs
MacroTools.@q
MacroTools.@qq
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
