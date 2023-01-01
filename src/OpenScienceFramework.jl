module OpenScienceFramework

module API
include("general_api.jl")
include("waterbutler_api.jl")
include("helpers.jl")
end

import Downloads

include("highlevel.jl")

end
