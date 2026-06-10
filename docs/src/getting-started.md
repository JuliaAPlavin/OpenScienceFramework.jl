# Getting Started

This guide walks you through the basics of using OpenScienceFramework.jl.

## Accessing a Public Project

No authentication is needed for public projects:

```julia
import OpenScienceFramework as OSF

# Connect to a project by its ID (the alphanumeric string from the URL)
proj = OSF.project(OSF.Client(), "hk9g4")

# List top-level contents
contents = readdir(proj)
names = basename.(contents)

# Navigate into a directory
dir = joinpath(proj, "my_folder")
readdir(dir)

# Read a file
f = joinpath(dir, "data.csv")
content = read(f, String)

# Download to local path
cp(f, "local_copy.csv")

# Get a public download URL
OSF.url(f)
```

## Working with Private Projects

For private projects or write operations, authenticate with a personal access token:

```julia
# Create authenticated client
client = OSF.Client(token="my-token")

# Access your project by title
proj = OSF.project(client; title="My Research Data")

# Upload a file
dir = readdir(proj)[1]
cp("local_file.csv", OSF.file(dir, "uploaded.csv"))

# Create a directory
mkdir(joinpath(dir, "new_folder"))

# Write content directly
write(OSF.file(dir, "notes.txt"), "some notes")

# Delete a file
rm(joinpath(dir, "old_file.csv"))
```

## View-Only Access

You can access a private project using a view-only link key without a personal token:

```julia
client = OSF.Client(view_only="your-view-only-key")
proj = OSF.project(client, "project-id")
```

## Creating Projects and Components

```julia
# Create a new project
proj = OSF.create_project(client; title="New Project", public=false)

# Create a component under a project
comp = OSF.create_component(proj; title="Analysis Component")

# List components
OSF.components(proj)
```

## File Versioning

OSF tracks file versions. You can access them:

```julia
f = joinpath(proj, "data.csv")
all_versions = OSF.versions(f)

# Read a specific version
content = read(all_versions[1], String)
```
