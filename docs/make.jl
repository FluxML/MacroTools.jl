using Documenter, MacroTools

makedocs(
    sitename = "MacroTools",
    pages = [
        "Home" => "index.md"])

deploydocs(
  repo = "github.com/MikeInnes/MacroTools.jl.git",)
