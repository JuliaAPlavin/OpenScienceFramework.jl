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

to_payload(x::String) = x
to_payload(x::Dict) = JSON.write(x)
result_to(T::Type{String}, r::HTTP.Response) = String(r.body)
result_to(T::Type{Dict}, r::HTTP.Response) = copy(JSON.read(String(r.body)))
result_to(T::Type, r::HTTP.Response) = JSON.read(String(r.body), T)
resource_url(osf::Client, x::String) = occursin(r"^https?://", x) ? x : joinpath("https://api.osf.io", "v$(osf.api_version)", x)

function request(osf::Client, ::Val{:GET}, resource, T)::T
    r = HTTP.get(resource_url(osf, resource), headers(osf))
    return result_to(T, r)
end

function request(osf::Client, ::Val{:POST}, resource, T; payload, content_type="application/json")::T
    r = HTTP.post(
        resource_url(osf, resource),
        [headers(osf); "Content-Type" => content_type],
        to_payload(payload)
    )
    return result_to(T, r)
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
        r = new()
        for k in fieldnames(Entity{T})
            isdefined(e, k) && setfield!(r, k, getfield(e, k))
        end
        r
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
    r = request(osf, Val(:GET), "$endpoint/$id", EntityContainer{nothing})
    return convert(Entity{endpoint}, r.data)
end



mutable struct EntityCollection{T}
    links::Dict
    meta::Dict
    data::Vector{Entity{T}}
    EntityCollection{T}() where {T} = new()

    function EntityCollection{T}(e::EntityCollection{nothing}) where {T}
        new(map(k -> getfield(e, k), fieldnames(EntityCollection{T}))...)
    end
end
check(ec::EntityCollection) = foreach(check, ec.data)
StructTypes.StructType(::Type{<:EntityCollection}) = StructTypes.Mutable()

is_complete(ec::EntityCollection) = length(ec.data) == ec.links["meta"]["total"]
has_next(ec::EntityCollection) = !isnothing(ec.links["next"])
get_next(osf::Client, ec::EntityCollection{T}) where {T} = get_collection(osf, ec.links["next"], etype=T)

function relationship(osf::Client, entity::Entity, relationship::Symbol; etype::Union{Nothing, Symbol}=relationship, filters::Vector=[])
    return get_collection(osf, entity.relationships[relationship]["links"]["related"]["href"]; filters, etype=etype)
end

function get_collection(osf::Client, endpoint::String; filters::Vector=[], etype=nothing)
    uri = parse(HTTP.URI, endpoint)
    query = merge(HTTP.queryparams(uri), Dict("filter[$field]" => value for (field, value) in filters))
    uri = HTTP.URI(uri; query)
    r = request(osf, Val(:GET), string(uri), EntityCollection{nothing})
    return EntityCollection{etype}(r)
end
