"""
    Project

An OSF project. Obtain via [`project(client, id)`](@ref) or [`project(client; title=...)`](@ref).
Acts as a root directory — supports `readdir`, `joinpath`, `walkdir`.
"""
struct Project
    client::API.Client
    entity::API.Entity{:nodes}
end
client(x::Project) = x.client
client(x) = client(project(x))

"""
    project(client, id::String)
    project(client; title::String, user::String="me")

Get an OSF project. Either by its ID (the alphanumeric string from the project URL, e.g. `"hk9g4"`),
or by searching for a `title` among projects owned by `user` (defaults to the authenticated user).
The `title` must match exactly and uniquely.
"""
project(c::API.Client, id::String) = OSF.Project(c, OSF.API.get_entity(c, :nodes, id))

function project(c::API.Client; user::String="me", title::String)
    user_e = API.get_entity(c, :users, user)
    projs = API.relationship(c, user_e, :nodes, filters=["title" => title]).data
    proj_e = only(projs)
    @assert proj_e.attributes[:title] == title
    Project(c, proj_e)
end

"""
    storage(proj::Project, name::String)

Get a storage provider for the project by name. Most projects use `"osfstorage"` (the default),
but OSF also supports linked storage like Google Drive, S3, etc.
"""
storage(proj::Project, ::Nothing) = storage(proj, "osfstorage")
storage(proj::Project, storage::String) = let
    storages = API.relationship(client(proj), proj.entity, :files).data
    only(filter(s -> s.attributes[:name] == storage, storages))
end
storage(::Project, storage::API.Entity{:files}) = storage

Base.isdir(::Project) = true
Base.isfile(::Project) = false
Base.basename(p::Project) = ""
Base.abspath(p::Project) = "/"

"""
    Directory

A directory (folder) in OSF storage. Obtain via `readdir`, `joinpath`, or [`directory`](@ref).
Supports `readdir`, `joinpath`, `walkdir`, `mkdir` (for children), `rm`.
"""
struct Directory
    project::Project
    storage::API.Entity{:files}
    entity::API.Entity{:files}
end

project(x::Directory) = x.project
Base.isdir(::Directory) = true
Base.isfile(::Directory) = false
Base.basename(d::Directory) = d.entity.attributes[:name]
Base.abspath(d::Directory) = d.entity.attributes[:path] == "/" ? "/" : d.entity.attributes[:materialized_path]

"""
    DirectoryNonexistent

A reference to a directory that doesn't exist yet in OSF. Returned by [`directory`](@ref) when the path is not found.
Use with `mkdir` to create it.
"""
struct DirectoryNonexistent
    project::Project
    storage::API.Entity{:files}
    path::String
end

project(x::DirectoryNonexistent) = x.project
Base.isdir(::DirectoryNonexistent) = false
Base.isfile(::DirectoryNonexistent) = false
Base.basename(d::DirectoryNonexistent) = basename(dirname(d.path))
Base.abspath(d::DirectoryNonexistent) = d.path


"""
    File

A file in OSF storage. Obtain via `readdir`, `joinpath`, or [`file`](@ref).
Supports `read`, `write`, `cp`, `rm`, `basename`, `abspath`, `filesize`.
"""
struct File
    project::Project
    storage::API.Entity{:files}
    entity::API.Entity{:files}
end

project(x::File) = x.project
Base.isdir(::File) = false
Base.isfile(::File) = true
Base.basename(d::File) = d.entity.attributes[:name]
Base.abspath(d::File) = d.entity.attributes[:materialized_path]
Base.filesize(d::File) = d.entity.attributes[:size]

"""
    FileNonexistent

A reference to a file that doesn't exist yet in OSF. Returned by [`file`](@ref) when the path is not found.
Use as a target for `cp` or `write` to create the file.
"""
struct FileNonexistent
    project::Project
    storage::API.Entity{:files}
    path::String
end

project(x::FileNonexistent) = x.project
Base.isdir(::FileNonexistent) = false
Base.isfile(::FileNonexistent) = false
Base.basename(d::FileNonexistent) = basename(d.path)
Base.abspath(d::FileNonexistent) = d.path
Base.filesize(d::FileNonexistent) = 0


Base.show(io::IO, p::Project) = print(io, "OSF Project `$(p.entity.attributes[:title])`, id $(p.entity.id)")
Base.show(io::IO, x::Directory) = print(io, "OSF Directory `$(abspath(x))`")
Base.show(io::IO, x::File) = print(io, "OSF File `$(abspath(x))` ($(Base.format_bytes(filesize(x))))")
Base.show(io::IO, x::DirectoryNonexistent) = print(io, "OSF Directory `$(x.path)` (doesn't exist)")
Base.show(io::IO, x::FileNonexistent) = print(io, "OSF File `$(x.path)` (doesn't exist)")


