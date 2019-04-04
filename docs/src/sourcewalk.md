# SourceWalk

Pattern matching is really useful if you're writing macros, but it also works
on Julia source code files. You can try this with the `sourcewalk` function,
which behaves like `postwalk` but with a source file as input.

!!! note

    To use this functionality you currently need to a fork of CSTParser.
    ```julia
    ] add https://github.com/MikeInnes/CSTParser.jl#location
    ```

For example, if we have a file like

```julia
# test.jl
foo(a, b)
```

And run

```julia
sourcewalk("test.jl") do x
  x == :foo ? :bar : x
end
```

then our file will have changed to

```julia
# test.jl
bar(a, b)
```

You can also pass `sourcewalk` a directory, and it will work on all `.jl` files
in that directory. You can use `sourcewalk` anywhere you'd normally use a
Regex-based find and replace, but it'll take care of subtle issues like matching
brackets, operator precedence and code formatting.

We can use this to do some very powerful code transformations with minimal
effort. For example, [this whole
patch](https://github.com/MikeInnes/julia/commit/45ccbc6a3c003accb0eedca889835071c371ae86)
was generated simply with `sourcewalk(longdef, "base")`. Let's look at some
examples.

!!! warning

    We recommend running SourceWalk on files that are checked into Git. This way
    you can easily look through every change and check it's sensible. Being
    careless with `sourcewalk` can delete all your code!

## Find and Replace

Here's a more realistic example. When working with strings, we use `nextind(s, i)`
to get the next index after `i` – which will often just be `i+1`, but may
be something else if we're working with unicode.

How do you know your code handles unicode correctly? One way to check is to
actually replace `nextind(s, i)` with `i + 1` and _make sure that the tests
fail_ – if they don't, we're not testing with unicode input properly. This is a
form of [mutation testing](https://en.wikipedia.org/wiki/Mutation_testing).

Of course, the transformation is very simple with MacroTools:

```julia
julia> function nextinds(x)
         @capture(x, nextind(str_, i_)) && return :($i + 1)
         @capture(x, prevind(str_, i_)) && return :($i - 1)
         return x
       end
nextinds (generic function with 1 method)

julia> nextinds(:(nextind(a, b)))
:(b + 1)
```

We can check this works on text, before running it on our file, using `textwalk`.

```julia
julia> using MacroTools: textwalk

julia> textwalk(nextinds, "nextind(s, i)")
"i + 1"
```

And verify that it correctly handles operator precedence – so we won't get invalid
syntax or unexpected changes to the meaning of our code.

```julia
julia> textwalk(nextinds, "1:nextind(s, i)")
"1:i + 1"

julia> textwalk(nextinds, "1*nextind(s, i)")
"1*(i + 1)"
```

Running this on Julia's base code yields [the following patch](https://github.com/MikeInnes/julia/commit/b3964317321150c4b9ae8d629f613ee1143b3629).
