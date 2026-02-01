# OpenScienceFramework.jl

Julia interface to the [Open Science Framework](https://osf.io/) (OSF), a free platform for sharing research data and materials. This package lets you interact with OSF projects and files using familiar Julia filesystem functions like `readdir`, `cp`, `read`, and `write`.

## Reading from a Public Project

No authentication needed for public projects:

```julia
import OpenScienceFramework as OSF

# connect to a project by its ID (the part after osf.io/ in the URL)
proj = OSF.project(OSF.Client(), "hk9g4")

# list top-level contents — returns OSF.Directory and OSF.File objects
contents = readdir(proj)
basename.(contents)  # just the names

# navigate into a directory
dir = joinpath(proj, "dirname")
readdir(dir)

# read a file directly into memory
f = joinpath(dir, "data.csv")
read(f, String)

# or download to a local path
cp(f, "local_copy.csv")

# get a public download URL
OSF.url(f)
```

## Writing to a Project (Authenticated)

For private projects or any write operations, you need an OSF personal access token — create one at https://osf.io/settings/tokens.

```julia
client = OSF.Client(token="your-token-here")

# find your project by title
proj = OSF.project(client; title="My Research Data")

# upload a file — use OSF.file() to reference a (possibly nonexistent) target
dir = readdir(proj)[1]
cp("local_data.csv", OSF.file(dir, "data.csv"))

# create a new subdirectory
mkdir(joinpath(dir, "results"))

# overwrite an existing file
cp("updated.csv", OSF.file(dir, "data.csv"); force=true)

# write content directly
write(OSF.file(dir, "notes.txt"), "experiment completed")

# delete a file
rm(joinpath(dir, "old_file.csv"))
```

## Supported Filesystem Functions

These standard Julia `Base` functions work on OSF objects:

| Function | Description |
|---|---|
| `readdir(dir)` | List directory contents as `File`/`Directory` objects |
| `joinpath(dir, name)` | Navigate to a child by name |
| `walkdir(dir)` | Recursively traverse directories |
| `read(file)`, `read(file, String)` | Download file contents |
| `write(file, content)` | Upload content to a file |
| `cp(src, dst)` | Copy between local and OSF (both directions) |
| `mkdir(dir)` | Create a directory |
| `mkpath(dir)` | Create a directory (no-op if it exists) |
| `rm(file_or_dir)` | Delete a file or directory |
| `basename(entry)` | Name of the file or directory |
| `abspath(entry)` | Full path within the OSF storage |
| `filesize(file)` | File size in bytes |
| `isdir(entry)`, `isfile(entry)` | Check entry type |

## OSF-Specific Functions

Beyond the filesystem API, these functions handle OSF-specific concepts. See their docstrings for details (`?OSF.versions` etc.).

- `OSF.project(client, id)` / `OSF.project(client; title="...")` — access a project by ID or title
- `OSF.file(dir, name)` / `OSF.directory(proj, path)` — reference entries that may not exist yet (for upload targets)
- `OSF.storage(proj, name)` — access different storage providers (default: `"osfstorage"`)
- `OSF.url(file)` — get a download URL for a file
- `OSF.versions(file)` — get all versions of a file
- `OSF.view_only_links(proj)` — list view-only access links for a project
- `OSF.refresh(entry)` — re-fetch an entry from the server
- `OSF.create_upload_artifact(...)` — create and upload a Julia `Artifact` to OSF

## Internal API

The `OSF.API` submodule provides lower-level access to the [OSF REST API](https://developer.osf.io/). It maps directly to API endpoints and handles pagination, authentication, and JSON deserialization. This is useful for advanced use cases not covered by the high-level interface.
