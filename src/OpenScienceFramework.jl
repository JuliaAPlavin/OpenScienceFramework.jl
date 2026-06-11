module OpenScienceFramework

struct OSFError <: Exception
    message::String
end
Base.showerror(io::IO, e::OSFError) = print(io, e.message)

"""
    API

Internal submodule that provides low-level access to the OSF REST API and Waterbutler file API.
Contains [`Client`](@ref), [`Entity`](@ref), HTTP request handling, and pagination utilities.
For most use cases, prefer the high-level functions exported from the main module.
"""
module API
include("general_api.jl")
include("waterbutler_api.jl")
include("helpers.jl")
end

import Downloads
import .API: Client
using Pkg.Artifacts

const OSF = OpenScienceFramework
export OSF

include("highlevel.jl")
include("artifacts.jl")

end
