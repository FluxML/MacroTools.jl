import Base: Expr

# Terminals
convert_expr(loc::Location, x::IDENTIFIER) = Symbol(normalize_julia_identifier(x.val))
function convert_expr(loc::Location, x::KEYWORD)
    if x.kind == Tokens.BREAK
        return Expr(:break)
    elseif x.kind == Tokens.CONTINUE
        return Expr(:continue)
    else
        return Symbol(lowercase(string(x.kind)))
    end
end
convert_expr(loc::Location, x::OPERATOR) = x.dot ? Symbol(:., UNICODE_OPS_REVERSE[x.kind]) : UNICODE_OPS_REVERSE[x.kind]
convert_expr(loc::Location, x::PUNCTUATION) = string(x.kind)

function julia_normalization_map(c::Int32, x::Ptr{Nothing})::Int32
    return c == 0x00B5 ? 0x03BC : # micro sign -> greek small letter mu
           c == 0x025B ? 0x03B5 : # latin small letter open e -> greek small letter
           c
end

# Note: This code should be in julia base
function utf8proc_map_custom(str::String, options, func)
    norm_func = @cfunction $func Int32 (Int32, Ptr{Nothing})
    nwords = ccall(:utf8proc_decompose_custom, Int, (Ptr{UInt8}, Int, Ptr{UInt8}, Int, Cint, Ptr{Nothing}, Ptr{Nothing}),
                   str, sizeof(str), C_NULL, 0, options, norm_func, C_NULL)
    nwords < 0 && Base.Unicode.utf8proc_error(nwords)
    buffer = Base.StringVector(nwords * 4)
    nwords = ccall(:utf8proc_decompose_custom, Int, (Ptr{UInt8}, Int, Ptr{UInt8}, Int, Cint, Ptr{Nothing}, Ptr{Nothing}),
                   str, sizeof(str), buffer, nwords, options, norm_func, C_NULL)
    nwords < 0 && Base.Unicode.utf8proc_error(nwords)
    nbytes = ccall(:utf8proc_reencode, Int, (Ptr{UInt8}, Int, Cint), buffer, nwords, options)
    nbytes < 0 && Base.Unicode.utf8proc_error(nbytes)
    return String(resize!(buffer, nbytes))
end

function normalize_julia_identifier(str::AbstractString)
    options = Base.Unicode.UTF8PROC_STABLE | Base.Unicode.UTF8PROC_COMPOSE
    utf8proc_map_custom(String(str), options, julia_normalization_map)
end


function sized_uint_literal(s::AbstractString, b::Integer)
    # We know integers are all ASCII, so we can use sizeof to compute
    # the length of ths string more quickly
    l = (sizeof(s) - 2) * b
    l <= 8   && return Base.parse(UInt8,   s)
    l <= 16  && return Base.parse(UInt16,  s)
    l <= 32  && return Base.parse(UInt32,  s)
    l <= 64  && return Base.parse(UInt64,  s)
    # l <= 128 && return Base.parse(UInt128, s)
    l <= 128 && return Expr(:macrocall, Symbol("@uint128_str"), nothing, s)
    return Base.parse(BigInt, s)
end

function sized_uint_oct_literal(s::AbstractString)
    s[3] == 0 && return sized_uint_literal(s, 3)
    len = sizeof(s)
    (len < 5  || (len == 5  && s <= "0o377")) && return Base.parse(UInt8, s)
    (len < 8  || (len == 8  && s <= "0o177777")) && return Base.parse(UInt16, s)
    (len < 13 || (len == 13 && s <= "0o37777777777")) && return Base.parse(UInt32, s)
    (len < 24 || (len == 24 && s <= "0o1777777777777777777777")) && return Base.parse(UInt64, s)
    (len < 45 || (len == 45 && s <= "0o3777777777777777777777777777777777777777777")) && return Base.parse(UInt128, s)
    return Base.parse(BigInt, s)
end

