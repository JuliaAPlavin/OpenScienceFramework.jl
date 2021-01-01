import OpenScienceFrameworkClient as OSF

token = "BiBvoIbBgNHIAE9VDrRlbxAw0h1AahVv4lQlkoixQlPLZPXFgW0BkUTHIarKUSW8nGH8AX"
osf = OSF.Client(; token)
proj = OSF.get_project(osf, "DataCatalogs.jl")
provider = OSF.request(osf, "GET", "nodes/$(proj["id"])/files/")["data"] |> only
files = OSF.request(osf, "GET", "nodes/$(proj["id"])/files/$(provider["attributes"]["provider"])/")
HTTP.request(
    "PUT",
    provider["links"]["upload"],
    ["Authorization" => "Bearer $(osf.token)"],
    "file content test",
    query=["kind" => "file", "name" => "test.txt"],
    verbose=3
)
