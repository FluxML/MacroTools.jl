import Base: +

function nodes(ex)
  n = 0
  postwalk(_ -> n += 1, ex)
end

struct Insert
  tree
end

cost(i::Insert) = 1

Base.show(io::IO, i::Insert) = print(io, "insert ", i.tree)

struct Delete
  tree
end

cost(d::Delete) = nodes(d.tree)

Base.show(io::IO, d::Delete) = print(io, "delete ", d.tree)

struct Patch
  ps::Vector{Any}
end

@forward Patch.ps Base.isempty, Base.length

cost(p::Patch) = isempty(p) ? 0 : sum(cost.(p.ps))

a::Patch + b::Patch = Patch([a.ps...,b.ps...])

function Base.show(io::IO, p::Patch)
  println(io, "Expression patch:")
  for p in p.ps
    println(io, p)
  end
end

function best(ps)
  ps = filter(p -> p != nothing, ps)
  ps[findmin(cost.(ps))[2]]
end

label(ex) = ex
label(ex::Expr) = Expr(ex.head)

children(ex) = []
children(ex::Expr) = ex.args

function delete(f1, f2)
  isempty(f1) && return
  fdiff(f1[2:end], f2) + Patch([Delete(f1[1])])
end

function insert(f1, f2)
  isempty(f2) && return
  fdiff(f1, f2[2:end]) + Patch([Insert(f2[1])])
end

function modify(f1, f2)
  (isempty(f1) || isempty(f2)) && return
  label(f1[1]) == label(f2[1]) || return
  fdiff(children(f1[1]), children(f2[1])) +
    fdiff(f1[2:end], f2[2:end])
end

function fdiff(f1, f2)
  isempty(f1) && isempty(f2) && return Patch([])
  best([f(f1, f2) for f in [insert, delete, modify]])
end

diff(x1, x2) = fdiff([x1], [x2])
