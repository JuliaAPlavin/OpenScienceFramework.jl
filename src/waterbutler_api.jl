# Docs: https://waterbutler.readthedocs.io/

function upload_file(osf::Client, file::Entity{:files}, content)
    @assert file.attributes[:kind] == "file"
    r = HTTP.request("PUT", file.links[:upload], headers(osf), content)
end

function upload_file(osf::Client, dir::Entity{:files}, name::String, content)
    @assert dir.attributes[:kind] == "folder"
    r = HTTP.request("PUT", joinpath(dir.links[:upload], "?kind=file&name=$name"), headers(osf), content)
end

const update_file = upload_file



function create_folder(osf::Client, dir::Entity{:files}, name::String)
    @assert dir.attributes[:kind] == "folder"
    r = HTTP.request("PUT", dir.links[:new_folder] * "&name=$name", headers(osf))
end
