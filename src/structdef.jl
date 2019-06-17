const STRUCTSYMBOL = VERSION < v"0.7-" ? :type : :struct
isstructdef(ex) = Meta.isexpr(ex, STRUCTSYMBOL)

function splitstructdef(ex)
    ex = MacroTools.striplines(ex)
    ex = MacroTools.flatten(ex)
    d = Dict{Symbol, Any}()
    if @capture(ex, struct header_ body__ end)
        d[:mutable] = false
    elseif @capture(ex, mutable struct header_ body__ end)
        d[:mutable] = true
    else
        parse_error(ex)
    end
    if @capture header nameparam_ <: super_
        nothing
    elseif @capture header nameparam_
        super = :Any
    else
        parse_error(ex)
    end
    d[:supertype] = super
    if @capture nameparam name_{param__}
        nothing
    elseif @capture nameparam name_
        param = []
    else
        parse_error(ex)
    end
    d[:name] = name
    d[:params] = param
    d[:fields] = []
    d[:constructors] = []
    for item in body
        if @capture item field_::T_= def_
            push!(d[:fields], (field, T, def))
        elseif @capture item field_= def_
            push!(d[:fields], (field, Any, def))
        elseif @capture item field_::T_
            push!(d[:fields], (field, T, nothing))
        elseif item isa Symbol
            push!(d[:fields], (item, Any, nothing))
        else
            push!(d[:constructors], item)
        end
    end
    d
end

function combinestructdef(d)::Expr
    name = d[:name]
    parameters = d[:params]
    nameparam = isempty(parameters) ? name : :($name{$(parameters...)})
    header = :($nameparam <: $(d[:supertype]))
    fields = map(combinefield, d[:fields])
    body = quote
        $(fields...)
        $(d[:constructors]...)
    end

    Expr(STRUCTSYMBOL, d[:mutable], header, body)
end

function combinefield(x)
    fieldname, T, def = x
    def === nothing ? :($fieldname::$T) : :($fieldname::$T= $def)
end
