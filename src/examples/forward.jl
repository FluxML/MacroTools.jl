macro forward(ex, fs)
  @capture(ex, T_.field_) || error("Syntax: @forward T.x f, g, h")
  T = esc(T)
  fs = isexpr(fs, :tuple) ? map(esc, fs.args) : [esc(fs)]
  :($([:($f(x::$T, args...) = (Base.@_inline_meta; $f(x.$field, args...)))
       for f in fs]...);
    nothing)
end
