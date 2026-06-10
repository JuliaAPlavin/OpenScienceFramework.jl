# OpenScienceFramework.jl

Julia interface to the [Open Science Framework](https://osf.io/) (OSF), a free platform for sharing research data and materials.

## Overview

This package provides a familiar filesystem-like API for interacting with OSF projects and files. You can use standard Julia functions such as `readdir`, `cp`, `read`, `write`, `mkdir`, and `rm` on OSF objects, making it intuitive to work with remote storage.

## Quick Example

```julia
import OpenScienceFramework as OSF

# Access a public project
proj = OSF.project(OSF.Client(), "hk9g4")

# List contents
contents = readdir(proj)

# Navigate and read a file
f = joinpath(proj, "data.csv")
data = read(f, String)
```

## Features

- **Public Access**: Read from public projects without authentication
- **Authenticated Operations**: Write, create, and delete with a personal access token
- **Filesystem API**: Familiar `Base` functions (`readdir`, `cp`, `read`, `write`, etc.)
- **View-Only Links**: Access private projects via view-only links
- **File Versioning**: Access and download specific file versions
- **Julia Artifacts**: Create and upload Julia package artifacts to OSF storage

## Installation

Add the package using the Julia package manager:

```julia
import Pkg
Pkg.add("OpenScienceFramework")
```

## Authentication

For read-only access to public projects, no authentication is needed. For private projects or write operations, you need an OSF personal access token. Create one at [https://osf.io/settings/tokens](https://osf.io/settings/tokens).

The token can be provided explicitly or via the `OSF_TOKEN` environment variable:

```julia
# Reads OSF_TOKEN from environment
client = OSF.Client()

# Or pass explicitly
client = OSF.Client(token="your-token-here")
```

## Documentation

- [Getting Started](getting-started.md)
- [Client & Authentication](api-client.md)
- [Projects & Components](api-projects.md)
- [Files & Directories](api-files.md)
- [Filesystem Operations](api-filesystem.md)
- [Artifacts](api-artifacts.md)
- [Internal API](api-internal.md)
