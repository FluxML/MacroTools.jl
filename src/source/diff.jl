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

function nleft(xs)
  h = zeros(Int, length(xs) + 1)
  for i = length(xs):-1:1
    h[i] = h[i+1] + nodes(xs[i])
  end
  return h
end

htable(x, y) = Broadcast.broadcasted((x, y) -> x > y ? x-y : y > x ? 1 : 0, nleft(x), nleft(y)')

function fdiff(f1, f2)
  f1 == f2 && return Patch([])
  isempty(f1) && return Patch(Insert.(f2))
  isempty(f2) && return Patch(Delete.(f1))
  m, n = length(f1)+1, length(f2)+1
  ps = Dict{Tuple{Int,Int},Patch}()
  q = PriorityQueue{Tuple{Int,Int},Int}()
  complete = falses(m, n)
  h = htable(f1, f2)
  function visit!(i, j, p)
    haskey(ps, (i, j)) && (p.cost >= ps[(i,j)].cost) && return
    ps[(i,j)] = p
    q[(i,j)] = p.cost + h[i,j]
  end
  visit!(1, 1, Patch([]))
  while !isempty(q)
    (i, j) = dequeue!(q)
    (i,j) == (m,n) && return ps[(i,j)]
    complete[i,j] = true
    p = ps[(i, j)]
    i < m && !complete[i+1,j] && visit!(i+1, j, p + Patch([Delete(f1[i])]))
    j < n && !complete[i,j+1] && visit!(i, j+1, p + Patch([Insert(f2[j])]))
    i < m && j < n && !complete[i+1,j+1] && visit!(i+1, j+1,p + diff(f1[i],f2[j]))
  end
end

diff(x1, x2) =
  label(x1) != label(x2) ? Patch([Replace(x1, x2)]) :
  x1 == x2               ? Patch([]) :
  fdiff(children(x1), children(x2))
