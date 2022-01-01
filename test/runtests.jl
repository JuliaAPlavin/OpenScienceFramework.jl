import OpenScienceFramework as OSF
import Downloads
using Test


project_title = "Test_OSFjl_project"
token = "BiBvoIbBgNHIAE9VDrRlbxAw0h1AahVv4lQlkoixQlPLZPXFgW0BkUTHIarKUSW8nGH8AX"

@testset verbose=true "highlevel" begin
    @testset begin
        osf = OSF.Client(; token)
        proj = OSF.project(osf; user="me", title=project_title)
        @test OSF.project(osf; title=project_title).entity.attributes == proj.entity.attributes

        for d in readdir(OSF.Directory, proj)
            rm(d)
        end

        @test readdir(OSF.Directory, proj) == []
        dir = OSF.directory(proj, "mydir"; storage="osfstorage")
        mkdir(dir)
        @test [basename(d) for d in readdir(OSF.Directory, proj)] == ["mydir"]
        # @test readdir(OSF.File, proj) == []
    end
end

# @testset verbose=true "lowlevel" begin
#     osf = nothing
#     user = nothing
#     proj = nothing
#     vo_link = nothing
#     storage = nothing

#     @testset "init" begin
#         osf = OSF.Client(; token)
#         user = OSF.API.get_entity(osf, :users, "me")
#         @test user.type == "users"
#     end

#     @testset "get project" begin
#         nodes = OSF.API.relationship(osf, user, :nodes, filters=["title" => project_title])
#         proj = if !isempty(nodes.data)
#             only(nodes.data)
#         else
#             create_entity(osf, "nodes", Dict("title" => project_title, "category" => "project"))
#             nodes = OSF.API.relationship(osf, user, :nodes, filters=["title" => project_title])
#             only(nodes.data)
#         end
#         @test proj.attributes[:title] == project_title

#         links = OSF.API.relationship(osf, proj, :view_only_links)
#         vo_link = only(links.data)
#         @test vo_link.type == "view_only_links"
#     end

#     @testset "get storage, remove files" begin
#         storages = OSF.API.relationship(osf, proj, :files)
#         storage = only(storages.data)
#         @test storage.attributes[:name] == "osfstorage"

#         files = OSF.API.relationship_complete(osf, storage, :files)
#         @sync for f in files
#             @async OSF.API.delete(osf, f)
#         end

#         @test isempty(OSF.API.relationship_complete(osf, storage, :files))
#         @test OSF.API.find_by_path(osf, storage, "/test.txt") == nothing
#     end

#     @testset "file" begin
#         OSF.API.upload_file(osf, storage, "test.txt", "test content")
#         files = OSF.API.relationship_complete(osf, storage, :files)
#         @test length(files) == 1
#         @test only(files).attributes[:materialized_path] == "/test.txt"
#         @test OSF.API.find_by_path(osf, storage, "/test.txt").attributes == only(files).attributes
#         @test OSF.API.find_by_path(osf, storage, "/test_1.txt") == nothing

#         file = OSF.API.find_by_path(osf, storage, "/test.txt")
#         versions = OSF.API.relationship_complete(osf, file, :versions, etype=:file_versions)
#         @test length(versions) == 1

#         url = OSF.API.file_viewonly_url(file, vo_link, :download)
#         content = String(take!(Downloads.download(string(url), IOBuffer())))
#         @test content == "test content"

#         url = OSF.API.file_viewonly_url(only(versions), vo_link, :download)
#         content = String(take!(Downloads.download(string(url), IOBuffer())))
#         @test content == "test content"

#         OSF.API.upload_file(osf, file, "updated content")
#         versions = OSF.API.relationship_complete(osf, file, :versions, etype=:file_versions)
#         @test length(versions) == 2

#         url = OSF.API.file_viewonly_url(versions[1], vo_link, :download)
#         content = String(take!(Downloads.download(string(url), IOBuffer())))
#         @test content == "updated content"

#         url = OSF.API.file_viewonly_url(versions[2], vo_link, :download)
#         content = String(take!(Downloads.download(string(url), IOBuffer())))
#         @test content == "test content"
#     end

#     @testset "many files" begin
#         @sync for i in 1:30
#             @async OSF.API.upload_file(osf, storage, "test_$i.txt", "test file #$i")
#         end
#         files = OSF.API.relationship_complete(osf, storage, :files)
#         @test length(files) == 31
#         @test sort([f.attributes[:materialized_path] for f in files]) == sort(["/test.txt"; ["/test_$i.txt" for i in 1:30]])
#         @test OSF.API.find_by_path(osf, storage, "/test.txt").attributes[:materialized_path] == "/test.txt"
#         @test OSF.API.find_by_path(osf, storage, "/test_11.txt").attributes[:materialized_path] == "/test_11.txt"

#         file = OSF.API.find_by_path(osf, storage, "/test_11.txt")
#         versions = OSF.API.relationship_complete(osf, file, :versions, etype=:file_versions)
#         @test length(versions) == 1

#         url = OSF.API.file_viewonly_url(only(versions), vo_link, :download)
#         content = String(take!(Downloads.download(string(url), IOBuffer())))
#         @test content == "test file #11"

#         file = OSF.API.find_by_path(osf, storage, "/test_21.txt")
#         OSF.API.upload_file(osf, file, "updated content 21")
#         versions = OSF.API.relationship_complete(osf, file, :versions, etype=:file_versions)
#         @test length(versions) == 2
#         url = OSF.API.file_viewonly_url(versions[1], vo_link, :download)
#         content = String(take!(Downloads.download(string(url), IOBuffer())))
#         @test content == "updated content 21"
#     end

#     @testset "folders" begin
#         OSF.API.create_folder(osf, storage, "testdir")
#         dir = OSF.API.find_by_path(osf, storage, "/testdir/")
#         @test dir.attributes[:kind] == "folder"
#         @test dir.attributes[:materialized_path] == "/testdir/"

#         @sync for i in 1:20
#             @async OSF.API.upload_file(osf, dir, "test_indir_$i.txt", "test indir #$i")
#         end

#         @test sort(OSF.API.readdir(osf, storage)) == sort(["test.txt"; "testdir"; ["test_$i.txt" for i in 1:30]])
#         @test sort(OSF.API.readdir(osf, dir)) == sort(["test_indir_$i.txt" for i in 1:20])

#         @test OSF.API.find_by_path(osf, storage, "/testdir/test.txt") == nothing
#         @test OSF.API.find_by_path(osf, storage, "/testdir/test_indir_12.txt").attributes[:materialized_path] == "/testdir/test_indir_12.txt"
#     end
# end


import Aqua
import CompatHelperLocal
@testset begin
    CompatHelperLocal.@check()
    Aqua.test_ambiguities(OSF, recursive=false)
    Aqua.test_unbound_args(OSF)
    Aqua.test_undefined_exports(OSF)
    Aqua.test_stale_deps(OSF)
end
