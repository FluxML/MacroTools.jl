using CSTParser
import CSTParser: EXPR, AbstractEXPR

struct Location
  ii::Vector{Int}
end

parent(l::Location) = Location(l.ii[1:end-1])
child(l::Location, i) = Location([l.ii..., i])

Base.getindex(ex::EXPR, i::Integer) = ex.args[i]
Base.getindex(ex::AbstractEXPR, i) = collect(ex)[i]

function Base.getindex(ex::AbstractEXPR, l::Location)
  for i in l.ii
    ex = ex[i]
  end
  return ex
end

function charrange(ex::AbstractEXPR, l::Location)
    o = 0
    for i in l.ii
      for j = 1:i-1
        o += ex[j].fullspan
      end
      ex = ex[i]
    end
    full = o .+ (1:ex.fullspan)
    inner = o .+ ex.span
    return full, inner
end

function expr_child_index(x::EXPR, n)
  for (i, a) in enumerate(x.args)
    a isa CSTParser.PUNCTUATION && continue
    n -= 1
    n == 0 && return i
  end
end

function expr_child_index(x::EXPR{CSTParser.Const}, i)
  @assert i == 1
  return 2
end

expr_child_index(x::CSTParser.UnaryOpCall, i) = i
expr_child_index(x::CSTParser.UnarySyntaxOpCall, _) = x.arg1 isa OPERATOR ? 2 : 1
expr_child_index(x::CSTParser.BinaryOpCall, i) = [2, 1, 3][i]
expr_child_index(x::CSTParser.BinarySyntaxOpCall, i) = i+1
expr_child_index(x::CSTParser.ConditionalOpCall, i) = i
expr_child_index(x::EXPR{CSTParser.ChainOpCall}, i) = i == 1 ? 2 : 2(i-1)-1

function expr_child!(ii, ex, i)
  j = expr_child_index(ex, i)
  push!(ii, j)
  return ex[j]
end

function expr_child!(ii, x::EXPR{<:Union{CSTParser.Begin,CSTParser.InvisBrackets}}, i)
  push!(ii, 2, i)
  return x[2][i]
end

function expr_location(ex::AbstractEXPR, ii)
  jj = []
  for i in ii
    ex = expr_child!(jj, ex, i)
  end
  return Location(jj)
end
