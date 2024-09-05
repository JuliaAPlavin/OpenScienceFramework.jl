# OpenScienceFramework.jl

Interface to the The Open Science Framework ([OSF](https://osf.io/)) API.

# Usage

Example of using the high-level API:

```julia
import OpenScienceFramework as OSF

osf = OSF.Client(; token="...")  # put your OSF token here
proj = OSF.project(osf; title="MyProject")

for d in readdir(OSF.Directory, proj)
    rm(d)
end

@test readdir(OSF.Directory, proj) == []
dir = OSF.directory(proj, "mydir")
@test !isdir(dir)
dir = mkdir(dir)
@test isdir(dir)
@test [basename(d) for d in readdir(OSF.Directory, proj)] == ["mydir"]

@test readdir(OSF.Directory, dir) == []
subdir = OSF.directory(dir, "mysubdir")
@test !isdir(subdir)
subdir = mkdir(subdir)
@test isdir(subdir)
@test [basename(d) for d in readdir(OSF.Directory, dir)] == ["mysubdir"]

@test [basename(d) for d in readdir(OSF.File, dir)] == []
file = OSF.file(dir, "myfile.txt")
@test !isfile(file)
write(file, "my file content")
file = OSF.file(dir, "myfile.txt")
@test isfile(file)
@test [basename(d) for d in readdir(OSF.File, dir)] == ["myfile.txt"]
@test read(file, String) == "my file content"

OSF.url(file)  # get the URL for anonymous downloading
```

## Example for read-only access

```julia
proj = OSF.project("hk9g4")
collect(walkdir(proj))
```

There is also an internal module `OSF.API` with lower-level API functions. They are not covered by semver and may change arbitrarily.
