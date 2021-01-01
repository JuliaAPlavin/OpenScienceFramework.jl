import OpenScienceFrameworkClient as OSF

token = "BiBvoIbBgNHIAE9VDrRlbxAw0h1AahVv4lQlkoixQlPLZPXFgW0BkUTHIarKUSW8nGH8AX"
osf = OSF.Client(; token)
user = OSF.get_entity(osf, :users, "me")
nodes = OSF.relationship(osf, user, :nodes, filters=["title" => "DataCatalogs.jl"])
proj = only(nodes.data)
storages = OSF.relationship(osf, proj, :files)
storage = only(storages.data)
@assert storage.attributes[:name] == "osfstorage"
files = OSF.relationship(osf, storage, :files)
@assert OSF.is_complete(files)
file = files.data[1]

links = OSF.relationship(osf, proj, :view_only_links)
link = only(links.data)

OSF.file_viewonly_url(file, link, :html)
