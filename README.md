# MacroTools.jl

This library provides helpful tools for writing macros, notably a very simple
but templating system and some functions that have proven useful to me (see
`utils.jl`.)

Template matching enables macro writers to deconstruct Julia
expressions in a more declarative way, and without having to know in
great detail how syntax is represented internally. For example, say you
have a type definition:

```julia
ex = quote
  type Foo
    x::Int
    y
  end
end
```

If you know what you're doing, you can pull out the name and fields via:

```julia
julia> if isexpr(ex.args[2], :type)
         (ex.args[2].args[2], ex.args[2].args[3].args)
       end
(:Foo,{:( # line 3:),:(x::Int),:( # line 4:),:y})
```

But this is hard to write – since you have to deconstruct the `type`
expression by hand – and hard to read, since you can't tell at a glance
what's being acheived. On top of that, there's a bunch of messy stuff to
deal with like besky `begin` blocks which wrap a single expression, line
numbers, etc. etc.

Enter ExpressionMatch:

```julia
julia> @match ex begin
         type T_
           fields__
         end => (T, fields)
       end
(:Foo,{:(x::Int),:y})
```

Which is a bit nicer, IMHO. `@match` can take multiple clauses to act as
a kind of `if` statement, too, and returns `nothing` if no match is
found.

Symbols like `T_` underscore are treated as catchalls which match any
expression, and the expression they match is bound to the
(underscore-less) variable, as above.

Symbols like `f__` (double underscored) are similar, but slurp a
sequence of arguments into an array. For example:

```julia
julia> @match :[1, 2, 3, 4, 5, 6, 7] begin
         [1, a_, 3, b__, c_] -> (a, b, c)
         [a__] -> a
       end
(2,{4,5,6},7)
```

Slurps don't have to be at the end of an expression, but like the
Highlander there can only be one (per expression).
