module OpenScienceFrameworkClient

import HTTP
import JSON
import Parameters: @with_kw


@with_kw struct Client
    api_version::String = "2"
    token::String
end

headers(osf::Client) = ["Authorization" => "Bearer $(osf.token)"]

function request(osf::Client, method::String, resource::String)
    r = HTTP.request(
        method,
        joinpath("https://api.osf.io", "v$(osf.api_version)", resource),
        headers(osf),
    )
    JSON.parse(String(r.body))
end

function get_project(osf::Client, name::String)
    r = request(osf, "GET", "nodes/?filter[title]=$name")
    proj = only(r["data"])
    @assert proj["attributes"]["title"] == name
    r = request(osf, "GET", "nodes/$(proj["id"])/files/")
    provider = only(r["data"])
    @assert provider["attributes"]["provider"] == "osfstorage"
    proj
end

end # module
