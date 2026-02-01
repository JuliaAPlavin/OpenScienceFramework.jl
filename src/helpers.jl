function file_viewonly_url(file::Union{Entity{:files}, Entity{:file_versions}}, key::String, ltype::Symbol)
    uri = parse(HTTP.URI, file.links[ltype])
    query = merge(HTTP.queryparams(uri), Dict("view_only" => key))
    return HTTP.URI(uri; query)
end

file_viewonly_url(file::Union{Entity{:files}, Entity{:file_versions}}, link::Entity{:view_only_links}, ltype::Symbol) =
    file_viewonly_url(file, link.attributes[:key], ltype)

function find_by_path(osf::Client, root::Entity{:files}, path::String)
    if root.attributes[:path] == "/"
        @assert root.attributes[:name] == "osfstorage"
        path == "/" && return root
    else
        root.attributes[:materialized_path] == path && return root
        startswith(path, root.attributes[:materialized_path]) || return nothing
    end
    root.attributes[:kind] == "file" && return nothing
    files = relationship_complete(osf, root, :files)
    found = map(files) do file
        find_by_path(osf, file, path)
    end
    filter!(!isnothing, found)
    isempty(found) ? nothing : only(found)
end

function relationship_complete(osf::Client, entity::Entity, rel::Symbol; kwargs...)
    es = relationship(osf, entity, rel; kwargs...)
    entities = es.data
    while has_next(es)
        es = get_next(osf, es)
        append!(entities, es.data)
    end
    unique!(e -> e.id, entities)
    return entities
end

readdir(osf, dir::Entity{:files}) = [f.attributes[:name] for f in relationship_complete(osf, dir, :files)]
readtree(osf, dir::Entity{:files}) = [
    v.attributes[:materialized_path] => v
    for f in relationship_complete(osf, dir, :files)
    for (_, v) in (haskey(f.relationships, :files) ? readtree(osf, f) : [(nothing, f)])
]
