immutable AnnotatedLine
    line_number::Expr
    expression
end

annotate(arguments) = begin
    result = []
    i = 1
    while i <= length(arguments)
        if isexpr(arguments[i], :line)
            push!(result, AnnotatedLine(arguments[i], arguments[i + 1] ) )
            i = i + 2
        else
            push!(result, arguments[i])
            i = i + 1
        end
    end
    result
end

annotate_line(line_number, line) = Expr(:block, line_number, line)
