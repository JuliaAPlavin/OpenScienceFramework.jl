using OpenScienceFramework
import Downloads
using Test
using Artifacts


project_title = "Test_OSFjl_project"
token = if haskey(ENV, "OSF_TOKEN")
    ENV["OSF_TOKEN"]
else
    read(joinpath(@__DIR__, "OSF_TOKEN"), String)
end

download_as_string(url) = String(take!(Downloads.download(string(url), IOBuffer())))

@testset "artifacts" begin
    toml_file = "Artifacts.toml"
    rm(toml_file; force=true)
    
    osf = OSF.Client(; token)
    proj = OSF.project(osf; title=project_title)
	osf_dir = OSF.directory(proj, "artifacts_dir") |> mkpath
    rm.(readdir(OSF.File, osf_dir))
    OSF.create_upload_artifact("my_artifact"; osf_dir, toml_file) do dir
        write(joinpath(dir, "abc"), "def")
    end
    @test isfile(OSF.file(osf_dir, "my_artifact.tar.gz"))
    let meta = artifact_meta("my_artifact", toml_file)
        @test meta["git-tree-sha1"] == "3278d58d97443073cc3ef9a20bdfcd18ba820558"
        @test meta["lazy"] == true
        @test occursin(r"^https://osf.io/download/\w+/\?revision=1&view_only=\w+$", only(meta["download"])["url"])
    end

    tmpdir = mktempdir()
    write(joinpath(tmpdir, "abc"), "xyz")
    @test_throws Exception OSF.create_upload_artifact(tmpdir, "my_artifact"; osf_dir, toml_file)
    OSF.create_upload_artifact(tmpdir, "my_artifact"; osf_dir, toml_file, update_existing=true)
    @test OSF.file(osf_dir, "my_artifact.tar.gz") |> OSF.versions |> length == 2
    let meta = artifact_meta("my_artifact", toml_file)
        @test meta["git-tree-sha1"] == "7542f7396ca040373e65f868767cc4dfdf3708db"
        @test occursin(r"^https://osf.io/download/\w+/\?revision=2&view_only=\w+$", only(meta["download"])["url"])
    end

    rm(toml_file; force=true)
end

