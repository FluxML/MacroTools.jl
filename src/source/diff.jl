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

struct Replace
  old
  new
end

cost(r::Replace) = nodes(r.old)

Base.show(io::IO, r::Replace) = print(io, "replace ", r.old, " => ", r.new)

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

struct DiffCtx
  idx::Vector{Int}
  cache::Dict{Any,Patch}
end

DiffCtx() = DiffCtx([],IdDict())

function delete(cx::DiffCtx, f1, f2)
  isempty(f1) && return
  fdiff(cx, f1[2:end], f2) + Patch([Delete(f1[1])])
end

function insert(cx::DiffCtx, f1, f2)
  isempty(f2) && return
  fdiff(cx, f1, f2[2:end]) + Patch([Insert(f2[1])])
end

function replace(cx::DiffCtx, f1, f2)
  (isempty(f1) || isempty(f2)) && return
  (label(f1[1]) == label(f2[1])) && return
  fdiff(cx, f1[2:end], f2[2:end]) + Patch([Replace(f1[1], f2[1])])
end

function modify(cx::DiffCtx, f1, f2)
  (isempty(f1) || isempty(f2)) && return
  label(f1[1]) == label(f2[1]) || return
  fdiff(cx, children(f1[1]), children(f2[1])) +
    fdiff(cx, f1[2:end], f2[2:end])
end

function fdiff(cx::DiffCtx, f1, f2)
  isempty(f1) && isempty(f2) && return Patch([])
  haskey(cx.cache, (f1, f2)) && return cx.cache[(f1, f2)]
  cx.cache[(f1, f2)] = best([f(cx, f1, f2) for f in [replace, insert, delete, modify]])
end

diff(x1, x2) = fdiff(DiffCtx(), [x1], [x2])
