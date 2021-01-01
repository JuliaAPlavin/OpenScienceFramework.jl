import OpenScienceFramework as OSF

token = "BiBvoIbBgNHIAE9VDrRlbxAw0h1AahVv4lQlkoixQlPLZPXFgW0BkUTHIarKUSW8nGH8AX"
@time osf = OSF.Client(; token)
@time user = OSF.get_entity(osf, :users, "me")
@time nodes = OSF.relationship(osf, user, :nodes, filters=["title" => "DataCatalogs.jl"])
proj = only(nodes.data)
@time storages = OSF.relationship(osf, proj, :files)
storage = only(storages.data)
@assert storage.attributes[:name] == "osfstorage"
@time files = OSF.relationship(osf, storage, :files)
@assert OSF.is_complete(files)
file = files.data[1]
dir = files.data[2]

@time versions = OSF.relationship(osf, file, :versions, etype=:file_versions)

@time OSF.find_by_path(osf, storage, "/tmpdir/newname")

@time links = OSF.relationship(osf, proj, :view_only_links)
link = only(links.data)

@time OSF.file_viewonly_url(versions.data[1], link, :download)

# OSF.upload_file(osf, file, "abcdef1")
# OSF.upload_file(osf, dir, "newname", "abcdefxaxa")