@testset verbose=true "highlevel" begin
    osf = OSF.Client(; token)
    proj = OSF.project(osf; title=project_title)
    @test startswith(sprint(show, proj), "OSF Project `Test_OSFjl_project`, id")

    @sync for d in readdir(proj)
        @async rm(d)
    end

    @test readdir(OSF.Directory, proj) == []
    @test readdir(proj) == []
    dir = OSF.directory(proj, "mydir")
    @test sprint(show, dir) == "OSF Directory `/mydir/` (doesn't exist)"
    @test !isdir(dir)
    dir = mkdir(dir)
    dir_r = OSF.refresh(dir)
    @test sprint(show, dir) == "OSF Directory `/mydir/`"
    @test !islink(dir)
    @test isdir(dir)
    @test isdir(dir_r)
    @test abspath(dir) == abspath(dir_r)
    @test [basename(d) for d in readdir(OSF.Directory, proj)] == ["mydir"]
    
    @test readdir(OSF.Directory, dir) == []
    subdir = OSF.directory(dir, "mysubdir")
    @test !isdir(subdir)
    subdir = mkdir(subdir)
    @test isdir(subdir)
    @test isdir(OSF.directory(dir, "mysubdir"))
    @test joinpath(dir, subdir) == subdir
    @test_throws "Cannot" joinpath(subdir, dir)
    @test [basename(d) for d in readdir(OSF.Directory, dir)] == ["mysubdir"]
    @test basename.(readdir(dir)) == ["mysubdir"]

    @test [basename(d) for d in readdir(OSF.File, dir)] == []
    file = OSF.file(dir, "myfile.txt")
    @test sprint(show, file) == "OSF File `/mydir/myfile.txt` (doesn't exist)"
    @test !isfile(file)
    @test joinpath(dir, file) == file
    @test_throws MethodError joinpath(file, dir)

    write(file, "my file content")
    file = OSF.refresh(file)
    @test sprint(show, file) == "OSF File `/mydir/myfile.txt` (15 bytes)"
    @test joinpath(dir, file) == file
    @test [basename(d) for d in readdir(OSF.File, dir)] == ["myfile.txt"]
    @test basename.(readdir(dir)) == ["mysubdir", "myfile.txt"]
    @test isfile(file)
    @test !islink(file)
    @test filesize(file) == length("my file content")
    @test read(file, String) == "my file content"
    @test length(OSF.versions(file)) == 1
    url_file = OSF.url(file)
    url_ver1 = OSF.url(OSF.versions(file) |> only)
    @test download_as_string(url_ver1) == "my file content"

    write(file, b"some new content")
    @test read(file, String) == "some new content"
    @test read(file) == b"some new content"
    @test length(OSF.versions(file)) == 2
    @test read.(OSF.versions(file), String) == ["some new content", "my file content"]
    url_ver2 = OSF.url(OSF.versions(file) |> maximum)
    @test download_as_string(url_file) == "some new content"
    @test download_as_string(url_ver1) == "my file content"
    @test download_as_string(url_ver2) == "some new content"

    let fname = tempname()
        write(fname, "content from file")
        open(fname) do io
            write(file, io)  # method specific to OSF.File - not in Base
        end
    end
    @test read(file, String) == "content from file"
    @test length(OSF.versions(file)) == 3

    mktemp() do path, _
        write(path, "more from file")
        @test_throws Exception cp(path, file)
        cp(path, file; force=true)
    end
    @test read(file, String) == "more from file"
    @test length(OSF.versions(file)) == 4
    url_ver4 = OSF.url(OSF.versions(file) |> maximum)
    @test download_as_string(url_ver1) == "my file content"
    @test download_as_string(url_ver2) == "some new content"
    @test download_as_string(url_ver4) == "more from file"
    @test download_as_string(url_file) == "more from file"

    let fname = tempname()
        cp(file, fname)
        file = OSF.refresh(file)
        @test_throws Exception cp(file, fname)
        cp(file, fname; force=true)
        @test read(fname, String) == "more from file"
    end

    map(OSF.url, OSF.versions(file))

    rm(file)
    @test !isfile(OSF.refresh(file))
end

