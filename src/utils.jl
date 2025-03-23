"""
    split_kwargs(keep; kwargs...) → kwkeep, kwdisc

Split `kwargs` by name into two groups, with the first group containing those names appearing in `keep`.

# Examples

```julia
julia> PoGOBase.split_kwargs((:a, :z); a=5, b="hello", z=nothing)
((a = 5, z = nothing), (b = "hello",))
```
"""
function split_kwargs(keep; kwargs...)
    kwkeep, kwdisc = Dict{Symbol, Any}(), Dict{Symbol, Any}()
    for (key, val) in kwargs
        target = key ∈ keep ? kwkeep : kwdisc
        target[key] = val
    end
    return NamedTuple(kwkeep), NamedTuple(kwdisc)
end

# from NamedTupleTools.jl
function ntfromstruct(x::T) where {T}
    !isstructtype(T) && throw(ArgumentError("$(T) is not a struct type"))
    names = fieldnames(T)
    values = map(name -> getfield(x, name), names)
    return NamedTuple{names}(values)
end

trim2(a, b) = (n = min(length(a), length(b)); return a[1:n], b[1:n])

levfrac(a, b) = Levenshtein()(a, b) / min(length(a), length(b))

"""
    binary_search(f, flim, xmin, xmax, Δx) → x => f(x)

Return the largest value of `x`, starting with `xmin` and incrementing by `Δx` as long as `x <= xmax`,
such that `f(x) <= flim`.
"""
function binary_search(f, flim, xmin, xmax, Δx)
    rounddx(x) = round(Int, x / Δx) * Δx

    fmin, fmax = f(xmin), f(xmax)
    fmin > flim && error(xmin, " is too high")
    fmax <= flim && return xmax => fmax
    while xmax - xmin > Δx
        xmid = rounddx((xmin + xmax) / 2)
        fmid = f(xmid)
        if fmid <= flim
            xmin, fmin = xmid, fmid
        else
            xmax, fmax = xmid, fmid
        end
    end
    return fmax <= flim ? xmax => fmax : xmin => fmin
end

# JLD2 serialization

# This is primarily to avoid writing the entire `Species` object repeatedly

struct PokemonSerialization
    key::String
    name::String                     # assigned name
    level::Union{LevelType, Nothing}
    ivs::Tuple{Int16, Int16, Int16}
    islucky::Bool
    mutation::Char                   # 'N' for normal, 'S' for shadow, 'P' for purified
    max::Char                        # 'N' for normal, 'D' for dynamax, 'G' for gigantamax
    isshiny::Bool
    weight::Float32
    height::Float32
    mega::Union{Bool, Char}           # 'X' and 'Y' for Charizard
    maxlevel::Union{Nothing, MaxLevelType}   # (attack, guard, spirit)
    raid_tier::Union{Nothing, Float16}       # for raid bosses
    max_tier::Union{Nothing, Float16}        # for max-battle bosses

    function PokemonSerialization(poke::Pokemon)
        return new(
            uniquename(poke), poke.name, poke.level, poke.ivs, poke.islucky, poke.mutation, poke.max, poke.isshiny,
            poke.weight, poke.height, poke.mega, poke.maxlevel, poke.raid_tier, poke.max_tier
        )
    end
end

Pokemon(poke::PokemonSerialization) = Pokemon(
    only_pokemon(poke.key; exact = true), poke.name, poke.level, poke.ivs, poke.islucky, poke.mutation, poke.max, poke.isshiny,
    poke.weight, poke.height, poke.mega, poke.maxlevel, poke.raid_tier, poke.max_tier
)

JLD2.writeas(::Type{Pokemon}) = PokemonSerialization
Base.convert(::Type{Pokemon}, ps::PokemonSerialization) = Pokemon(ps)
Base.convert(::Type{PokemonSerialization}, poke::Pokemon) = PokemonSerialization(poke)