function convert_expr(loc::Location, x::LITERAL)
    if x.kind == Tokens.TRUE
        return true
    elseif x.kind == Tokens.FALSE
        return false
    elseif is_nothing(x)
        return nothing
    elseif x.kind == Tokens.INTEGER || x.kind == Tokens.BIN_INT || x.kind == Tokens.HEX_INT || x.kind == Tokens.OCT_INT
        return Expr_int(x)
    elseif x.kind == Tokens.FLOAT
        return Expr_float(x)
    elseif x.kind == Tokens.CHAR
        return Expr_char(x)
    elseif x.kind == Tokens.MACRO
        return Symbol(x.val)
    elseif x.kind == Tokens.STRING
        return x.val
    elseif x.kind == Tokens.TRIPLE_STRING
        return x.val
    elseif x.kind == Tokens.CMD
        return Expr_cmd(x)
    elseif x.kind == Tokens.TRIPLE_CMD
        return Expr_tcmd(x)
    end
end

const TYPEMAX_INT64_STR = string(typemax(Int))
const TYPEMAX_INT128_STR = string(typemax(Int128))
function Expr_int(x)
    is_hex = is_oct = is_bin = false
    val = replace(x.val, "_" => "")
    if sizeof(val) > 2 && val[1] == '0'
        c = val[2]
        c == 'x' && (is_hex = true)
        c == 'o' && (is_oct = true)
        c == 'b' && (is_bin = true)
    end
    is_hex && return sized_uint_literal(val, 4)
    is_oct && return sized_uint_oct_literal(val)
    is_bin && return sized_uint_literal(val, 1)
    sizeof(val) <= sizeof(TYPEMAX_INT64_STR) && return Base.parse(Int64, val)
    return Meta.parse(val)
    # # val < TYPEMAX_INT64_STR && return Base.parse(Int64, val)
    # sizeof(val) <= sizeof(TYPEMAX_INTval < TYPEMAX_INT128_STR128_STR) && return Base.parse(Int128, val)
    # # val < TYPEMAX_INT128_STR && return Base.parse(Int128, val)
    # Base.parse(BigInt, val)
end

function Expr_float(x)
    if 'f' in x.val
        return Base.parse(Float32, replace(x.val, 'f' => 'e'))
    end
    Base.parse(Float64, replace(x.val, "_" => ""))
end
function Expr_char(x)
    val = _unescape_string(x.val[2:prevind(x.val, sizeof(x.val))])
    # one byte e.g. '\xff' maybe not valid UTF-8
    # but we want to use the raw value as a codepoint in this case
    sizeof(val) == 1 && return Char(codeunit(val, 1))
    length(val) == 1 || error("Invalid character literal")
    val[1]
end


# Expressions

struct LocExpr
  loc::Location
  expr
end

function convert_child(loc, x, i...)
  loc = loc[i...]
  LocExpr(loc, convert_expr(loc, x[Location([i...])]))
end

LocExpr(x::AbstractEXPR) = convert_child(Location(), x)

striploc(x) = x
striploc(x::Expr) = Expr(x.head, striploc.(x.args)...)
striploc(x::QuoteNode) = QuoteNode(striploc(x.value))
striploc(x::LocExpr) = striploc(x.expr)

Expr(x::AbstractEXPR) = striploc(LocExpr(x))

exprloc(x::LocExpr, i) = isempty(i) ? x.loc : exprloc(x.expr, i)

exprloc(x::Expr, i) = isempty(i) ? nothing :
  exprloc(x.args[i[1]], i[2:end])

exprloc(x, i) = isempty(i) ? nothing :
  error("Can't take index $i of $(repr(x))")

exprloc(x::AbstractEXPR, i) = exprloc(LocExpr(x), i)

