module OpenScienceFramework

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
