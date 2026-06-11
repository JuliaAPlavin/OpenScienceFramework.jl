# Filesystem Operations

OpenScienceFramework.jl implements standard Julia `Base` functions for OSF objects, providing a familiar filesystem-like API. The following `Base` functions are extended to work with OSF types:

## Reading Directory Contents

`readdir` lists the contents of a project root or directory, returning a vector of `File` and `Directory` objects.

```@docs
Base.readdir
```

## Walking Directory Trees

`walkdir` recursively traverses the directory tree, yielding `(dir, subdirs, files)` tuples.

```@docs
Base.walkdir
```

## Reading Files

`read` downloads file contents from OSF. Returns bytes by default, or a `String` with the two-argument form.

```@docs
Base.read
```

## Writing Files

`write` uploads content to OSF. Overwrites the file if it already exists, or creates a new file.
`content` can be any IO-compatible object or byte data.

## Copying Files

`cp` copies files or directories between local filesystem and OSF in both directions. Directories are copied recursively.

```@docs
Base.cp
```

## Creating Directories

`mkdir` creates a single directory. `mkpath` creates a directory and all missing parent directories recursively.

## Deleting Entries

`rm` deletes files or directories from OSF. Directories require `recursive=true`. Use `force=true` to suppress errors on nonexistent entries.

```@docs
Base.rm
```

## Path Operations

The following path utility functions are supported on OSF types:

- `basename` — return the name of the entry
- `abspath` — return the full OSF path
- `filesize` — return the file size in bytes (for files)
- `isdir` / `isfile` — check the entry type
- `joinpath` — navigate to a child entry (see [Files & Directories](api-files.md))