# Fallback
function convert_expr(loc::Location, x::EXPR)
    ret = Expr(:call)
    for i in 1:length(x.args)
        if !(x[i] isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{ErrorToken})
    ret = Expr(:error)
    for i in 1:length(x.args)
        if !(x[i] isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

# Op. expressions
convert_expr(loc::Location, x::UnaryOpCall) = Expr(:call, convert_child(loc, x, :op), convert_child(loc, x, :arg))
convert_expr(loc::Location, x::UnarySyntaxOpCall) = x.arg1 isa OPERATOR ? Expr(Expr(x.arg1), convert_child(loc, x, :arg2)) : Expr(Expr(x.arg2), convert_child(loc, x, :arg1))
convert_expr(loc::Location, x::BinaryOpCall) = Expr(:call, convert_child(loc, x, :op), convert_child(loc, x, :arg1), convert_child(loc, x, :arg2))
convert_expr(loc::Location, x::BinarySyntaxOpCall) = Expr(Expr(x.op), convert_child(loc, x, :arg1), convert_child(loc, x, :arg2))
convert_expr(loc::Location, x::ConditionalOpCall) = Expr(:if, convert_child(loc, x, :cond), convert_child(loc, x, :arg1), convert_child(loc, x, :arg2))
function convert_expr(loc::Location, x::EXPR{ChainOpCall})
    ret = Expr(:call, convert_child(loc, x, 2))
    for i = 1:length(x.args)
        if isodd(i)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end
function convert_expr(loc::Location, x::EXPR{Comparison})
    ret = Expr(:comparison)
    for i in 1:length(x.args)
        if !(x[i] isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end
convert_expr(loc::Location, x::EXPR{ColonOpCall}) = Expr(:call, :(:), convert_child(loc, x, 1), convert_child(loc, x, 3), convert_child(loc, x, 5))


function convert_expr(loc::Location, x::WhereOpCall)
    ret = Expr(:where, convert_child(loc, x, :arg1))
    for i = 1:length(x.args)
        a = x.args[i]
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, convert_child(loc[i+2], a))
        elseif !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, convert_child(loc[i+2], a))
        end
    end
    return ret
end

function convert_expr(loc::Location, x::EXPR{TopLevel})
    ret = Expr(:toplevel)
    for i in 1:length(x.args)
        if !(x[i] isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{MacroName})
    if x.args[2] isa IDENTIFIER
        if x.args[2].val == "."
            return Symbol("@", "__dot__")
        else
            return Symbol("@", x.args[2].val)
        end
    else
        return Symbol("@")
    end
end

# cross compatability for line number insertion in macrocalls
if VERSION > v"1.1-"
Expr_cmd(x) = Expr(:macrocall, GlobalRef(Core, Symbol("@cmd")), nothing, x.val)
Expr_tcmd(x) = Expr(:macrocall, GlobalRef(Core, Symbol("@cmd")), nothing, x.val)
else
Expr_cmd(x) = Expr(:macrocall, Symbol("@cmd"), nothing, x.val)
Expr_tcmd(x) = Expr(:macrocall, Symbol("@cmd"), nothing, x.val)
end

function convert_expr(loc::Location, x::EXPR{x_Str})
    if x.args[1] isa BinarySyntaxOpCall
        mname = convert_child(loc, x, 1)
        mname.expr.args[2] = QuoteNode(Symbol("@", striploc(mname).args[2].value, "_str"))
        ret = Expr(:macrocall, mname, nothing)
    else
        name = LocExpr(loc[1], Symbol("@", x.args[1].val, "_str"))
        ret = Expr(:macrocall, name, nothing)
    end
    for i = 2:length(x.args)
        push!(ret.args, LocExpr(loc[i], x.args[i].val))
    end
    return ret
end

function convert_expr(loc::Location, x::EXPR{x_Cmd})
    ret = Expr(:macrocall, Symbol("@", x.args[1].val, "_cmd"), nothing)
    for i = 2:length(x.args)
        push!(ret.args, x.args[i].val)
    end
    return ret
end

function clear_at!(x)
    if x isa Expr && x.head == :.
        if x.args[2] isa QuoteNode && string(x.args[2].value)[1] == '@'
            x.args[2].value = Symbol(string(x.args[2].value)[2:end])
        end
        if x.args[1] isa Symbol && string(x.args[1])[1] == '@'
            x.args[1] = Symbol(string(x.args[1])[2:end])
        else
            clear_at!(x.args[1])
        end
    end
end

