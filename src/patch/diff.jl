import Base: +, isoperator

nodes(x) = 1
function nodes(x::Expr)
  n = 1
  for y in x.args
    n += nodes(y)
  end
  return n
end

struct Insert
  idx::Vector{Int}
  tree
end

cost(i::Insert) = 1

function Base.show(io::IO, i::Insert)
  print(io, "insert ")
  show(io, i.tree)
end

struct Delete
  idx::Vector{Int}
  tree
end

cost(d::Delete) = nodes(d.tree)

function Base.show(io::IO, d::Delete)
  print(io, "delete ")
  show(io, d.tree)
end

struct Replace
  idx::Vector{Int}
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

isopchange(x1, x2) =
  isexpr(x1, :call) &&
  x1.args[1] isa Symbol &&
  x2.args[1] isa Symbol &&
  x1.args[1] != x2.args[1] &&
  (isoperator(x1.args[1]) || isoperator(x2.args[1]))

shouldreplace(x1, x2) = x1 != x2

shouldreplace(x1::Expr, x2::Expr) = x1.head != x2.head || isopchange(x1, x2)

canshift(head, i) = !(head == :call && i == 1)

function nleft(xs)
  h = zeros(Int, length(xs) + 1)
  for i = length(xs):-1:1
    h[i] = h[i+1] + nodes(xs[i])
  end
  return h
end

htable(x, y) = Broadcast.broadcasted((x, y) -> x > y ? x-y : y > x ? 1 : 0, nleft(x), nleft(y)')

function fdiff(head, ii, f1, f2)
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
    if canshift(head, i)
      i < m && !complete[i+1,j] && visit!(i+1, j, p + Patch([Delete([ii...,i], f1[i])]))
      j < n && !complete[i,j+1] && visit!(i, j+1, p + Patch([Insert([ii...,i], f2[j])]))
    end
    i < m && j < n && !complete[i+1,j+1] && visit!(i+1, j+1, p + diff([ii...,i],f1[i],f2[j]))
  end
end

diff(ii, x1, x2) =
  (x1,x2) isa NTuple{2,Union{LineNumberNode,Nothing}} ? Patch([]) :
  shouldreplace(x1, x2)  ? Patch([Replace(ii, x1, x2)]) :
  x1 == x2               ? Patch([]) :
  fdiff(x1.head, ii, x1.args, x2.args)

diff(a, b) = diff([], a, b)
