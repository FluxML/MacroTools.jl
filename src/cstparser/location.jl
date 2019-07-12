struct Location
  ii::Vector{Union{Int,Symbol}}
end

Location() = Location([])

parent(l::Location) = Location(l.ii[1:end-1])
Base.getindex(l::Location, i...) = Location([l.ii..., i...])

Base.getindex(ex::EXPR, i::Integer) = ex.args[i]
Base.getindex(ex::AbstractEXPR, i) = collect(ex)[i]

function Base.getindex(ex::AbstractEXPR, l::Location)
  for i in l.ii
    ex = i isa Integer ? ex[i] : getproperty(ex, i)
  end
  return ex
end

# HACK
index_in_collected(ex, k) = findfirst(x -> x === getproperty(ex, k), collect(ex))

function charrange(ex::AbstractEXPR, l::Location)
    o = 0
    for i in l.ii
      i isa Symbol && (i = index_in_collected(ex, i))
      for j = 1:i-1
        o += ex[j].fullspan
      end
      ex = ex[i]
    end
    full = o .+ (1:ex.fullspan)
    inner = o .+ (1:ex.span)
    return full, inner
end