Base.islink(a::Union{Directory,File}) = false

"""
    directory(proj::Project, path; storage=nothing)
    directory(parent::Directory, name)

Look up a directory by path (from project root) or by name (within a parent directory).
Returns a [`Directory`](@ref) if found, or a [`DirectoryNonexistent`](@ref) if the path doesn't exist.
The `storage` keyword selects the storage provider (defaults to `"osfstorage"`).
"""
function directory(proj::Project, path::AbstractString; storage=nothing)
    storage_e = (@__MODULE__).storage(proj, storage)
    path = endswith(path, "/") ? path : "$(path)/"
    path = startswith(path, "/") ? path : "/$(path)"
    dir_e = API.find_by_path(client(proj), storage_e, path)
    if isnothing(dir_e)
        return DirectoryNonexistent(proj, storage_e, path)
    else
        @assert dir_e.attributes[:kind] == "folder"
        @assert dir_e.attributes[:path] == "/" || dir_e.attributes[:materialized_path] == path
        return Directory(proj, storage_e, dir_e)
    end
end

function directory(parent::Directory, name::AbstractString)
    @assert !occursin("/", strip(name, '/'))  name
    path = "$(rstrip(abspath(parent), '/'))/$(lstrip(name, '/'))"  # not joinpath() because on windows it uses \
    path = endswith(path, "/") ? path : "$(path)/"
    @assert startswith(path, "/")  path
    dir_e = API.find_by_path(client(parent), parent.entity, path)
    if isnothing(dir_e)
        return DirectoryNonexistent(project(parent), parent.storage, path)
    else
        @assert dir_e.attributes[:kind] == "folder"
        @assert dir_e.attributes[:path] == "/" || dir_e.attributes[:materialized_path] == path
        return Directory(project(parent), parent.storage, dir_e)
    end
end

directory(f::Union{File, FileNonexistent}) = directory(project(f), dirname(abspath(f)); f.storage)

"""
    file(parent::Directory, name)

Look up a file by name within a directory.
Returns a [`File`](@ref) if found, or a [`FileNonexistent`](@ref) if it doesn't exist.
Use `FileNonexistent` as a target for `cp` or `write` to upload a new file.
"""
function file(parent::Directory, name::AbstractString)
    @assert !occursin("/", strip(name, '/'))  name
    path = "$(rstrip(abspath(parent), '/'))/$(lstrip(name, '/'))"  # not joinpath() because on windows it uses \
    @assert !endswith(path, "/") && startswith(path, "/")  path
    entity = API.find_by_path(client(parent), parent.entity, path)
    if isnothing(entity)
        return FileNonexistent(project(parent), parent.storage, path)
    else
        # @assert entity.attributes[:kind] == "folder"
        # @assert entity.attributes[:path] == "/" || entity.attributes[:materialized_path] == path
        return File(project(parent), parent.storage, entity)
    end
end

"""
    joinpath(parent::Directory, name::AbstractString)
    joinpath(parent, names::AbstractString...)

Navigate to a child file or directory by name. The entry must exist — errors otherwise.
Use [`file`](@ref) or [`directory`](@ref) to reference entries that may not exist yet.
"""
function Base.joinpath(a::Union{Directory,Project}, b::Union{Directory,File,DirectoryNonexistent,FileNonexistent})
    pa, pb = abspath(a), abspath(b)
    if startswith(pb, pa)
        return b
    else
        error("Cannot `joinpath()` OSF entries $pa and $pb.")
    end
end

function Base.joinpath(parent::Directory, name::AbstractString)
    @assert !occursin("/", strip(name, '/'))  name
    path = "$(rstrip(abspath(parent), '/'))/$(lstrip(name, '/'))"  # not joinpath() because on windows it uses \
    @assert startswith(path, "/")  path
    entity = API.find_by_path(client(parent), parent.entity, path)
    if isnothing(entity)
        entity = API.find_by_path(client(parent), parent.entity, path * "/")
    end
    isnothing(entity) && error("File/directory $path doesn't exist. Use `OSF.file(...)` or `OSF.directory(...)` to handle nonexistent entries.")
    if entity.attributes[:kind] == "folder"
        @assert entity.attributes[:path] == "/" || entity.attributes[:materialized_path] in (path, path * "/")
        return Directory(project(parent), parent.storage, entity)
    else
        return File(project(parent), parent.storage, entity)
    end
