using CSTParser
using CSTParser: EXPR, Call, Location, LocExpr, exprloc, charrange

expridx(x, ii) = (@assert isempty(ii); x)
expridx(x::Expr, ii) = isempty(ii) ? x : expridx(x.args[ii[1]], ii[2:end])
expridx(x::LocExpr, ii) = expridx(x.expr, ii)

function precedence_level(cst::EXPR, loc::Location)
  parent = cst[CSTParser.parent(loc)]
  if parent isa Union{CSTParser.BinaryOpCall,CSTParser.UnaryOpCall,CSTParser.ChainOpCall}
    Base.operator_precedence(Expr(parent).args[1])
  elseif parent isa Union{CSTParser.BinarySyntaxOpCall,CSTParser.UnarySyntaxOpCall}
    Base.operator_precedence(Expr(parent).head)
  else
    0
  end
end

# Get the range at loc, including trailing trivia from the previous node.
function separator_range(cst, loc)
  i = loc.ii[end]
  loc = CSTParser.parent(loc)
  start = charrange(cst, loc[i-1])[1][1]+1
  stop = charrange(cst, loc[i])[1][end]
  return start:stop
end

function separator(cst, loc, x::EXPR{Call}, i)
  length(x.args) == 3 && return ""
  length(x.args) == 4 && return ", "
  separator_range(cst, loc[max(i-1,4)])
end

function separator(cst, loc, x::EXPR{CSTParser.MacroCall}, i)
  if get(x.args, 2, nothing) isa CSTParser.PUNCTUATION # @foo(a, b)
    length(x.args) == 3 && return ""
    length(x.args) == 4 && return ", "
    separator_range(cst, loc[max(i-1,4)])
  else                                   # @foo a b
    length(x.args) == 1 && return " "
    outer, inner = charrange(cst, loc[i-1])
    inner[end]+1:outer[end]
  end
end

function separator(cst, loc, x::EXPR{CSTParser.TupleH}, i)
  brackets = x.args[1] isa CSTParser.PUNCTUATION
  length(x.args) == 2brackets && return ""
  length(x.args) == 1+2brackets && return ", "
  separator_range(cst, loc[max(i-1,2+brackets)])
end

ex = CSTParser.parse("a, b")
separator(ex, CSTParser.Location(), ex, 1)

ex = CSTParser.parse("(a,)")
separator(ex, CSTParser.Location(), ex, 2)

function separator(cst, loc, x::EXPR{CSTParser.Block}, i)
  out, in = charrange(cst, loc[max(i-1,1)])
  in[end]+1:out[end]
end

function separator(cst, loc, x::CSTParser.BinaryOpCall, i)
  separator_range(cst, loc[2])
end

function separator(cst::EXPR, loc::Location)
  parent = CSTParser.parent(loc)
  separator(cst, parent, cst[parent], loc.ii[end])
end

struct SourceFile
  path::String
  text::String
  cst::EXPR
  ast::LocExpr
end

function SourceFile(path::String, text = String(read(path)))
  cst = CSTParser.parse(text, true)
  SourceFile(path, text, cst, LocExpr(cst))
end

function replacement(src::SourceFile, p::Replace)
  loc = exprloc(src.ast, p.idx)
  if loc == nothing
    @warn "No location found for $(repr(CSTParser.striploc(expridx(src.ast, p.idx))))"
    return
  end
  prec = precedence_level(src.cst, loc)
  _, span = charrange(src.cst, loc)
  span => sprint(Base.show_unquoted, p.new, 0, prec)
end

function replacement(src::SourceFile, p::Insert)
  append = p.idx[end] > length(expridx(src.ast, p.idx[1:end-1]).args)
  append && (p.idx[end] -= 1)
  loc = exprloc(src.ast, p.idx)
  # TODO handle cases like this more generally
  src.cst[CSTParser.parent(loc)] isa EXPR{Call} && (loc.ii[end] = max(loc.ii[end], 2))
  _, span = charrange(src.cst, loc)
  point = append ? span[end] : span[1]-1
  sep = separator(src.cst, loc)
  sep isa AbstractRange && (sep = src.text[sep])
  (1:0).+point => sprint() do io
    append && write(io, sep)
    Base.show_unquoted(io, p.tree, 0, 0)
    append || write(io, sep)
  end
end

function replacement(src::SourceFile, p::Delete)
  loc = exprloc(src.ast, p.idx)
  span, _ = charrange(src.cst, loc)
  sep = separator(src.cst, loc)
  sep isa AbstractRange || (sep = span)
  span = span[1] > sep[1] ? (sep[1]:span[end]) : (span[1]:sep[end])
  span => ""
end

replacement(src::SourceFile, p::Patch) =
  filter(x -> x != nothing, [replacement(src, p) for p in p.ps])

function patch(io::IO, src::SourceFile, rs)
  rs = sort(rs, by=x->first(x[1]))
  offset = 1
  for r in rs
    print(io, src.text[offset:prevind(src.text, first(r[1]))])
    print(io, r[2])
    offset = last(r[1])+1
  end
  print(io, src.text[offset:end])
end

patch(io::IO, src::SourceFile, p::Patch) = patch(io, src, replacement(src, p))

patch(src::SourceFile, p) = sprint(patch, src, p)

function patch!(src::SourceFile, p)
  s = read(src.path)
  open(src.path, "w") do io
    try
      patch(io, src, p)
    catch _
      seek(io, 0)
      write(io, s)
      rethrow()
    end
  end
end

function sourcemap(f, src::SourceFile)
  expr = CSTParser.striploc(src.ast)
  ex = striplines(f(expr))
  patch(src, diff(expr, ex))
end

function sourcemap(f, path::AbstractString)
  isdir(path) && return sourcemap_dir(f, path)
  isfile(path) || error("No file at $path")
  s = SourceFile(path)
  expr = CSTParser.striploc(s.ast)
  ex = striplines(f(expr))
  patch!(s, diff(expr, ex))
  return
end

function sourcemap_dir(f, path)
  @sync for (dir, _, fs) in walkdir(path), file in fs
    @async if endswith(file, ".jl")
      @info "SourceWalk: processing $file"
      sourcemap(f, joinpath(dir, file))
    end
  end
end

sourcewalk(f, file) = sourcemap(x -> postwalk(f, x), file)

textmap(f, text) = sourcemap(f, SourceFile("", text))

textwalk(f, text) = sourcewalk(f, SourceFile("", text))
