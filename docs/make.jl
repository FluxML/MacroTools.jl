using Documenter, MacroTools

makedocs(
    modules = [MacroTools],
    format  = :html,
    sitename = "MacroTools",
    pages = Any[
        "Introduction to MacroTools"   => "index.md"
    ],
    # Use clean URLs, unless built as a "local" build
    html_prettyurls = !("local" in ARGS),
    # html_canonical = "https://juliadocs.github.io/Documenter.jl/latest/",
)

deploydocs(
    repo = "MikeInnes/MacroTools.jl.git",
    target = "build",
    julia = "1.0",
)
