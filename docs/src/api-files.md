# Files & Directories

OSF storage is accessed through types that mirror filesystem concepts.

## Core Types

```@docs
OpenScienceFramework.Directory
OpenScienceFramework.File
```

## Nonexistent Entries

When looking up paths that don't exist, the package returns wrapper types that can be used as targets for creation operations:

```@docs
OpenScienceFramework.DirectoryNonexistent
OpenScienceFramework.FileNonexistent
OpenScienceFramework.Nonexistent
```

## Navigation

```@docs
OpenScienceFramework.directory
OpenScienceFramework.file
Base.joinpath
```

## Refreshing Entries

Re-fetch an entry from the server to get updated metadata:

```@docs
OpenScienceFramework.refresh
```

## File Versioning

OSF maintains version history for files:

```@docs
OpenScienceFramework.FileVersion
OpenScienceFramework.revision_number
OpenScienceFramework.versions
```

## URLs

```@docs
OpenScienceFramework.url
```
