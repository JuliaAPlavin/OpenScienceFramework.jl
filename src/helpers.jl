function file_viewonly_url(file::Entity{:files}, link::Entity{:view_only_links}, ltype::Symbol)
    joinpath(file.links[ltype], "?view_only=$(link.attributes[:key])")
end
