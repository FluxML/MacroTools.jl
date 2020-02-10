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
