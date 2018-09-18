import Base: +

function nodes(ex)
  n = 0
  postwalk(_ -> n += 1, ex)
end

struct Insert
  tree
end

cost(i::Insert) = 1

function Base.show(io::IO, i::Insert)
  print(io, "insert ")
  show(io, i.tree)
end

struct Delete
  tree
end

cost(d::Delete) = nodes(d.tree)

function Base.show(io::IO, d::Delete)
  print(io, "delete ")
  show(io, d.tree)
end

struct Replace
  old
  new
end

cost(r::Replace) = nodes(r.old)

function Base.show(io::IO, r::Replace)
  print(io, "replace ")
  show(io, r.old)
  print(io, " => ")
  show(io, r.new)
end

struct Patch
  cost::Int
  ps::Vector{Any}
end

Patch(ps) = Patch(isempty(ps) ? 0 : sum(cost.(ps)), ps)

@forward Patch.ps Base.isempty, Base.length

a::Patch + b::Patch = Patch(a.cost + b.cost, vcat(a.ps, b.ps))

function Base.show(io::IO, p::Patch)
  println(io, "Expression patch:")
  for p in p.ps
    println(io, p)
  end
end

best(a::Patch) = a
best(a::Patch, b::Patch, c...) = best(a.cost < b.cost ? a : b, c...)

label(ex) = ex
label(ex::Expr) = Expr(ex.head)

children(ex) = []
children(ex::Expr) = ex.args

function fdiff(f1, f2)
  f1 == f2 && return Patch([])
  isempty(f1) && return Patch(Insert.(f2))
  isempty(f2) && return Patch(Delete.(f1))
  ps = Matrix{Patch}(undef, length(f1)+1, length(f2)+1)
  ps[1,1] = Patch([])
  for i = 1:length(f1)
    ps[i+1,1] = Patch(Delete.(f1[1:end-(length(f1)-i)]))
  end
  for j = 1:length(f2)
    ps[1, j+1] = Patch(Insert.(f2[1:end-(length(f2)-j)]))
  end
  for i = 1:length(f1), j = 1:length(f2)
    delete = ps[i, j+1] + Patch([Delete(f1[i])])
    insert = ps[i+1, j] + Patch([Insert(f2[j])])
    modify = ps[i,j] + diff(f1[i],f2[j])
    ps[i+1,j+1] = best(delete, insert, modify)
  end
  return ps[end,end]
end

diff(x1, x2) =
  label(x1) != label(x2) ? Patch([Replace(x1, x2)]) :
  x1 == x2               ? Patch([]) :
  fdiff(children(x1), children(x2))
