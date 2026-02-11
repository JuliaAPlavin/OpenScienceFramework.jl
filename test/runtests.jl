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

const test_run_id = string(time_ns())
test_name(prefix::AbstractString) = "$(prefix)_$(test_run_id)"

function eventually(f::Function; timeout=30.0, interval=0.5)
    deadline = time() + timeout
    last_error = nothing
    while true
        try
            return f()
        catch err
            last_error = err
            time() >= deadline && rethrow(last_error)
            sleep(interval)
        end
    end
end

function eventually_true(f::Function; timeout=30.0, interval=0.5)
    deadline = time() + timeout
    last_error = nothing
    last_result = nothing
    while true
        try
            last_result = f()
            last_result === true && return true
        catch err
            last_error = err
        end
        if time() >= deadline
            isnothing(last_error) || throw(last_error)
            error("Condition wasn't met before timeout; last result: $(repr(last_result))")
        end
        sleep(interval)
    end
end

download_as_string(url) = eventually() do
    String(take!(Downloads.download(string(url), IOBuffer())))
end

@testset "artifacts" begin
    toml_file = "Artifacts.toml"
    rm(toml_file; force=true)
    
    osf = OSF.Client(; token)
    proj = OSF.project(osf; title=project_title)
    artifact_name = test_name("my_artifact")
    tar_name = "$artifact_name.tar.gz"
    osf_dir = OSF.directory(proj, test_name("artifacts_dir")) |> mkpath
    rm.(readdir(OSF.File, osf_dir))
    OSF.create_upload_artifact(artifact_name; osf_dir, toml_file) do dir
        write(joinpath(dir, "abc"), "def")
    end
    @test isfile(OSF.file(osf_dir, tar_name))
    let meta = artifact_meta(artifact_name, toml_file)
        @test meta["git-tree-sha1"] == "3278d58d97443073cc3ef9a20bdfcd18ba820558"
        @test meta["lazy"] == true
        @test occursin(r"^https://osf.io/download/\w+/\?revision=1&view_only=\w+$", only(meta["download"])["url"])
    end

    tmpdir = mktempdir()
    write(joinpath(tmpdir, "abc"), "xyz")
    @test_throws Exception OSF.create_upload_artifact(tmpdir, artifact_name; osf_dir, toml_file)
    OSF.create_upload_artifact(tmpdir, artifact_name; osf_dir, toml_file, update_existing=true)
    @test OSF.file(osf_dir, tar_name) |> OSF.versions |> length == 2
    let meta = artifact_meta(artifact_name, toml_file)
        @test meta["git-tree-sha1"] == "7542f7396ca040373e65f868767cc4dfdf3708db"
        @test occursin(r"^https://osf.io/download/\w+/\?revision=2&view_only=\w+$", only(meta["download"])["url"])
    end

    rm(toml_file; force=true)
end