function convert_expr(loc::Location, x::EXPR{MacroCall})
    ret = Expr(:macrocall)
    for i in 1:length(x.args)
        if !(x[i] isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    insert!(ret.args, 2, nothing)
    if ret.args[1] isa Expr && ret.args[1].head == :. && string(ret.args[1].args[2].value)[1] != '@'
        clear_at!(ret.args[1])
        ret.args[1].args[2] = QuoteNode(Symbol(string('@', ret.args[1].args[2].value)))
    end
    ret
end
"""
    remlineinfo!(x)
Removes line info expressions. (i.e. Expr(:line, 1))
"""
function remlineinfo!(x)
    if isa(x, Expr)
        if x.head == :macrocall && x.args[2] != nothing
            id = findall(map(x -> (isa(x, Expr) && x.head == :line) || (@isdefined(LineNumberNode) && x isa LineNumberNode), x.args))
            deleteat!(x.args, id)
            for j in x.args
                remlineinfo!(j)
            end
            insert!(x.args, 2, nothing)
        else
            id = findall(map(x -> (isa(x, Expr) && x.head == :line) || (@isdefined(LineNumberNode) && x isa LineNumberNode), x.args))
            deleteat!(x.args, id)
            for j in x.args
                remlineinfo!(j)
            end
        end
        if x.head == :elseif && x.args[1] isa Expr && x.args[1].head == :block && length(x.args[1].args) == 1
            x.args[1] = x.args[1].args[1]
        end
    end
    x
end


convert_expr(loc::Location, x::EXPR{Quotenode}) = QuoteNode(Expr(x.args[end]))

function convert_expr(loc::Location, x::EXPR{Call})
    ret = Expr(:call)
    for i in 1:length(x.args)
        a = x.args[i]
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, convert_child(loc, x, i))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end


function convert_expr(loc::Location, x::EXPR{Braces})
    ret = Expr(:braces)
    for i in 1:length(x.args)
        a = x.args[i]
        if a isa EXPR{Parameters}
            insert!(ret.args, 1, convert_child(loc, x, i))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end


# Definitiions
convert_expr(loc::Location, x::EXPR{Struct}) = Expr(:struct, false, convert_child(loc, x, 2), convert_child(loc, x, 3))
convert_expr(loc::Location, x::EXPR{Mutable}) = length(x.args) == 4 ? Expr(:struct, true, convert_child(loc, x, 2), convert_child(loc, x, 3)) : Expr(:struct, true, convert_child(loc, x, 3), convert_child(loc, x, 4))
convert_expr(loc::Location, x::EXPR{Abstract}) = length(x.args) == 2 ? Expr(:abstract, convert_child(loc, x, 2)) : Expr(:abstract, convert_child(loc, x, 3))
convert_expr(loc::Location, x::EXPR{Primitive}) = Expr(:primitive, convert_child(loc, x, 3), convert_child(loc, x, 4))

function convert_expr(loc::Location, x::EXPR{FunctionDef})
    ret = Expr(:function)
    for i in 1:length(x.args)
        if !(x[i] isa PUNCTUATION || x[i] isa KEYWORD)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end
function convert_expr(loc::Location, x::EXPR{Macro})
    if length(x.args) == 3
        Expr(:macro, convert_child(loc, x, 2))
    else
        Expr(:macro, convert_child(loc, x, 2), convert_child(loc, x, 3))
    end
end
convert_expr(loc::Location, x::EXPR{ModuleH}) = Expr(:module, true, convert_child(loc, x, 2), convert_child(loc, x, 3))
convert_expr(loc::Location, x::EXPR{BareModule}) = Expr(:module, false, convert_child(loc, x, 2), convert_child(loc, x, 3))



# Control Flow

function convert_expr(loc::Location, x::EXPR{If})
    ret = Expr(:if)
    iselseif = false
    n = length(x.args)
    i = 0
    while i < n
        i += 1
        a = x.args[i]
        if a isa KEYWORD && a.kind == Tokens.ELSEIF
            i += 1
            r1 = convert_child(loc, x, i, 1)
            r1.expr.head = :elseif
            push!(ret.args, r1)
        elseif !(a isa PUNCTUATION || a isa KEYWORD)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Try})
    ret = Expr(:try)
    for i in 1:length(x.args)
        if !(x[i] isa PUNCTUATION || x[i] isa KEYWORD)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Let})
    ret = Expr(:let)
    if length(x.args) == 3
        push!(ret.args, Expr(:block))
        push!(ret.args, convert_child(loc, x, 2))
        return ret
    elseif x.args[2] isa EXPR{Block}
        arg = Expr(:block)
        for (i, a) in enumerate(x.args[2].args)
            if !(a isa PUNCTUATION)
                push!(arg.args, fix_range(loc[2, i], a))
            end
        end
        push!(ret.args, arg)
    else
        push!(ret.args, fix_range(loc[2], x.args[2]))
    end
    push!(ret.args, convert_child(loc, x, 3))
    ret
