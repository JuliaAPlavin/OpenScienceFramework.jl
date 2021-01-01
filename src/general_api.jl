# API docs: https://developer.osf.io/

import HTTP
import JSON3 as JSON
import StructTypes
using Parameters


@with_kw struct Client
    api_version::String = "2"
    token::String
end

headers(osf::Client) = ["Authorization" => "Bearer $(osf.token)"]

function request(::Type{String}, osf::Client, method::String, resource::String)::String where {T}
    r = HTTP.request(
        method,
        occursin(r"^https?://", resource) ? resource : joinpath("https://api.osf.io", "v$(osf.api_version)", resource),
        headers(osf),
    )
    return String(r.body)
end

function request(::Type{Dict}, args...)::Dict
    return copy(JSON.read(request(String, args...)))
end

function request(::Type{T}, args...)::T where {T}
    return JSON.read(request(String, args...), T)
end


mutable struct Entity{T}
    type::String
    id::String
    links::Dict{Symbol, String}
    attributes::Dict{Symbol, Any}
    relationships::Dict{Symbol, Dict}
    Entity{T}() where {T} = new()

    function Entity{T}(e::Entity{nothing}) where {T}
        @assert T === nothing || Symbol(e.type) == T
        new(map(k -> getfield(e, k), fieldnames(Entity{T}))...)
    end
end
check(e::Entity{T}) where {T} = @assert T === nothing || Symbol(e.type) == T

Base.convert(::Type{Entity{nothing}}, e::Entity{nothing}) = e
Base.convert(::Type{Entity{T}}, e::Entity{nothing}) where {T} = Entity{T}(e)
StructTypes.StructType(::Type{<:Entity}) = StructTypes.Mutable()

mutable struct EntityContainer{T}
    meta::Dict
    data::Entity{T}
    EntityContainer{T}() where {T} = new()
end
StructTypes.StructType(::Type{<:EntityContainer}) = StructTypes.Mutable()


function get_entity(osf::Client, endpoint::Symbol, id::String)
    r = request(EntityContainer{endpoint}, osf, "GET", "$endpoint/$id")
    check(r.data)
    return r.data
end



mutable struct EntityCollection{T}
    links::Dict
    meta::Dict
    data::Vector{Entity{T}}
    EntityCollection{T}() where {T} = new()
end
check(ec::EntityCollection) = foreach(check, ec.data)
StructTypes.StructType(::Type{<:EntityCollection}) = StructTypes.Mutable()

is_complete(ec::EntityCollection) = length(ec.data) == ec.links["meta"]["total"]

function relationship(osf::Client, entity::Entity, relationship::Symbol; etype::Union{Nothing, Symbol}=relationship, filters::Vector=[])
    return get_collection(osf, entity.relationships[relationship]["links"]["related"]["href"]; filters, etype=etype)
end

function get_collection(osf::Client, endpoint::String; filters::Vector=[], etype=nothing)
    filter_str = join(["filter[$field]=$value" for (field, value) in filters], "&")
    r = request(EntityCollection{etype}, osf, "GET", joinpath(endpoint, "?$filter_str"))
    check(r)
    return r
end