@testset verbose=true "lowlevel" begin
    osf = nothing
    user = nothing
    proj = nothing
    vo_link = nothing
    storage = nothing

    @testset "init" begin
        osf = OSF.Client(; token)
        user = OSF.API.get_entity(osf, :users, "me")
        @test user.type == "users"
    end

    @testset "get project" begin
        nodes = OSF.API.relationship(osf, user, :nodes, filters=["title" => project_title])
        proj = if !isempty(nodes.data)
            only(nodes.data)
        else
            create_entity(osf, "nodes", Dict("title" => project_title, "category" => "project"))
            nodes = OSF.API.relationship(osf, user, :nodes, filters=["title" => project_title])
            only(nodes.data)
        end
        @test proj.attributes[:title] == project_title

        links = OSF.API.relationship(osf, proj, :view_only_links)
        vo_link = only(links.data)
        @test vo_link.type == "view_only_links"
    end

    @testset "get storage, remove files" begin
        storages = OSF.API.relationship(osf, proj, :files)
        storage = only(storages.data)
        @test storage.attributes[:name] == "osfstorage"

        files = OSF.API.relationship_complete(osf, storage, :files)
        @sync for f in files
            @async OSF.API.delete(osf, f)
        end

        @test isempty(OSF.API.relationship_complete(osf, storage, :files))
        @test OSF.API.find_by_path(osf, storage, "/test.txt") == nothing
    end

    @testset "file" begin
        OSF.API.upload_file(osf, storage, "test.txt", "test content")
        files = OSF.API.relationship_complete(osf, storage, :files)
        @test length(files) == 1
        @test only(files).attributes[:materialized_path] == "/test.txt"
        @test OSF.API.find_by_path(osf, storage, "/test.txt").attributes == only(files).attributes
        @test OSF.API.find_by_path(osf, storage, "/test_1.txt") == nothing

        file = OSF.API.find_by_path(osf, storage, "/test.txt")
        versions = OSF.API.relationship_complete(osf, file, :versions, etype=:file_versions)
        @test length(versions) == 1

        url_file_1 = OSF.API.file_viewonly_url(file, vo_link, :download)
        @test download_as_string(url_file_1) == "test content"

        url_ver_1 = OSF.API.file_viewonly_url(only(versions), vo_link, :download)
        @test download_as_string(url_ver_1) == "test content"

        OSF.API.upload_file(osf, file, "updated content")
        versions = OSF.API.relationship_complete(osf, file, :versions, etype=:file_versions)
        @test length(versions) == 2

        url_ver_2 = OSF.API.file_viewonly_url(versions[1], vo_link, :download)
        @test download_as_string(url_ver_2) == "updated content"
        @test download_as_string(url_file_1) == "updated content"

        url_ver_1_after2 = OSF.API.file_viewonly_url(versions[2], vo_link, :download)
        @test download_as_string(url_ver_1_after2) == "test content"
        @test download_as_string(url_ver_1) == "test content"
    end

    @testset "many files" begin
        @sync for i in 1:30
            @async OSF.API.upload_file(osf, storage, "test_$i.txt", "test file #$i")
        end
        files = OSF.API.relationship_complete(osf, storage, :files)
        @test length(files) == 31
        @test sort([f.attributes[:materialized_path] for f in files]) == sort(["/test.txt"; ["/test_$i.txt" for i in 1:30]])
        @test OSF.API.find_by_path(osf, storage, "/test.txt").attributes[:materialized_path] == "/test.txt"
        @test OSF.API.find_by_path(osf, storage, "/test_11.txt").attributes[:materialized_path] == "/test_11.txt"

        file = OSF.API.find_by_path(osf, storage, "/test_11.txt")
        versions = OSF.API.relationship_complete(osf, file, :versions, etype=:file_versions)
        @test length(versions) == 1

        url = OSF.API.file_viewonly_url(only(versions), vo_link, :download)
        content = String(take!(Downloads.download(string(url), IOBuffer())))
        @test content == "test file #11"

        file = OSF.API.find_by_path(osf, storage, "/test_21.txt")
        OSF.API.upload_file(osf, file, "updated content 21")
        versions = OSF.API.relationship_complete(osf, file, :versions, etype=:file_versions)
        @test length(versions) == 2
        url = OSF.API.file_viewonly_url(versions[1], vo_link, :download)
        content = String(take!(Downloads.download(string(url), IOBuffer())))
        @test content == "updated content 21"
    end

    @testset "folders" begin
        OSF.API.create_folder(osf, storage, "testdir")
        dir = OSF.API.find_by_path(osf, storage, "/testdir/")
        @test dir.attributes[:kind] == "folder"
        @test dir.attributes[:materialized_path] == "/testdir/"

        @sync for i in 1:20
            @async OSF.API.upload_file(osf, dir, "test_indir_$i.txt", "test indir #$i")
        end

        @test sort(OSF.API.readdir(osf, storage)) == sort(["test.txt"; "testdir"; ["test_$i.txt" for i in 1:30]])
        @test sort(OSF.API.readdir(osf, dir)) == sort(["test_indir_$i.txt" for i in 1:20])

        @test OSF.API.find_by_path(osf, storage, "/testdir/test.txt") == nothing
        @test OSF.API.find_by_path(osf, storage, "/testdir/test_indir_12.txt").attributes[:materialized_path] == "/testdir/test_indir_12.txt"
    end
end


import Aqua
import CompatHelperLocal
@testset begin
    CompatHelperLocal.@check()
    Aqua.test_all(OSF)
end