end

function convert_expr(loc::Location, x::EXPR{Do})
    Expr(:do, convert_child(loc, x, 1), Expr(:->, convert_child(loc, x, 3), convert_child(loc, x, 4)))
end


# Loops
convert_expr(loc::Location, x::EXPR{Outer}) = Expr(:outer, convert_child(loc, x, 2))

function convert_expr(loc::Location, x::EXPR{For})
    ret = Expr(:for)
    if x.args[2] isa EXPR{Block}
        arg = Expr(:block)
        for (i, a) in enumerate(x.args[2].args)
            if !(a isa PUNCTUATION)
                push!(arg.args, fix_range(loc[2, i], a))
            end
        end
        push!(ret.args, arg)
    else
        push!(ret.args, fix_range(loc[2], x.args[2]))
    end
    push!(ret.args, convert_child(loc, x, 3))
    ret
end

function convert_expr(loc::Location, x::EXPR{While})
    ret = Expr(:while)
    for i in 1:length(x.args)
        if !(x[i] isa PUNCTUATION || x[i] isa KEYWORD)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end


fix_range(loc, a) = convert_child(loc, a)
function fix_range(loc, a::BinaryOpCall)
    if (is_in(a.op) || is_elof(a.op))
        LocExpr(loc, Expr(:(=), convert_child(loc, a, :arg1), convert_child(loc, a, :arg2)))
    else
        convert_child(loc, a)
    end
end




# Lists

function convert_expr(loc::Location, x::EXPR{TupleH})
    ret = Expr(:tuple)
    for (i, a) in enumerate(x.args)
        if a isa EXPR{Parameters}
            insert!(ret.args, 1, convert_child(loc[i], a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc[i], a))
        end
    end
    return ret
end

function convert_expr(loc::Location, x::EXPR{Curly})
    ret = Expr(:curly)
    for (i, a) in enumerate(x.args)
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, convert_child(loc[i], a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc[i], a))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Vect})
    ret = Expr(:vect)
    for (i, a) in enumerate(x.args)
        if a isa EXPR{Parameters}
            pushfirst!(ret.args, convert_child(loc[i], a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc[i], a))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Row})
    ret = Expr(:row)
    for (i, a) in enumerate(x.args)
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc[i], a))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Hcat})
    ret = Expr(:hcat)
    for (i, a) in enumerate(x.args)
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc[i], a))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Vcat})
    ret = Expr(:vcat)
    for (i, a) in enumerate(x.args)
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc[i], a))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Block})
    ret = Expr(:block)
    for (i, a) in enumerate(x.args)
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc[i], a))
        end
    end
    return ret
end






convert_expr(loc::Location, x::EXPR{Kw}) = Expr(:kw, convert_child(loc, x, 1), convert_child(loc, x, 3))

function convert_expr(loc::Location, x::EXPR{Parameters})
    ret = Expr(:parameters)
    for (i, a) in enumerate(x.args)
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, convert_child(loc[i], a))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc[i], a))
        end
    end
    ret
end


function convert_expr(loc::Location, x::EXPR{Return})
    ret = Expr(:return)
    for i = 2:length(x.args)
        push!(ret.args, convert_child(loc, x, i))
    end
    ret
end

convert_expr(loc::Location, x::EXPR{InvisBrackets}) = convert_child(loc, x, 2)
convert_expr(loc::Location, x::EXPR{Begin}) = convert_child(loc, x, 2)

function convert_expr(loc::Location, x::EXPR{Quote})
    if x.args[2] isa EXPR{InvisBrackets} && (x.args[2].args[2] isa OPERATOR || x.args[2].args[2] isa LITERAL || x.args[2].args[2] isa IDENTIFIER)
        return QuoteNode(convert_child(loc, x, 2))
    else
        return Expr(:quote, convert_child(loc, x, 2))
    end
end

