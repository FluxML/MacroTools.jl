# MacroTools.jl

This library provides helpful tools for writing macros, notably a very simple
but powerful templating system and some functions that have proven useful to me (see
[utils.jl](src/utils.jl).)

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
what's being achieved. On top of that, there's a bunch of messy stuff to
deal with like pesky `begin` blocks which wrap a single expression, line
numbers, etc. etc.

Enter MacroTools:

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
         [1, a_, 3, b__, c_] => (a, b, c)
         [a__] => a
       end
(2,{4,5,6},7)
```

Slurps don't have to be at the end of an expression, but like the
Highlander there can only be one (per expression).

## Matching on expression type

`@match` can match expressions by their type, which is either the `head` of `Expr`
objects or the `typeof` atomic stuff like `Symbol`s and `Int`s. For example:

```julia
@match ex begin
  foo(x_String_string) => x
end
```

This will match a call to the `foo` function which has a single argument, which
may either be a `String` object or a `Expr(:string, ...)`. Julia string literals
may be parsed into either type of object, so this is a handy way to catch both.

Another common use case is to catch symbol literals, e.g.

```julia
@match ex begin
  type T_Symbol
    fields__
  end => T
end
```

which will match e.g. `type Foo ...` but not `type Foo{V} ...`

## Unions

`@match` can also try to match the expression against one pattern or another,
for example:

```julia
@match ex begin
  (f_(args__) = body_ |
   function f_(args__) body_ end) => (f, args, body)
end
```

will match both kinds of function syntax. You can also do this within expressions,
e.g.

```julia
@match ex begin
  ((f_{T_}|f_)(args__) = body_) => (f, T, args, body)
end
```

matches a function definition, with a single type parameter bound to `T` if possible.
If not, `T = nothing`.

## Captures

`@capture` is an alternative to `@match` which, instead of binding variables
within a clause, makes those matches available in the local scope. For example,

```julia
let ex = :(foo(x, y) = x*y)
  @capture(ex, f_(args__) = body_)
  f, args, body
end
```

The `@capture` expression itself returns `true` or `false` to indicate whether
the match was successful, which enables convenient patterns such as:

```julia
let ex = :(foo(x, y) = x*y)
  @capture(ex, f_(args__) = body_) ||
    error("We need a function definition.")
  f, args, body
end
```
