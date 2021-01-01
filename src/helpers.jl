function file_viewonly_url(file::Entity{:files}, link::Entity{:view_only_links}, ltype::Symbol)
    joinpath(file.links[ltype], "?view_only=$(link.attributes[:key])")
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