end

Base.joinpath(parent::Project, name::AbstractString) = joinpath(directory(parent, "/"), name)
Base.joinpath(parent::Union{Directory,Project}, names::AbstractString...) = foldl(joinpath, names; init=parent)

"""
    refresh(entry)

Re-fetch a file or directory from the OSF server, returning a fresh object.
Useful after modifications to get updated metadata.
"""
refresh(f::Union{File, FileNonexistent}) = file(directory(f), basename(f))
refresh(d::Union{Directory, DirectoryNonexistent}) = directory(project(d), abspath(d); d.storage)


Base.mkpath(d::Directory) = d
Base.mkpath(d::DirectoryNonexistent) = mkdir(d)
function Base.mkdir(d::DirectoryNonexistent)
    @assert dirname(d.path) * "/" == d.path  d.path
    parent_d = directory(project(d), dirname(dirname(d.path)); d.storage)
    API.create_folder(client(d), parent_d.entity, basename(d))
    return directory(project(d), d.path; d.storage)
end

"""
    rm(entry::Union{File, Directory}; force=false)

Delete a file or directory from OSF. Returns the corresponding `Nonexistent` wrapper.
"""
function Base.rm(d::Directory)
    API.delete(client(d), d.entity)
    return nothing
end

function Base.rm(f::FileNonexistent; force::Bool=false)
    force && return nothing
    throw(OSFError("File doesn't exist in OSF: $(abspath(f))"))
end
function Base.rm(f::File; force::Bool=false)
    API.delete(client(f), f.entity)
    return nothing
end

"""
    cp(local_path::String, osf_file; force=false)
    cp(osf_file, local_path::String; force=false)
    cp(osf_dir::Directory, local_path::String; force=false)

Copy files between local filesystem and OSF. Works in both directions.
Use `force=true` to overwrite existing files. Copying a `Directory` downloads all its contents recursively.
"""
function Base.cp(src::AbstractString, dst::FileNonexistent; force::Bool=false)
    open(io -> write(dst, io), src, "r")
    return dst
end
function Base.cp(src::AbstractString, dst::File; force::Bool=false)
    force || throw(OSFError("Destination file exists in OSF: $(abspath(dst)). Pass `force=true` to overwrite."))
    open(io -> write(dst, io), src, "r")
    return dst
end
Base.cp(src::FileNonexistent, dst::AbstractString; force::Bool=false) = throw(OSFError("File doesn't exist in OSF: $(abspath(src))"))
Base.cp(src::File, dst::AbstractString; force::Bool=false) = let 
    if !force && ispath(dst)
        throw(ArgumentError("'$dst' exists. `force=true` is required to remove '$dst' before copying."))
    end
    Downloads.download(string(url(src)), dst)
end

function Base.cp(src::Directory, dst::AbstractString;force::Bool=false)
    mkpath(dst)
    for f in readdir(src)
        cp(f, joinpath(dst, basename(f)); force)
    end
    return dst
end

"""
    write(f::File, content)
    write(f::FileNonexistent, content)

Upload `content` to OSF. Overwrites the file if it already exists, or creates a new file.
`content` can be any IO-compatible object or byte data.
"""
function upload_payload(content)
    if content isa IO
        payload = read(content)
        return payload, length(payload)
    elseif content isa AbstractString
        return content, ncodeunits(content)
    elseif content isa AbstractVector{UInt8}
        return content, length(content)
    else
        hasmethod(length, Tuple{typeof(content)}) || throw(OSFError("Unsupported write content type: $(typeof(content))"))
        return content, length(content)
    end
end

function Base.write(f::File, content)
    payload, nbytes = upload_payload(content)
    API.upload_file(client(f), f.entity, payload)
    return nbytes
end

function Base.write(f::FileNonexistent, content)
    payload, nbytes = upload_payload(content)
    API.upload_file(client(f), directory(f).entity, basename(f), payload)
    return nbytes
end


"""
    readdir(proj::Project; storage=nothing)
    readdir(dir::Directory)
    readdir(File, dir)
    readdir(Directory, dir)

List contents of a project root or directory. Returns a `Vector` of [`File`](@ref) and [`Directory`](@ref) objects
(not strings — use `basename.()` to get names).
The `storage` keyword selects the storage provider (defaults to `"osfstorage"`).
The type-filtered forms return only files or only directories.
"""
function Base.readdir(proj::Project; storage=nothing)
    storage_e = (@__MODULE__).storage(proj, storage)
    entities = API.relationship_complete(client(proj), storage_e, :files)
    [
        haskey(ent.relationships, :files) ? Directory(proj, storage_e, ent) : File(proj, storage_e, ent)
        for ent in entities
    ]
