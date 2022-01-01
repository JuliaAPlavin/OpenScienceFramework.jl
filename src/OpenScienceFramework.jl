module OpenScienceFramework

module API
include("general_api.jl")
include("waterbutler_api.jl")
include("helpers.jl")
end

import .API: Client

struct Project
    client::Client
    entity::API.Entity{:nodes}
end
client(x::Project) = x.client

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

client(x::Directory) = client(x.project)
Base.isdir(::Directory) = true
Base.isfile(::Directory) = false
Base.basename(d::Directory) = d.entity.attributes[:name]
Base.abspath(d::Directory) = d.entity.attributes[:path] == "/" ? "/" : d.entity.attributes[:materialized_path]

struct DirectoryNonexistent
    project::Project
    storage::API.Entity{:files}
    path::String
end

client(x::DirectoryNonexistent) = client(x.project)
Base.isdir(::DirectoryNonexistent) = false
Base.isfile(::DirectoryNonexistent) = false
Base.basename(d::DirectoryNonexistent) = basename(dirname(d.path))
Base.abspath(d::DirectoryNonexistent) = d.path


struct File
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

function Base.mkdir(d::DirectoryNonexistent)
    @assert dirname(d.path) * "/" == d.path  d.path
    parent_d = directory(d.project, dirname(dirname(d.path)); d.storage)
    API.create_folder(client(d), parent_d.entity, basename(d))
    return directory(d.project, d.path; d.storage)
end

function Base.rm(d::Directory)
    API.delete(client(d), d.entity)
    return DirectoryNonexistent(d.project, d.storage, abspath(d))
end

function Base.readdir(::Type{Directory}, proj::Project; storage=nothing)
    storage_e = (@__MODULE__).storage(proj, storage)
    entities = API.relationship_complete(client(proj), storage_e, :files)
    [
        Directory(proj, storage_e, ent)
        for ent in entities
        if haskey(ent.relationships, :files)
    ]
end

end # module
