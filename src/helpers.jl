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
    files = relationship_complete(osf, root, :files; sort="name")
    found = map(files) do file
        find_by_path(osf, file, path)
    end
    filter!(!isnothing, found)
    isempty(found) ? nothing : only(found)
end

# Pagination is only deterministic when sorted by a key unique within the listing:
# OSF sorts in SQL per page request, returning ties in arbitrary varying order,
# which duplicates+skips entries across pages (issue #8). For files, `name` is such a key.
function relationship_complete(osf::Client, entity::Entity, rel::Symbol; kwargs...)
    es = relationship(osf, entity, rel; kwargs...)
    entities = es.data
    total = es.links["meta"]["total"]
    while has_next(es)
        es = get_next(osf, es)
        es.links["meta"]["total"] == total ||
            throw(OSFError("Inconsistent pagination of `$rel`: total changed from $total to $(es.links["meta"]["total"]) mid-listing, retry"))
        append!(entities, es.data)
    end
    n_unique = length(unique(e.id for e in entities))
    n_unique == length(entities) == total ||
        throw(OSFError("Incomplete listing of `$rel`: got $(length(entities)) entries ($n_unique unique), server reports $total"))
    return entities
end

readdir(osf, dir::Entity{:files}) = [f.attributes[:name] for f in relationship_complete(osf, dir, :files; sort="name")]
readtree(osf, dir::Entity{:files}) = [
    v.attributes[:materialized_path] => v
    for f in relationship_complete(osf, dir, :files; sort="name")
    for (_, v) in (haskey(f.relationships, :files) ? readtree(osf, f) : [(nothing, f)])
]
