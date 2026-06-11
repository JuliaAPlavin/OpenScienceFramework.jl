# Internal API

The `OSF.API` submodule provides lower-level access to the [OSF REST API](https://developer.osf.io/) and the [Waterbutler API](https://waterbutler.readthedocs.io/).

## Module Structure

```@docs
OpenScienceFramework.API
```

## HTTP Client

The `Client` type handles authentication and HTTP requests. See [Client & Authentication](api-client.md) for usage details.

## HTTP Requests

```@docs
OpenScienceFramework.API.request
```

## Entities

API responses are deserialized into typed `Entity` objects:

```@docs
OpenScienceFramework.API.Entity
OpenScienceFramework.API.EntityContainer
OpenScienceFramework.API.EntityCollection
```

## Entity Operations

```@docs
OpenScienceFramework.API.get_entity
OpenScienceFramework.API.create_entity
OpenScienceFramework.API.delete
```

## Relationships and Collections

```@docs
OpenScienceFramework.API.relationship
OpenScienceFramework.API.relationship_complete
```

## Waterbutler Operations

File operations use the Waterbutler API:

- `upload_file` — Upload file content to an existing file or create a new file in a directory
- `create_folder` — Create a new folder in a directory

## Helper Functions

```@docs
OpenScienceFramework.API.find_by_path
OpenScienceFramework.API.file_viewonly_url
```
