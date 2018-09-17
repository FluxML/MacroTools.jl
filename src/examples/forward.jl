"""
    @forward Foo.bar f, g, h

`@forward` simply forwards method definition to a given field of a struct.
For example, the above is  equivalent to

```julia
f(x::Foo, args...) = f(x.bar, args...)
g(x::Foo, args...) = g(x.bar, args...)
h(x::Foo, args...) = h(x.bar, args...)
```
"""
macro forward(ex, fs)
  @capture(ex, T_.field_) || error("Syntax: @forward T.x f, g, h")
  T = esc(T)
  fs = isexpr(fs, :tuple) ? map(esc, fs.args) : [esc(fs)]
  :($([:($f(x::$T, args...; kwargs...) =
         (Base.@_inline_meta; $f(x.$field, args...; kwargs...)))
       for f in fs]...);
    nothing)
end
