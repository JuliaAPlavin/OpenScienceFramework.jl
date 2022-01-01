function file_viewonly_url(file::Union{Entity{:files}, Entity{:file_versions}}, link::Entity{:view_only_links}, ltype::Symbol)
    uri = parse(HTTP.URI, file.links[ltype])
    query = merge(HTTP.queryparams(uri), Dict("view_only" => link.attributes[:key]))
    return HTTP.URI(uri; query)
end

function find_by_path(osf::Client, root::Entity{:files}, path::String)
    if root.attributes[:path] == "/"
        @assert root.attributes[:name] == "osfstorage"
        path == "/" && return root
    else
        root.attributes[:materialized_path] == path && return root
    end
    root.attributes[:kind] == "file" && return nothing
    files = relationship(osf, root, :files)
    found = map(files.data) do file
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
    return entities
end