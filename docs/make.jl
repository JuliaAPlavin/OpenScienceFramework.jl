using Documenter
using OpenScienceFramework

makedocs(
    modules = [OpenScienceFramework],
    sitename = "OpenScienceFramework.jl",
    format = Documenter.HTML(
        prettyurls = false,
        canonical = "https://github.com/PlaviAndrei/OpenScienceFramework.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
        "API Reference" => [
            "Client & Authentication" => "api-client.md",
            "Projects & Components" => "api-projects.md",
            "Files & Directories" => "api-files.md",
            "Filesystem Operations" => "api-filesystem.md",
            "Artifacts" => "api-artifacts.md",
            "Internal API" => "api-internal.md",
        ],
    ],
    checkdocs = :none,
)

deploydocs(
    repo = "github.com/PlaviAndrei/OpenScienceFramework.jl.git",
    branch = "gh-pages",
)
