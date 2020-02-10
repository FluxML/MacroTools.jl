export unwrap_fun, wrap_fun, unwrap_head, wrap_head, unwrap_fcall, wrap_fcall
################################################################
"""
    head, body = unwrap_fun(fexpr)
    fcall, wherestack, body = unwrap_fun(fexpr,true)
    f, args, wherestack, body = unwrap_fun(fexpr, true, true)

Unwraps function expression.
"""
function unwrap_fun(expr::Expr)
    if expr.head in (:function, :(=))
        fexpr = expr
    elseif expr.head == :block
        fexpr = expr.args[2] # separate fexpr from block
    else
        error("Expression is not supported")
    end

    head = fexpr.args[1]
    body = fexpr.args[2]
    return head, body
end

function unwrap_fun(expr::Expr, should_unwrap_head::Bool)
    if expr.head in (:function, :(=))
        fexpr = expr
    elseif expr.head == :block
        fexpr = expr.args[2] # separate fexpr from block
    else
        error("Expression is not supported")
    end

    head = fexpr.args[1]
    fcall, wherestack = unwrap_head(head)
    body = fexpr.args[2]
    return fcall, wherestack, body
end

function unwrap_fun(expr::Expr, should_unwrap_head::Bool, should_unwrap_fcall::Bool)
    if expr.head in (:function, :(=))
        fexpr = expr
    elseif expr.head == :block
        fexpr = expr.args[2] # separate fexpr from block
    else
        error("Expression is not supported")
    end

    head = fexpr.args[1]
    fcall, wherestack = unwrap_head(head)
    f, args = unwrap_fcall(fcall)

    body = fexpr.args[2]
    return f, args, wherestack, body
end
################################################################
"""
    fexpr = wrap_fun(f, args, wherestack, body)
    fexpr = wrap_fun(fcall, wherestack, body)
    fexpr = wrap_fun(head, body)
    fexpr = wrap_fun(fexpr)

Returns a function definition expression
"""
function wrap_fun(f, args, wherestack, body)
    fcall = wrap_fcall(f, args)
    head =  wrap_head(fcall, wherestack)
    return Expr(:function, head, Expr(:block, body))
end

function wrap_fun(fcall, wherestack, body)
    head =  wrap_head(fcall, wherestack)
    return Expr(:function, head, Expr(:block, body))
end

function wrap_fun(head::Expr, body::Expr)
    return Expr(:function, head, Expr(:block, body))
end

function wrap_fun(fexpr::Expr)
    if fexpr.head in (:function, :(=))
        return fexpr
    elseif fexpr.head == :block
        fexpr = fexpr.args[2] # separate fexpr from block
        return fexpr
    else
        error("Expression is not supported")
    end
end

################################################################
function unwrap_head(head)
    wherestack = Any[]
    while head isa Expr && head.head == :where
        push!(wherestack, head.args[2])
        head = head.args[1]
    end
    fcall = head
    fcall, wherestack
end

function wrap_head(fcall, wherestack)
    for w in Iterators.reverse(wherestack)
        fcall = Expr(:where, fcall, w)
    end
    head = fcall
    return head
end
################################################################
function unwrap_fcall(fcall::Expr)
    if !(fcall.head == :call)
        error("Expression is not supported")
    end
    f = fcall.args[1]
    args = fcall.args[2:end]
    return f, args
end

function wrap_fcall(f, args)
    fcall = :($f($((args)...)))
    return fcall
end
################################################################
