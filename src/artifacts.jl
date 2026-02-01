"""
    create_upload_artifact(local_dir, artifact_name; osf_dir, toml_file, update_existing=false, lazy=true)
    create_upload_artifact(func, artifact_name; osf_dir, toml_file, update_existing=false, lazy=true)

Create a Julia `Artifact` from a local directory (or a `func` that populates one),
compress it as `.tar.gz`, upload to `osf_dir` on OSF, and bind it in `toml_file`.

- `osf_dir`: the OSF [`Directory`](@ref) to upload the archive to.
- `toml_file`: path to `Artifacts.toml` to update with download info.
- `update_existing`: set to `true` to overwrite an existing artifact and OSF file.
- `lazy`: whether the artifact should be downloaded lazily (default `true`).
"""
create_upload_artifact(dir::AbstractString, args...; kwargs...) =
    create_upload_artifact(args...; kwargs...) do art_dir
        cp(dir, art_dir; force=true)
    end

function create_upload_artifact(func::Function, artifact_name::AbstractString; osf_dir::Directory, toml_file::AbstractString, update_existing=false, lazy=true)
    tar_name = "$artifact_name.tar.gz"
	osf_file = OSF.file(osf_dir, tar_name)
    hash = artifact_hash(artifact_name, toml_file)

    if update_existing && (!isfile(osf_file) || isnothing(hash))
        @error "" update_existing osf_exists=isfile(osf_file) artifact_exists=!isnothing(hash)
        error("Artifact or file doesn't exists while `update_existing=true` is passed.")
    end
    if !update_existing && (isfile(osf_file) || !isnothing(hash))
        @error "" update_existing osf_exists=isfile(osf_file) artifact_exists=!isnothing(hash)
        error("Artifact or file already exists, pass `update_existing=true` to update.")
    end

    hash = create_artifact(func)

    tar_hash = mktempdir() do tmp_dir
        tar_path = joinpath(tmp_dir, tar_name)
        @info "Archiving" to=tar_path
        tar_hash = archive_artifact(hash, tar_path)
        @info "Uploading" from=tar_path to=abspath(osf_file)
		cp(tar_path, osf_file; force=update_existing)
        tar_hash
    end

    @info "Determining url" artifact_name
	osf_file = OSF.file(osf_dir, tar_name)
	url = OSF.versions(osf_file) |> maximum |> OSF.url |> string

    @info "Binding artifact" artifact_name url
    bind_artifact!(
        toml_file, artifact_name, hash;
        download_info=[(url, tar_hash)],
        lazy,
        force=update_existing
    )
end
