using CSTParser
using CSTParser: EXPR, Location, expr_location, charrange

struct SourceFile
  path::String
  src::String
  cst::EXPR
  ast::Expr
end

function SourceFile(path::String)
  src = String(read(path))
  cst = CSTParser.parse(src, true)
  SourceFile(path, src, cst, Expr(cst))
end

function patch(src::SourceFile, p::Replace)
  _, span = charrange(src.cst, expr_location(src.cst, p.idx))
  span => sprint(show, p.new)
end

patch(src::SourceFile, p::Patch) = [patch(src, p) for p in p.ps]
