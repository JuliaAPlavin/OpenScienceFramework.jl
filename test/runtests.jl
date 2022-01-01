import OpenScienceFramework as OSF
import Downloads
using Test


project_title = "Test_OSFjl_project"
token = "BiBvoIbBgNHIAE9VDrRlbxAw0h1AahVv4lQlkoixQlPLZPXFgW0BkUTHIarKUSW8nGH8AX"

@testset "init" begin
    global osf, user
    osf = OSF.Client(; token)
    user = OSF.get_entity(osf, :users, "me")
    @test user.type == "users"
end

@testset "get project" begin
    global proj, vo_link
    nodes = OSF.relationship(osf, user, :nodes, filters=["title" => project_title])
    proj = if !isempty(nodes.data)
        only(nodes.data)
    else
        create_entity(osf, "nodes", Dict("title" => project_title, "category" => "project"))
        nodes = OSF.relationship(osf, user, :nodes, filters=["title" => project_title])
        only(nodes.data)
    end
    @test proj.attributes[:title] == project_title

    links = OSF.relationship(osf, proj, :view_only_links)
    vo_link = only(links.data)
    @test vo_link.type == "view_only_links"
end

@testset "get storage, remove files" begin
    global storage
    storages = OSF.relationship(osf, proj, :files)
    storage = only(storages.data)
    @test storage.attributes[:name] == "osfstorage"

    files = OSF.relationship_complete(osf, storage, :files)
    @sync for f in files
        @async OSF.delete(osf, f)
    end

    @test isempty(OSF.relationship_complete(osf, storage, :files))
    @test OSF.find_by_path(osf, storage, "/test.txt") == nothing
end

@testset "file" begin
    OSF.upload_file(osf, storage, "test.txt", "test content")
    files = OSF.relationship_complete(osf, storage, :files)
    @test length(files) == 1
    @test only(files).attributes[:materialized_path] == "/test.txt"
    @test OSF.find_by_path(osf, storage, "/test.txt").attributes == only(files).attributes
    @test OSF.find_by_path(osf, storage, "/test_1.txt") == nothing

    file = OSF.find_by_path(osf, storage, "/test.txt")
    versions = OSF.relationship_complete(osf, file, :versions, etype=:file_versions)
    @test length(versions) == 1

    url = OSF.file_viewonly_url(file, vo_link, :download)
    content = String(take!(Downloads.download(string(url), IOBuffer())))
    @test content == "test content"

    url = OSF.file_viewonly_url(only(versions), vo_link, :download)
    content = String(take!(Downloads.download(string(url), IOBuffer())))
    @test content == "test content"

    OSF.upload_file(osf, file, "updated content")
    versions = OSF.relationship_complete(osf, file, :versions, etype=:file_versions)
    @test length(versions) == 2

    url = OSF.file_viewonly_url(versions[1], vo_link, :download)
    content = String(take!(Downloads.download(string(url), IOBuffer())))
    @test content == "updated content"

    url = OSF.file_viewonly_url(versions[2], vo_link, :download)
    content = String(take!(Downloads.download(string(url), IOBuffer())))
    @test content == "test content"
end

@testset "many files" begin
    @sync for i in 1:30
        @async OSF.upload_file(osf, storage, "test_$i.txt", "test file #$i")
    end
    files = OSF.relationship_complete(osf, storage, :files)
    @test length(files) == 31
    @test sort([f.attributes[:materialized_path] for f in files]) == sort(["/test.txt"; ["/test_$i.txt" for i in 1:30]])
    @test OSF.find_by_path(osf, storage, "/test.txt").attributes[:materialized_path] == "/test.txt"
    @test OSF.find_by_path(osf, storage, "/test_11.txt").attributes[:materialized_path] == "/test_11.txt"

    file = OSF.find_by_path(osf, storage, "/test_11.txt")
    versions = OSF.relationship_complete(osf, file, :versions, etype=:file_versions)
    @test length(versions) == 1

    url = OSF.file_viewonly_url(only(versions), vo_link, :download)
    content = String(take!(Downloads.download(string(url), IOBuffer())))
    @test content == "test file #11"

    file = OSF.find_by_path(osf, storage, "/test_21.txt")
    OSF.upload_file(osf, file, "updated content 21")
    versions = OSF.relationship_complete(osf, file, :versions, etype=:file_versions)
    @test length(versions) == 2
    url = OSF.file_viewonly_url(versions[1], vo_link, :download)
    content = String(take!(Downloads.download(string(url), IOBuffer())))
    @test content == "updated content 21"
end

@testset "folders" begin
    
end