end

function Base.readdir(dir::Directory)
    entities = API.relationship_complete(client(dir), dir.entity, :files)
    [
        haskey(ent.relationships, :files) ? Directory(project(dir), dir.storage, ent) : File(project(dir), dir.storage, ent)
        for ent in entities
    ]
end

Base.readdir(::Type{Directory}, dir::Union{Project,Directory}; kwargs...) = filter(isdir, readdir(dir; kwargs...))
Base.readdir(::Type{File}, dir::Union{Project,Directory}; kwargs...) = filter(isfile, readdir(dir; kwargs...))


"""
    walkdir(dir::Union{Directory, Project}; topdown=true, onerror=throw)

Recursively walk the directory tree. Yields `(dir, subdirs, files)` tuples where
`dir` is a `Directory` (or `Project`), `subdirs` is a `Vector{Directory}`, and `files` is a `Vector{File}`.
"""
function Base.walkdir(dir::Union{Directory,Project}; topdown=true, onerror=throw)
    function _walkdir(chnl, dir)
        tryf(f, p) =
            try
                f(p)
            catch err
                isa(err, IOError) || rethrow()
                try
                    onerror(err)
                catch err2
                    close(chnl, err2)
                end
                return
            end
        entries = tryf(readdir, dir)
        entries === nothing && return
        dirs = filter(isdir, entries)
        files = filter(!isdir, entries)  # treat everything that isn't a directory as a file; anything aside from File here?
        if topdown
            push!(chnl, (dir, dirs, files))
        end
        for d in dirs
            _walkdir(chnl, d)
        end
        if !topdown
            push!(chnl, (dir, dirs, files))
        end
        nothing
    end
    return Channel{Tuple{Union{Project,Directory},Vector{Directory},Vector{File}}}(chnl -> _walkdir(chnl, dir))
end


"""
    ViewOnlyLink

A view-only access link for a project. Obtain via [`view_only_links`](@ref).
Pass to [`url(file, link)`](@ref) to generate a shareable download URL.
"""
struct ViewOnlyLink
    entity::API.Entity{:view_only_links}
end

"""
    view_only_links(proj::Project)

Get all view-only links for the project. Returns a `Vector{ViewOnlyLink}`.
"""
function view_only_links(proj::Project)
    links = API.relationship(client(proj), proj.entity, :view_only_links)
    return map(ViewOnlyLink, links.data)
end

"""
    FileVersion

A specific version of a file. Obtain via [`versions`](@ref).
Supports `read`, `url`, and comparison via `<` (ordered by revision number).
"""
struct FileVersion
    file::File
    entity::API.Entity{:file_versions}
end

"""
    revision_number(fv::FileVersion)

Get the integer revision number of a file version.
"""
revision_number(f::FileVersion) = parse(Int, f.entity.id)

Base.isless(a::FileVersion, b::FileVersion) = if a.file == b.file
    isless(revision_number(a), revision_number(b))
else
    error("Cannot compare versions of different files: $(abspath(a.file)) vs $(abspath(b.file))")
end

project(x::FileVersion) = project(x.file)

"""
    versions(f::File)

Get all versions of a file. Returns a `Vector{FileVersion}`.
"""
versions(f::File) = [
    FileVersion(f, ent)
    for ent in API.relationship_complete(client(f), f.entity, :versions, etype=:file_versions)
]

"""
    url(file_or_version)
    url(file_or_version, view_only_link::ViewOnlyLink)

Get a download URL for a file or file version.
Without a `ViewOnlyLink`, uses the public download link for public projects,
or automatically looks up the project's view-only link for private projects.
"""
url(f::Union{File,FileVersion}, vo_link::ViewOnlyLink) = API.file_viewonly_url(f.entity, vo_link.entity, :download)
url(f) = project(f).entity.attributes[:public] ?
    f.entity.links[:download] :  # public download link
    url(f, only(view_only_links(project(f))))  # project-specific view-only link

"""
    read(f::Union{File, FileVersion})
    read(f::Union{File, FileVersion}, String)

Download file contents from OSF. Returns bytes by default, or a `String` with the two-argument form.
Also works on [`FileVersion`](@ref) to read a specific version.
"""
Base.read(f::Union{File,FileVersion}) = take!(Downloads.download(string(url(f)), IOBuffer()))
Base.read(f::Union{File,FileVersion}, ::Type{String}) = String(read(f))
