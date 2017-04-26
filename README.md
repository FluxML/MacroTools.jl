# MacroTools.jl

This library provides helpful tools for writing macros, notably a very simple
but powerful templating system and some functions that have proven useful to me (see
[utils.jl](src/utils.jl).)

## Template Matching

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
julia> @capture(ex, type T_ fields__ end)
true

julia> T, fields
(:Foo, [:(x::Int), :y])
```

Symbols like `T_` underscore are treated as catchalls which match any
expression, and the expression they match is bound to the
(underscore-less) variable, as above.

Because `@capture` doubles as a test as well as extracting values, you can
easily handle unexpected input (which would be a lot harder otherwise):

```julia
@capture(ex, f_{T_}(xs__) = body_) ||
  error("expected a function with a single type parameter")
```

Symbols like `f__` (double underscored) are similar, but slurp a sequence of
arguments into an array. For example:

```julia
julia> @capture(:[1, 2, 3, 4, 5, 6, 7], [1, a_, 3, b__, c_])
true

julia> a, b, c
(2,[4,5,6],7)
```

Slurps don't have to be at the end of an expression, but like the
Highlander there can only be one (per expression).

### Matching on expression type

`@capture` can match expressions by their type, which is either the `head` of `Expr`
objects or the `typeof` atomic stuff like `Symbol`s and `Int`s. For example:

```julia
@capture(ex, foo(x_String_string))
```

This will match a call to the `foo` function which has a single argument, which
may either be a `String` object or a `Expr(:string, ...)`. Julia string literals
may be parsed into either type of object, so this is a handy way to catch both.

Another common use case is to catch symbol literals, e.g.

```julia
@capture(ex,
  type T_Symbol
    fields__
  end)
```

which will match e.g. `type Foo ...` but not `type Foo{V} ...`

### Unions

`@capture` can also try to match the expression against one pattern or another,
for example:

```julia
@capture(ex, f_(args__) = body_ | function f_(args__) body_ end)
```

will match both kinds of function syntax (though it's easier to use
`shortdef` to normalise definitions). You can also do this within
expressions, e.g.

```julia
@capture(ex, (f_{T_}|f_)(args__) = body_)
```

matches a function definition, with a single type parameter bound to `T` if possible.
If not, `T = nothing`.