@testset verbose=true "highlevel - anonymous" begin
    proj = OSF.project(OSF.Client(), "hk9g4")::OSF.Project

    d = readdir(proj)
    @test length(d) == 4
    @test typeof(d[1]) == OSF.Directory && typeof(d[4]) == OSF.Directory
    @test typeof(d[2]) == OSF.File && typeof(d[3]) == OSF.File
    @test abspath.(d) == ["/folderB/", "/photoB.jpg", "/folder.txt", "/folderA/"]

    @test sort(abspath.(readdir(OSF.Directory, proj; storage="osfstorage"))) == ["/folderA/", "/folderB/"]
    @test read(joinpath(proj, "folder.txt"), String) == "this is folder"
    @test read(joinpath(proj, "folderA", "folderA1", "folderA1.txt"), String) == "this is folderA1"
    
    wd = walkdir(proj) |> collect
    @test map(x -> basename(x[1]), wd) == ["", "folderB", "folderA", "folderA2", "folderA1"]
    @test map(x -> map(basename, x[2]), wd) == [["folderB", "folderA"], [], ["folderA2", "folderA1"], [], []]
    @test map(x -> map(basename, x[3]), wd) == [["photoB.jpg", "folder.txt"], ["folderB.txt"], ["photoA.jpg", "folderA.txt"], ["folderA2.txt"], ["folderA1.txt"]]

    @test read(joinpath(OSF.directory(proj, "/"), "folder.txt"), String) == "this is folder"
    @test read(wd[4][3][1], String) == "this is folderA2"

    tmp = mktempdir()
    eventually(() -> (cp(d[1], joinpath(tmp, basename(d[1]))); true))
    @test isdir(joinpath(tmp, basename(d[1])))
    @test_throws "exists" cp(d[1], joinpath(tmp, basename(d[1])))
    eventually(() -> (cp(d[1], joinpath(tmp, basename(d[1])); force=true); true))

    # test downloading a whole folder with subfolders
    eventually(() -> (cp(d[4], joinpath(tmp, basename(d[4])); force=true); true))
    local_d4 = collect(walkdir(joinpath(tmp, basename(d[4]))))
    remote_d4 = collect(walkdir(d[4]))

    @test length(local_d4) == length(remote_d4)
    @test map(x -> basename(x[1]), local_d4) |> sort == map(x -> basename(x[1]), local_d4) |> sort
    @test map(x -> map(basename, x[2]), local_d4) .|> sort |> sort == map(x -> map(basename, x[2]), local_d4) .|> sort |> sort
    @test map(x -> map(basename, x[3]), local_d4) .|> sort |> sort == map(x -> map(basename, x[3]), local_d4) .|> sort |> sort
    @test read(joinpath(local_d4[2][1], local_d4[2][3][1]), String) == "this is folderA1"
end

