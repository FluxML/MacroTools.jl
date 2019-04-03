using Documenter, MacroTools

makedocs(
    sitename = "MacroTools",
    pages = [
        "Home" => "index.md"],
    format=:html)

deploydocs(
    repo = "github.com/MikeInnes/MacroTools.jl.git",
    julia="1.0")
