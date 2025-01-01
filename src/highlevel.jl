struct Project
    client::API.Client
    entity::API.Entity{:nodes}
end
client(x::Project) = x.client
client(x) = client(project(x))

function project(c::API.Client; user::String="me", title::String)
    user_e = API.get_entity(c, :users, user)
    projs = API.relationship(c, user_e, :nodes, filters=["title" => title]).data
    proj_e = only(projs)
    @assert proj_e.attributes[:title] == title
    Project(c, proj_e)
end

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
Base.joinpath(a::Union{Directory,File}) = a
function Base.joinpath(a::Directory, b::Union{Directory,File,DirectoryNonexistent,FileNonexistent})
    pa, pb = abspath(a), abspath(b)
    if startswith(pb, pa)
        return b
    else
        error("Cannot `joinpath()` OSF entries $pa and $pb.")
    end
end


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

function Base.joinpath(parent::Directory, name::AbstractString)
    @assert !occursin("/", strip(name, '/'))  name
    path = "$(rstrip(abspath(parent), '/'))/$(lstrip(name, '/'))"  # not joinpath() because on windows it uses \
    @assert startswith(path, "/")  path
    entity = API.find_by_path(client(parent), parent.entity, path)
    isnothing(entity) && error("File/directory $path doesn't exist. Use `OSF.file(...)` or `OSF.directory(...)` to handle nonexistent entries.")
    if entity.attributes[:kind] == "folder"
        @assert entity.attributes[:path] == "/" || entity.attributes[:materialized_path] == path
        return Directory(project(parent), parent.storage, entity)
    else
        return File(project(parent), parent.storage, entity)
    end
end

Base.joinpath(parent::Union{Directory,Project}, names::AbstractString...) = foldl(joinpath, names; init=parent)

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

function Base.rm(d::Directory)
    API.delete(client(d), d.entity)
    return DirectoryNonexistent(project(d), d.storage, abspath(d))
end

Base.rm(f::FileNonexistent; force::Bool=false) = @assert force
function Base.rm(f::File; force::Bool=false)
    API.delete(client(f), f.entity)
    return FileNonexistent(project(f), f.storage, abspath(f))
end

Base.cp(src::AbstractString, dst::FileNonexistent; force::Bool=false) = open(io -> write(dst, io), src, "r")
Base.cp(src::AbstractString, dst::File; force::Bool=false) = (@assert force; open(io -> write(dst, io), src, "r"))
Base.cp(src::FileNonexistent, dst::AbstractString; force::Bool=false) = error("File doesn't exist in OSF: $(abspath(src))")
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
end

Base.write(f::File, content) = API.upload_file(client(f), f.entity, content)
Base.write(f::FileNonexistent, content) = API.upload_file(client(f), directory(f).entity, basename(f), content)


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

Base.readdir(::Type{Directory}, dir::Union{Project,Directory}; kwargs...) = filter(isdir, readdir(dir); kwargs...)
Base.readdir(::Type{File}, dir::Union{Project,Directory}; kwargs...) = filter(isfile, readdir(dir); kwargs...)


# copied almost verbatim from Julia Base
# just the types are changed from String
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


struct ViewOnlyLink
    entity::API.Entity{:view_only_links}
end

function view_only_links(proj::Project)
    links = API.relationship(client(proj), proj.entity, :view_only_links)
    return map(ViewOnlyLink, links.data)
end

struct FileVersion
    file::File
    entity::API.Entity{:file_versions}
end

revision_number(f::FileVersion) = parse(Int, f.entity.id)

Base.isless(a::FileVersion, b::FileVersion) = if a.file == b.file
    isless(revision_number(a), revision_number(b))
else
    error("Cannot compare versions of different files: $(abspath(a.file)) vs $(abspath(b.file))")
end

project(x::FileVersion) = project(x.file)

versions(f::File) = [
    FileVersion(f, ent)
    for ent in API.relationship_complete(client(f), f.entity, :versions, etype=:file_versions)
]

url(f::Union{File,FileVersion}, vo_link::ViewOnlyLink) = API.file_viewonly_url(f.entity, vo_link.entity, :download)
url(f) = url(f, only(view_only_links(project(f))))

Base.read(f::Union{File,FileVersion}) = take!(Downloads.download(string(url(f)), IOBuffer()))
Base.read(f::Union{File,FileVersion}, ::Type{String}) = String(read(f))