@testset verbose=true "highlevel - authenticated" begin
    osf = OSF.Client(; token)
    proj = OSF.project(osf; title=project_title)
    @test startswith(sprint(show, proj), "OSF Project `Test_OSFjl_project`, id")

    suite_root = OSF.directory(proj, test_name("highlevel")) |> mkpath
    suite_root_name = basename(suite_root)
    @test isdir(suite_root)

    dir = OSF.directory(suite_root, "mydir")
    @test sprint(show, dir) == "OSF Directory `$(abspath(dir))` (doesn't exist)"
    @test !isdir(dir)
    dir = mkdir(dir)
    dir_r = eventually(() -> OSF.refresh(dir))
    @test sprint(show, dir) == "OSF Directory `$(abspath(dir))`"
    @test !islink(dir)
    @test isdir(dir)
    @test isdir(dir_r)
    @test abspath(dir) == abspath(dir_r)
    @test [basename(d) for d in readdir(OSF.Directory, suite_root)] == ["mydir"]
    
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
    @test sprint(show, file) == "OSF File `$(abspath(file))` (doesn't exist)"
    @test !isfile(file)
    @test joinpath(dir, file) == file
    @test_throws MethodError joinpath(file, dir)

    @test write(file, "my file content") == length("my file content")
    file = eventually(() -> OSF.refresh(file))
    @test sprint(show, file) == "OSF File `$(abspath(file))` (15 bytes)"
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

    @test write(file, b"some new content") == length(b"some new content")
    @test eventually_true(() -> read(file, String) == "some new content")
    @test eventually_true(() -> read(file) == b"some new content")
    @test eventually_true(() -> length(OSF.versions(file)) == 2)
    @test eventually_true(() -> read.(OSF.versions(file), String) == ["some new content", "my file content"])
    url_ver2 = OSF.url(OSF.versions(file) |> maximum)
    @test download_as_string(url_file) == "some new content"
    @test download_as_string(url_ver1) == "my file content"
    @test download_as_string(url_ver2) == "some new content"

    let fname = tempname()
        write(fname, "content from file")
        open(fname) do io
            @test write(file, io) == length("content from file")
        end
    end
    @test eventually_true(() -> read(file, String) == "content from file")
    @test eventually_true(() -> length(OSF.versions(file)) == 3)

    mktemp() do path, _
        write(path, "more from file")
        @test_throws OSF.OSFError cp(path, file)
        @test cp(path, file; force=true) == file
    end
    @test eventually_true(() -> read(file, String) == "more from file")
    @test eventually_true(() -> length(OSF.versions(file)) == 4)
    url_ver4 = OSF.url(OSF.versions(file) |> maximum)
    @test download_as_string(url_ver1) == "my file content"
    @test download_as_string(url_ver2) == "some new content"
    @test download_as_string(url_ver4) == "more from file"
    @test download_as_string(url_file) == "more from file"

    let fname = tempname()
        @test cp(file, fname) == fname
        file = eventually(() -> OSF.refresh(file))
        @test_throws Exception cp(file, fname)
        cp(file, fname; force=true)
        @test read(fname, String) == "more from file"
    end

    map(OSF.url, OSF.versions(file))

    wd = collect(walkdir(dir))
    @test map(x -> basename(x[1]), wd) == ["mydir", "mysubdir"]
    @test map(x -> map(basename, x[2]), wd) == [["mysubdir"], []]
    @test map(x -> map(basename, x[3]), wd) == [["myfile.txt"], []]

    weird_dir_name = "dir & spaced"
    weird_file_name = "file & spaced.txt"
    weird_dir = OSF.directory(suite_root, weird_dir_name)
    weird_dir = mkdir(weird_dir)
    weird_dir = eventually(() -> OSF.refresh(weird_dir))
    @test isdir(weird_dir)
    @test basename(weird_dir) == weird_dir_name

    weird_file = OSF.file(weird_dir, weird_file_name)
    write(weird_file, "special content")
    weird_file = eventually(() -> OSF.refresh(weird_file))
    @test isfile(weird_file)
    @test basename(weird_file) == weird_file_name
    @test read(weird_file, String) == "special content"

    @test rm(weird_file) isa OSF.FileNonexistent
    @test eventually_true(() -> !isfile(OSF.refresh(weird_file)))
    @test rm(weird_dir) isa OSF.DirectoryNonexistent
    @test eventually_true(() -> !isdir(OSF.refresh(weird_dir)))

    @test_throws OSF.OSFError rm(OSF.file(dir, "missing_$(test_name("file")).txt"))
    @test_throws OSF.OSFError cp(OSF.file(dir, "missing_$(test_name("file")).txt"), tempname())

    @test rm(file) isa OSF.FileNonexistent
    @test eventually_true(() -> !isfile(OSF.refresh(file)))
    @test rm(subdir) isa OSF.DirectoryNonexistent
    @test eventually_true(() -> !isdir(OSF.refresh(subdir)))
    @test rm(dir) isa OSF.DirectoryNonexistent
    @test eventually_true(() -> !isdir(OSF.refresh(dir)))

    nested = OSF.directory(proj, "$(suite_root_name)/nested/a/b/c")
    @test !isdir(nested)
    nested = mkpath(nested)
    @test isdir(nested)
    @test isdir(OSF.directory(proj, "$(suite_root_name)/nested/"))
    @test isdir(OSF.directory(proj, "$(suite_root_name)/nested/a/"))
    @test isdir(OSF.directory(proj, "$(suite_root_name)/nested/a/b/"))

    @test_throws OSF.OSFError mkdir(OSF.directory(proj, "$(suite_root_name)/missing_parent/x/y"))

    @test rm(suite_root) isa OSF.DirectoryNonexistent
    @test eventually_true(() -> !isdir(OSF.refresh(suite_root)))
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
        sleep(1)
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
        sleep(1)
        versions = OSF.API.relationship_complete(osf, file, :versions, etype=:file_versions)
        @test length(versions) == 2
        url = OSF.API.file_viewonly_url(versions[1], vo_link, :download)
        content = String(take!(Downloads.download(string(url), IOBuffer())))
        @test content == "updated content 21"
    end

    @testset "folders" begin
        OSF.API.create_folder(osf, storage, "testdir")
        sleep(1)
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
