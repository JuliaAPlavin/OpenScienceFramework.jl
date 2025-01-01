# OpenScienceFramework.jl

Interface to the The Open Science Framework ([OSF](https://osf.io/)) API.

# Usage

`OpenScienceFramework.jl` supports Julia Filesystem API:

```julia
import OpenScienceFramework as OSF

# public OSF projects:
proj = OSF.project(OSF.Client(), "<project id>")

readdir(proj)

read(readdir(proj)[1], String)

cp(readdir(proj)[1], "/some/local/path")

OSF.url(readdir(proj)[1])

# private OSF projects:
proj = OSF.project(OSF.Client(; token="your OSF token"); title="MyProject")

basename.(readdir(proj))

mkdir(joinpath(readdir(proj)[1], "newdir"))

cp("local_file", OSF.file(readdir(proj)[1], "remote_file"))

OSF.url(readdir(proj)[1])
```

There is also an internal module `OSF.API` with lower-level API functions. They are not covered by semver and may change arbitrarily.
