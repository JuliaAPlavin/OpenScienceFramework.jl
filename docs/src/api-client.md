# Client & Authentication

The `Client` type is the entry point for all OSF operations.

## Types

```@docs
OpenScienceFramework.API.Client
```

## Usage

### Unauthenticated (Public Access)

```julia
client = OSF.API.Client()
```

### With Personal Access Token

```julia
# Explicit token
client = OSF.API.Client(token="my-token")

# Or via environment variable OSF_TOKEN
client = OSF.API.Client()
```

Create tokens at [https://osf.io/settings/tokens](https://osf.io/settings/tokens).

### With View-Only Key

```julia
client = OSF.API.Client(view_only="your-view-only-key")
```

This provides read-only access to a private project shared via a view-only link.

## HTTP Methods

The client supports standard HTTP methods through the `request` function. See the [Internal API](api-internal.md) documentation for details on `API.request`, entity types, and low-level operations.