function convert_expr(loc::Location, x::EXPR{Global})
    ret = Expr(:global)
    if x.args[2] isa EXPR{Const}
        ret = Expr(:const, Expr(:global, convert_child(loc, x, 2, 2)))
    elseif length(x.args) == 2 && x.args[2] isa EXPR{TupleH}
        for (i, a) in enumerate(x.args[2].args)
            if !(a isa PUNCTUATION)
                push!(ret.args, convert_child(loc[2, i], a))
            end
        end
    else
        for i = 2:length(x.args)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Local})
    ret = Expr(:local)
    if x.args[2] isa EXPR{Const}
        ret = Expr(:const, Expr(:global, convert_child(loc, x, 2, 2)))
    elseif length(x.args) == 2 && x.args[2] isa EXPR{TupleH}
        for (i, a) in enumerate(x.args[2].args)
            if !(a isa PUNCTUATION)
                push!(ret.args, convert_child(loc[2, i], a))
            end
        end
    else
        for i = 2:length(x.args)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Const})
    ret = Expr(:const)
    for i = 2:length(x.args)
        push!(ret.args, convert_child(loc, x, i))
    end
    ret
end


convert_expr(loc::Location, x::EXPR{GlobalRefDoc}) = GlobalRef(Core, Symbol("@doc"))



function convert_expr(loc::Location, x::EXPR{Ref})
    ret = Expr(:ref)
    for (i, a) in enumerate(x.args)
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, convert_child(loc, x, i))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{TypedHcat})
    ret = Expr(:typed_hcat)
    for (i, a) in enumerate(x.args)
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{TypedVcat})
    ret = Expr(:typed_vcat)

    for (i, a) in enumerate(x.args)
        if a isa EXPR{Parameters}
            insert!(ret.args, 2, convert_child(loc, x, i))
        elseif !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Comprehension})
    ret = Expr(:comprehension)
    for (i, a) in enumerate(x.args)
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Flatten})
    iters, body = get_inner_gen(loc[1], x[1])
    (l, i) = popfirst!(iters)
    ex = Expr(:generator, convert_child(body...), convert_iter_assign(l, i))
    for (l, i) in iters
        ex = Expr(:generator, ex, convert_iter_assign(l, i))
        ex = Expr(:flatten, ex)
    end
    return ex
end

get_inner_gen(loc, x::EXPR{Flatten}, iters = []) = get_inner_gen(loc[1], x[1], iters)
function get_inner_gen(loc, x::EXPR{Generator}, iters = [])
    push!(iters, (loc[3], x.args[3]))
    if x.args[1] isa EXPR{Generator} || x.args[1] isa EXPR{Flatten}
        get_inner_gen(loc[1], x.args[1], iters)
    else
        iters, (loc[1], x.args[1])
    end
end

function convert_expr(loc::Location, x::EXPR{Generator})
    ret = Expr(:generator, convert_child(loc, x, 1))
    for i = 3:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_iter_assign(loc[i], a))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Filter})
    ret = Expr(:filter)
    for (i, a) in enumerate(x.args)
        if !(is_if(a) || a isa PUNCTUATION)
            push!(ret.args, convert_iter_assign(loc[i], a))
        end
    end
    ret
end

function convert_iter_assign(loc, a)
    if a isa BinaryOpCall && (is_in(a.op) || is_elof(a.op))
        return LocExpr(loc, Expr(:(=), convert_child(loc, a, :arg1), convert_child(loc, a, :arg2)))
    else
        return convert_child(loc, a)
    end
end


function convert_expr(loc::Location, x::EXPR{TypedComprehension})
    ret = Expr(:typed_comprehension)
    for (i, a) in enumerate(x.args)
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{Export})
    ret = Expr(:export)
    for i = 2:length(x.args)
        a = x.args[i]
        if !(a isa PUNCTUATION)
            push!(ret.args, convert_child(loc, x, i))
        end
    end
    ret
end






function _get_import_block(loc, x, i, ret)
    while is_dot(x.args[i + 1])
        i += 1
        push!(ret.args, :.)
    end
    while i < length(x.args) && !(is_comma(x.args[i + 1]))
        i += 1
        a = x.args[i]
        if !(a isa PUNCTUATION) && !(is_dot(a) || is_colon(a))
            push!(ret.args, convert_child(loc, x, i))
        end
    end

    return i
