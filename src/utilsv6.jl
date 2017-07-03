# Code that doesn't parse under Julia 0.5

function longdef1_where(ex)
    @match ex begin
        (f_(args__) where {whereparams__} = body_) =>
            @q function $f($(args...)) where {$(whereparams...)}
                $body end
        ((f_(args__)::rtype_) where {whereparams__} = body_) =>
            @q function ($f($(args...))::$rtype) where {$(whereparams...)}
                $body end
        _ => ex
    end
end
function splitwhere(fdef)
    @assert(@capture(longdef1(fdef),
                     function ((fcall_ where {whereparams__}) | fcall_)
                     body_ end),
            "Not a function definition: $fdef")
    return fcall, body, whereparams
end
