module OpenScienceFrameworkClient

import HTTP
import JSON
import Parameters: @with_kw

export OSFClient, get_project


@with_kw struct OSFClient
    api_version::String = "2"
    token::String
end

headers(osf::OSFClient) = ["Authorization" => "Bearer $(osf.token)"]

function request(osf::OSFClient, method::String, resource::String)
    r = HTTP.request(
        method,
        joinpath("https://api.osf.io", "v$(osf.api_version)", resource),
        headers(osf),
    )
    JSON.parse(String(r.body))
end

function get_project(osf::OSFClient, name::String)
    r = request(osf, "GET", "nodes/?filter[title]=$name")
    proj = only(r["data"])
    @assert node["attributes"]["title"] == name
    r = request(osf, "GET", "nodes/$(proj["id"])/files/")
    provider = only(r["data"])
    @assert r["attributes"]["provider"] == "osfstorage"
    proj
end

end # module