end


convert_expr(loc::Location, x::EXPR{Import}) = expr_import(loc, x, :import)
convert_expr(loc::Location, x::EXPR{ImportAll}) = expr_import(loc, x, :importall)
convert_expr(loc::Location, x::EXPR{Using}) = expr_import(loc, x, :using)

function expr_import(loc, x, kw)
    col = findall(a-> a isa OPERATOR && precedence(a) == ColonOp, x.args)
    comma = findall(is_comma, x.args)

    header = []
    args = [Expr(:.)]
    i = 1 #skip keyword
    while i < length(x.args)
        i+=1
        a = x.args[i]
        if is_colon(a)
            push!(header, popfirst!(args))
            push!(args, Expr(:.))
        elseif is_comma(a)
            push!(args, Expr(:.))
        elseif !(a isa PUNCTUATION)
            push!(last(args).args, convert_child(loc, x, i))
        end
    end
    if isempty(header)
        return Expr(kw, args...)
    else
        return Expr(kw, Expr(:(:), header..., args...))
    end
end


function convert_expr(loc::Location, x::EXPR{FileH})
    ret = Expr(:file)
    for (i, a) in enumerate(x.args)
        push!(ret.args, convert_child(loc, x, i))
    end
    ret
end

function convert_expr(loc::Location, x::EXPR{StringH})
    ret = Expr(:string)
    for (i, a) in enumerate(x.args)
        if a isa UnarySyntaxOpCall
            a = a.arg2
            push!(ret.args, convert_child(loc, x, i, :arg2))
            continue
        elseif a isa LITERAL && a.kind == Tokens.STRING
            if span(a) == 0 || ((i == 1 || i == length(x.args)) && span(a) == 1) || isempty(a.val)
                continue
            end
        end
        push!(ret.args, convert_child(loc, x, i))
    end
    ret
end

const UNICODE_OPS_REVERSE = Dict{Tokenize.Tokens.Kind,Symbol}()
for (k, v) in Tokenize.Tokens.UNICODE_OPS
    UNICODE_OPS_REVERSE[v] = Symbol(k)
end

