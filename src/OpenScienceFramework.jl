module OpenScienceFramework

module API
include("general_api.jl")
include("waterbutler_api.jl")
include("helpers.jl")
end

import Downloads
import .API: Client

const OSF = OpenScienceFramework
export OSF

include("highlevel.jl")

end
