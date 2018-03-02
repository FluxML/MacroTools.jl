export @destruct

symbolliteral(x) = @capture(x, :(f_)) && isa(f, Symbol)

isatom(x) = symbolliteral(x) || typeof(x) ∉ (Symbol, Expr)

atoms(f, ex) = MacroTools.postwalk(x -> isatom(x) ? f(x) : x, ex)

get′(d::AbstractDict, k::Symbol) =
  haskey(d, k) ? d[k] :
  haskey(d, string(k)) ? d[string(k)] :
  error("Couldn't destruct key `$k` from collection $d")

get′(d::AbstractDict, k::Symbol, default) =
  haskey(d, k) ? d[k] :
  haskey(d, string(k)) ? d[string(k)] :
  default

get′(xs, k, v) = get(xs, k, v)
get′(xs, k) = getindex(xs, k)

getkeym(args...) = :(MacroTools.get′($(args...)))
getfieldm(val, i) = :(getfield($val,$i))
getfieldm(val, i, default) = error("Can't destructure fields with default values")

function destruct_key(pat, val, getm)
  @match pat begin
    _Symbol        => destruct_key(:($pat = $(Expr(:quote, pat))), val, getm)
    x_Symbol || y_ => destruct_key(:($x = $(Expr(:quote, x)) || $y), val, getm)
    (x_ = y_)      => destructm(x, destruct_key(y, val, getm))
    x_ || y_       => getm(val, x, y)
    _              => atoms(i -> getm(val, i), pat)
  end
end

destruct_keys(pats, val, getm, name = gensym()) =
  :($name = $val; $(map(pat->destruct_key(pat, name, getm), pats)...); $name)

function destructm(pat, val)
  @match pat begin
    x_Symbol     => :($pat = $val)
    (x_ = y_)    => destructm(x, destructm(y, val))
    [pats__]     => destruct_keys(pats, val, getkeym)
    x_[pats__]   => destructm(x, destructm(:([$(pats...)]), val))
    x_.(pats__,) => destructm(x, destruct_keys(pats, val, getfieldm))
    x_.pat_ | x_.(pat_) => destructm(:($x.($pat,)), val)
    _ => error("Unrecognised destructuring syntax $pat")
  end
end

macro destruct(ex)
  @capture(ex, pat_ = val_) || error("@destruct pat = val")
  esc(destructm(pat, val))
end