UNICODE_OPS_REVERSE[Tokens.EQ] = :(=)
UNICODE_OPS_REVERSE[Tokens.PLUS_EQ] = :(+=)
UNICODE_OPS_REVERSE[Tokens.MINUS_EQ] = :(-=)
UNICODE_OPS_REVERSE[Tokens.STAR_EQ] = :(*=)
UNICODE_OPS_REVERSE[Tokens.FWD_SLASH_EQ] = :(/=)
UNICODE_OPS_REVERSE[Tokens.FWDFWD_SLASH_EQ] = :(//=)
UNICODE_OPS_REVERSE[Tokens.OR_EQ] = :(|=)
UNICODE_OPS_REVERSE[Tokens.CIRCUMFLEX_EQ] = :(^=)
UNICODE_OPS_REVERSE[Tokens.DIVISION_EQ] = :(÷=)
UNICODE_OPS_REVERSE[Tokens.REM_EQ] = :(%=)
UNICODE_OPS_REVERSE[Tokens.LBITSHIFT_EQ] = :(<<=)
UNICODE_OPS_REVERSE[Tokens.RBITSHIFT_EQ] = :(>>=)
UNICODE_OPS_REVERSE[Tokens.LBITSHIFT] = :(<<)
UNICODE_OPS_REVERSE[Tokens.RBITSHIFT] = :(>>)
UNICODE_OPS_REVERSE[Tokens.UNSIGNED_BITSHIFT] = :(>>>)
UNICODE_OPS_REVERSE[Tokens.UNSIGNED_BITSHIFT_EQ] = :(>>>=)
UNICODE_OPS_REVERSE[Tokens.BACKSLASH_EQ] = :(\=)
UNICODE_OPS_REVERSE[Tokens.AND_EQ] = :(&=)
UNICODE_OPS_REVERSE[Tokens.COLON_EQ] = :(:=)
UNICODE_OPS_REVERSE[Tokens.PAIR_ARROW] = :(=>)
UNICODE_OPS_REVERSE[Tokens.APPROX] = :(~)
UNICODE_OPS_REVERSE[Tokens.EX_OR_EQ] = :($=)
UNICODE_OPS_REVERSE[Tokens.XOR_EQ] = :(⊻=)
UNICODE_OPS_REVERSE[Tokens.RIGHT_ARROW] = :(-->)
UNICODE_OPS_REVERSE[Tokens.LAZY_OR] = :(||)
UNICODE_OPS_REVERSE[Tokens.LAZY_AND] = :(&&)
UNICODE_OPS_REVERSE[Tokens.ISSUBTYPE] = :(<:)
UNICODE_OPS_REVERSE[Tokens.ISSUPERTYPE] = :(>:)
UNICODE_OPS_REVERSE[Tokens.GREATER] = :(>)
UNICODE_OPS_REVERSE[Tokens.LESS] = :(<)
UNICODE_OPS_REVERSE[Tokens.GREATER_EQ] = :(>=)
UNICODE_OPS_REVERSE[Tokens.GREATER_THAN_OR_EQUAL_TO] = :(≥)
UNICODE_OPS_REVERSE[Tokens.LESS_EQ] = :(<=)
UNICODE_OPS_REVERSE[Tokens.LESS_THAN_OR_EQUAL_TO] = :(≤)
UNICODE_OPS_REVERSE[Tokens.EQEQ] = :(==)
UNICODE_OPS_REVERSE[Tokens.EQEQEQ] = :(===)
UNICODE_OPS_REVERSE[Tokens.IDENTICAL_TO] = :(≡)
UNICODE_OPS_REVERSE[Tokens.NOT_EQ] = :(!=)
UNICODE_OPS_REVERSE[Tokens.NOT_EQUAL_TO] = :(≠)
UNICODE_OPS_REVERSE[Tokens.NOT_IS] = :(!==)
UNICODE_OPS_REVERSE[Tokens.NOT_IDENTICAL_TO] = :(≢)
UNICODE_OPS_REVERSE[Tokens.IN] = :(in)
UNICODE_OPS_REVERSE[Tokens.ISA] = :(isa)
UNICODE_OPS_REVERSE[Tokens.LPIPE] = :(<|)
UNICODE_OPS_REVERSE[Tokens.RPIPE] = :(|>)
UNICODE_OPS_REVERSE[Tokens.COLON] = :(:)
UNICODE_OPS_REVERSE[Tokens.DDOT] = :(..)
UNICODE_OPS_REVERSE[Tokens.EX_OR] = :($)
UNICODE_OPS_REVERSE[Tokens.PLUS] = :(+)
UNICODE_OPS_REVERSE[Tokens.MINUS] = :(-)
UNICODE_OPS_REVERSE[Tokens.PLUSPLUS] = :(++)
UNICODE_OPS_REVERSE[Tokens.OR] = :(|)
UNICODE_OPS_REVERSE[Tokens.STAR] = :(*)
UNICODE_OPS_REVERSE[Tokens.FWD_SLASH] = :(/)
UNICODE_OPS_REVERSE[Tokens.REM] = :(%)
UNICODE_OPS_REVERSE[Tokens.BACKSLASH] = :(\)
UNICODE_OPS_REVERSE[Tokens.AND] = :(&)
UNICODE_OPS_REVERSE[Tokens.FWDFWD_SLASH] = :(//)
UNICODE_OPS_REVERSE[Tokens.CIRCUMFLEX_ACCENT] = :(^)
UNICODE_OPS_REVERSE[Tokens.DECLARATION] = :(::)
UNICODE_OPS_REVERSE[Tokens.CONDITIONAL] = :?
UNICODE_OPS_REVERSE[Tokens.DOT] = :(.)
UNICODE_OPS_REVERSE[Tokens.NOT] = :(!)
UNICODE_OPS_REVERSE[Tokens.PRIME] = Symbol(''')
UNICODE_OPS_REVERSE[Tokens.DDDOT] = :(...)
UNICODE_OPS_REVERSE[Tokens.TRANSPOSE] = Symbol(".'")
UNICODE_OPS_REVERSE[Tokens.ANON_FUNC] = :(->)
UNICODE_OPS_REVERSE[Tokens.WHERE] = :where
