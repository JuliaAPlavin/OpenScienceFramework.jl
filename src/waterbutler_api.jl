# Docs: https://waterbutler.readthedocs.io/

function with_query_params(url::AbstractString, params::Pair...)
    uri = parse(HTTP.URI, url)
    query = Dict(string(k) => string(v) for (k, v) in HTTP.queryparams(uri))
    for (k, v) in params
        query[string(k)] = string(v)
    end
    return string(HTTP.URI(uri; query))
end

function upload_file(osf::Client, file::Entity{:files}, content)
    @assert file.attributes[:kind] == "file"
    r = HTTP.request("PUT", file.links[:upload], headers(osf), content)
end

function upload_file(osf::Client, dir::Entity{:files}, name::String, content)
    @assert dir.attributes[:kind] == "folder"
    upload_url = with_query_params(dir.links[:upload], "kind" => "file", "name" => name)
    r = HTTP.request("PUT", upload_url, headers(osf), content)
end



function create_folder(osf::Client, dir::Entity{:files}, name::String)
    @assert dir.attributes[:kind] == "folder"
    folder_url = with_query_params(dir.links[:new_folder], "name" => name)
    r = HTTP.request("PUT", folder_url, headers(osf))
end
