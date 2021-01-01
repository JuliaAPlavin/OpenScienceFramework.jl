using OpenScienceFrameworkClient

osf = OSFClient(token="BiBvoIbBgNHIAE9VDrRlbxAw0h1AahVv4lQlkoixQlPLZPXFgW0BkUTHIarKUSW8nGH8AX")
proj = get_project(osf, "DataCatalogs.jl")
provider = request(osf, "GET", "nodes/$(proj["id"])/files/")["data"] |> only
files = request(osf, "GET", "nodes/$(proj["id"])/files/$(provider["attributes"]["provider"])/")
HTTP.request(
    "PUT",
    provider["links"]["upload"],
    ["Authorization" => "Bearer $(osf.token)"],
    "file content test",
    query=["kind" => "file", "name" => "test.txt"],
    verbose=3
)
