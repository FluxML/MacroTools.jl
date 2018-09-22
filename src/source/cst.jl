using CSTParser
using CSTParser: EXPR, Location, expr_location, charrange

struct SourceFile
  path::String
  text::String
  cst::EXPR
  ast::Expr
end

function SourceFile(path::String)
  text = String(read(path))
  cst = CSTParser.parse(text, true)
  SourceFile(path, text, cst, Expr(cst))
end

function replacement(src::SourceFile, p::Replace)
  _, span = charrange(src.cst, expr_location(src.cst, p.idx))
  span => sprint(show, p.new)
end

replacement(src::SourceFile, p::Patch) = [replacement(src, p) for p in p.ps]

function patch(io::IO, src::SourceFile, rs)
  rs = sort(rs, by=x->first(x[1]))
  offset = 1
  for r in rs
    print(io, src.text[(offset:first(r[1])-1)])
    print(io, r[2])
    offset = last(r[1])+1
  end
  print(io, src.text[offset:end])
end

patch(io::IO, src::SourceFile, p::Patch) = patch(io, src, replacement(src, p))

patch(src::SourceFile, p) = sprint(patch, src, p)

function patch!(src::SourceFile, p)
  open(src.path, "w") do io
    patch(io, src, p)
  end
end
