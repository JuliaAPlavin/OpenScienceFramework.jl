module OpenScienceFramework

module API
include("general_api.jl")
include("waterbutler_api.jl")
include("helpers.jl")
end

import Downloads
import .API: Client

struct Project
    client::Client
    entity::API.Entity{:nodes}
end
client(x::Project) = x.client
client(x) = client(project(x))

function project(c::Client; user::String="me", title::String)
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
    path = joinpath(abspath(parent), name)
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

directory(f::FileNonexistent) = directory(project(f), dirname(abspath(f)); f.storage)
directory(f::File) = directory(project(f), dirname(abspath(f)); f.storage)

function file(parent::Directory, name::AbstractString)
    @assert !occursin("/", strip(name, '/'))  name
    path = joinpath(abspath(parent), name)
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

Base.cp(src::AbstractString, dst::FileNonexistent; force::Bool=false) = open(io -> write(dst, io), src, "r")
Base.cp(src::AbstractString, dst::File; force::Bool=false) = (@assert force; open(io -> write(dst, io), src, "r"))
Base.cp(src::FileNonexistent, dst::AbstractString; force::Bool=false) = error("File doesn't exist in OSF: $(abspath(src))")
Base.cp(src::File, dst::AbstractString; force::Bool=false) = let 
    if !force && ispath(dst)
        error("Already exists: $dst")
    end
    Downloads.download(string(url(src)), dst)
end

Base.write(f::File, content) = API.upload_file(client(f), f.entity, content)
Base.write(f::FileNonexistent, content) = API.upload_file(client(f), directory(f).entity, basename(f), content)


function Base.readdir(::Type{Directory}, proj::Project; storage=nothing)
    storage_e = (@__MODULE__).storage(proj, storage)
    entities = API.relationship_complete(client(proj), storage_e, :files)
    [
        Directory(proj, storage_e, ent)
        for ent in entities
        if haskey(ent.relationships, :files)
    ]
end

function Base.readdir(::Type{Directory}, dir::Directory)
    entities = API.relationship_complete(client(dir), dir.entity, :files)
    [
        Directory(project(dir), dir.storage, ent)
        for ent in entities
        if haskey(ent.relationships, :files)
    ]
end

function Base.readdir(::Type{File}, dir::Directory)
    entities = API.relationship_complete(client(dir), dir.entity, :files)
    [
        File(project(dir), dir.storage, ent)
        for ent in entities
        if !haskey(ent.relationships, :files)
    ]
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

project(x::FileVersion) = project(x.file)

versions(f::File) = [
    FileVersion(f, ent)
    for ent in API.relationship_complete(client(f), f.entity, :versions, etype=:file_versions)
]

url(f::Union{File,FileVersion}, vo_link::ViewOnlyLink) = API.file_viewonly_url(f.entity, vo_link.entity, :download)
url(f) = url(f, only(view_only_links(project(f))))

Base.read(f::Union{File,FileVersion}) = take!(Downloads.download(string(url(f)), IOBuffer()))
Base.read(f::Union{File,FileVersion}, ::Type{String}) = String(read(f))

end # module
