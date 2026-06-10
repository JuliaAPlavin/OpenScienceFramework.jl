# Artifacts

OpenScienceFramework.jl integrates with Julia's artifact system, allowing you to store package artifacts on OSF.

## Creating and Uploading Artifacts

```@docs
OpenScienceFramework.create_upload_artifact
```

## Example

```julia
# Create an artifact from a local directory and upload to OSF
OSF.create_upload_artifact(
    "/path/to/data",
    "my_artifact";
    osf_dir = OSF.directory(proj, "/artifacts"),
    toml_file = "Artifacts.toml",
)

# Or using a function that populates the artifact
OSF.create_upload_artifact(
    "my_artifact";
    osf_dir = OSF.directory(proj, "/artifacts"),
    toml_file = "Artifacts.toml",
) do art_dir
    # Populate art_dir with your data
    run(`tar xf data.tar.gz -C $art_dir`)
end
```

## Updating Existing Artifacts

To overwrite an existing artifact and its corresponding OSF file:

```julia
OSF.create_upload_artifact(
    "/path/to/updated/data",
    "my_artifact";
    osf_dir = OSF.directory(proj, "/artifacts"),
    toml_file = "Artifacts.toml",
    update_existing = true,
)
```
