using Documenter, MacroTools

makedocs(
    sitename = "MacroTools",
    pages = [
        "Home" => "index.md",
        "Pattern Matching" => "pattern-matching.md",
        "Utilities" => "utilities.md"],
    format = Documenter.HTML(prettyurls = haskey(ENV, "CI")))

deploydocs(
  repo = "github.com/FluxML/MacroTools.jl.git",
  push_preview = true)
