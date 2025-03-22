using PoGOBase
using Documenter

DocMeta.setdocmeta!(PoGOBase, :DocTestSetup, :(using PoGOBase); recursive = true)

makedocs(;
    modules = [PoGOBase],
    authors = "DrNobody42 <drnobody42@yahoo.com> and contributors",
    sitename = "PoGOBase.jl",
    format = Documenter.HTML(;
        canonical = "https://JuliaPokemonGO.github.io/PoGOBase.jl",
        edit_link = "main",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo = "github.com/JuliaPokemonGO/PoGOBase.jl",
    devbranch = "main",
)
