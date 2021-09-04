using Seqeval
using Documenter

DocMeta.setdocmeta!(Seqeval, :DocTestSetup, :(using Seqeval); recursive=true)

makedocs(;
    modules=[Seqeval],
    authors="chengchingwen <adgjl5645@hotmail.com> and contributors",
    repo="https://github.com/chengchingwen/Seqeval.jl/blob/{commit}{path}#{line}",
    sitename="Seqeval.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://chengchingwen.github.io/Seqeval.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/chengchingwen/Seqeval.jl",
)
