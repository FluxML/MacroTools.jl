const STRUCTSYMBOL = VERSION < v"0.7-" ? :type : :struct
isstructdef(ex) = Meta.isexpr(ex, STRUCTSYMBOL)

function splitstructdef(ex)
    ex = MacroTools.striplines(ex)
    ex = MacroTools.flatten(ex)
    if @capture(ex, struct header_ body__ end)
        _mutable = false
    elseif @capture(ex, mutable struct header_ body__ end)
        _mutable = true
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
    _supertype = super
    if @capture nameparam name_{param__}
        nothing
    elseif @capture nameparam name_
        param = []
    else
        parse_error(ex)
    end
    _name = name
    _params = param
    _fields = []
    _constructors = []
    for item in body
        if @capture item field_::T_
            push!(_fields, (field, T))
        elseif item isa Symbol
            push!(_fields, (item, Any))
        else
            push!(_constructors, item)
        end
    end
    return (; mutable=_mutable, name=_name, params=_params, supertype=_supertype, fields=_fields, body=_body,)
end

function combinestructdef(d)::Expr
    name = d[:name]
    parameters = d[:params]
    nameparam = isempty(parameters) ? name : :($name{$(parameters...)})
    header = :($nameparam <: $(d[:supertype]))
    fields = map(d[:fields]) do field
        fieldname, typ = field
        :($fieldname::$typ)
    end
    body = quote
        $(fields...)
        $(d[:constructors]...)
    end

    Expr(STRUCTSYMBOL, d[:mutable], header, body)
end

function combinefield(x)
    fieldname, T = x
    :($fieldname::$T)
end
