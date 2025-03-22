const LevelType = Union{Float32, typeof(1.0f0:0.5f0:1.5f0)}
const MaxLevelType = Tuple{Int8, Int8, Int8}
const IVsType = Tuple{Integer, Integer, Integer}
const StatsType = Tuple{T, T, T} where {T <: AbstractFloat}
const TypeStrings = Union{Tuple{String}, Tuple{String, String}}

Base.convert(::Type{Species}, key::AbstractString) = only_pokemon(denormal(key); exact = true)

display_name(pd::Species) = titlecase(denormal(uniquename(pd)))
display_name(key::AbstractString) = display_name(Species(key))

struct Pokemon
    pd::Species
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

    function Pokemon(pd, name, level, ivs, islucky, mutation, max, isshiny, weight, height, mega, maxlevel, raid_tier, max_tier; warn::Bool = true)
        if warn && pd.dex ∈ dex_unavilable && pd.dex ∉ unavail_shown
            @warn "if pokemon $(pd.dex) ($(uniquename(pd)) is available, update 'dex_unavailable' in 'src/consts.jl'"
            push!(unavail_shown, pd.dex)
        end
        level = level === nothing ? nothing :
            isa(level, Real) ? Float32(level) : convert(typeof(1.0f0:0.5f0:1.5f0), level)
        return new(pd, name, level, ivs, islucky, mutation, max, isshiny, weight, height, mega, maxlevel, raid_tier, max_tier)
    end
end
Pokemon(;
    pd, name = display_name(pd), level, ivs, islucky = false, mutation = 'N', max = 'N', isshiny = false,
    weight = NaN32, height = NaN32, mega = false, maxlevel = nothing, raid_tier = nothing, max_tier = nothing, kwargs...
) =
    Pokemon(pd, name, level, ivs, islucky, mutation, max, isshiny, weight, height, mega, maxlevel, raid_tier, max_tier; kwargs...)

"""
    Pokemon(id, level, ivs; name=display_name(id), islucky=false, mutation='N', isshiny=false, mega=false, max='N', maxlevel=nothing, raid_tier=nothing, max_tier=nothing)
    Pokemon(id, ivs; cp, kwargs...)

Construct a Pokemon. `id` is either a `Species` or a valid argument for `only_pokemon(id; exact=true)`.
If `level` is not supplied, `cp` is an obligate keyword argument.
`mega` is typically `true` or `false`, except in cases (like Charizard)
where one should supply a `Char` to disambiguate the mega (e.g., `'X'` or `'Y'`).

# Examples

```julia
julia> Pokemon("Ralts", (8, 12, 10); cp=204)
Ralts; CP: 204; level: 15.0; IVs: (8, 12, 10)

julia> Pokemon("LUCARIO", 20.0, (15, 12, 13); name="Wiley")
Wiley (Lucario); CP: 1521; level: 20.0; IVs: (15, 12, 13)
```
"""
Pokemon(id::Union{AbstractString, Species}, level::Union{Real, LevelType}, ivs::IVsType; kwargs...) =
    Pokemon(; kwargs..., pd = convert(Species, id), level, ivs)
function Pokemon(id::Union{AbstractString, Species}, ivs::IVsType; cp, kwargs...)
    pd = convert(Species, id)
    return Pokemon(; kwargs..., pd, ivs, level = PoGOBase.level(pd, ivs; cp))
end
Pokemon(id::Union{AbstractString, Species}; kwargs...) = Pokemon(; level = nothing, ivs = (15, 15, 15), kwargs..., pd = convert(Species, id))

# Pokemon(; kwargs...) = Pokemon(; level=nothing, ivs=(15, 15, 15), kwargs..., pd=convert(Species, id))

# function Base.:(==)(pk1::Pokemon, pk2::Pokemon)
#     return pk1.pd == pk2.pd && pk1.name == pk2.name && pk1.level == pk2.level && pk1.ivs == pk2.ivs &&
#            pk1.islucky == pk2.islucky && pk1.mutation == pk2.mutation && pk1.max == pk2.max &&
#            pk1.isshiny == pk2.isshiny && isequal(pk1.weight, pk2.weight) && isequal(pk1.height, pk2.height) &&
#            pk1.mega == pk2.mega && pk1.maxlevel == pk2.maxlevel && pk1.raid_tier == pk2.raid_tier &&
#            pk1.max_tier == pk2.max_tier
# end
# const hash_Pokemon = Int === Int64 ? 0x001bcd49504307e1 : 0x5056a59d
# function Base.hash(pk::Pokemon, h::UInt)
#     return hash(hash_Pokemon, hash(pk.pd, hash(pk.name, hash(pk.level, hash(pk.ivs, hash(pk.islucky,
#            hash(pk.mutation, hash(pk.max, hash(pk.isshiny, hash(pk.weight, hash(pk.height, hash(pk.mega,
#            hash(pk.maxlevel, hash(pk.raid_tier, hash(pk.max_tier, h)))))))))))))))
# end

function Base.show(io::IO, poke::Pokemon)
    (; name, pd) = poke
    key = display_name(pd)
    showname(io, poke, name)
    if poke.mega != false
        key = "Mega " * key
        if poke.mega isa Char
            key *= ' ' * poke.mega
        end
    end
    if name != key
        print(io, " (", key, ")")
    end
    return if !(get(io, :nameonly, false)::Bool)
        if poke.max_tier !== nothing
            print(io, "; max tier: ", poke.max_tier)
        else
            cp = combat_power(poke)
            print(io, "; CP: ", cp)
            if !(get(io, :compact, false)::Bool)
                if poke.level === nothing
                    print(io, "; HP: ", hp(poke), " (raid tier $(poke.raid_tier))")
                else
                    print(io, "; level: ", poke.level, "; IVs: ", poke.ivs)
                end
            end
        end
    end
end

function showname(io::IO, poke, name = poke.name)
    if isshadow(poke)
        printstyled(io, name; color = :light_black)
    elseif poke.islucky
        printstyled(io, name; color = :yellow)
    else
        print(io, name)
    end
    return if isshiny(poke)
        printstyled(io, "†"; color = :blue)
    end
end

PoGOGamemaster.Species(poke::Pokemon) = poke.pd
PoGOGamemaster.uniquename(poke::Pokemon) = uniquename(Species(poke))
PoGOGamemaster.type(poke::Pokemon) = type(getmega(Species(poke), poke.mega))

## Max attacks

struct MaxAttack <: AbstractMove
    type::String
    power::Float32
end
PoGOGamemaster.type(ma::MaxAttack) = ma.type
PoGOGamemaster.power(ma::MaxAttack) = ma.power

function MaxAttack(fastmove::PvEMove, poke::Pokemon)
    poke.max ∈ ('D', 'G') || throw(ArgumentError("$poke is not a dynamax or gigantamax"))
    maxlevel = poke.maxlevel
    maxlevel === nothing && throw(ArgumentError("$poke lacks `maxlevel` data"))
    p = maxbattles.movepower[maxlevel[1]]
    poke.max == 'G' && return MaxAttack(gmax_moves[uniquename(poke)], p + maxbattles.movepower_bonus_gmax)
    return MaxAttack(type(fastmove), p)
end

## Types for simplified battle mechanics

struct BossFT
    pd::Species                    # used only for its typing and move availibility (not stats)
    ferocity::Float32                  # like attack, but with all multipliers included
    tankiness::Float32                 # defensive parameter for a world in which the boss HP starts at 100%
end

PoGOGamemaster.Species(boss::BossFT) = boss.pd
PoGOGamemaster.type(boss::BossFT) = type(boss.pd)
PoGOGamemaster.uniquename(boss::BossFT) = uniquename(boss.pd)

Base.show(io::IO, boss::BossFT) = print(io, "BossFT($(display_name(boss.pd)), $(boss.ferocity), $(boss.tankiness))")

"""
    BossFT(boss::Species, tier::Int; attack_multiplier=1, defense_multiplier=1, cpm=maxbattles.cpm[tier], hp=maxbattles.hp[tier]) -> BossFT

Represent a max-battle boss with simplified parameters `ferocity` and `tankiness`.
"""
function BossFT(boss::Species, tier::Int; attack_multiplier = 1, defense_multiplier = 1, cpm = maxbattles.cpm[tier], hp = maxbattles.hp[tier])
    stats = base_stats(boss) .+ 15
    f = ferocity(cpm, stats[1], attack_multiplier)
    t = tankiness(cpm, stats[2], hp, defense_multiplier)
    return BossFT(boss, f, t)
end

# To distinguish absolute from %HP damage, we need a Tankiness unit
module ExtraUnits
    using Unitful
    @dimension(𝓣, "𝓣", TankUnits, autodocs = false)
    @refunit(Tk, "Tk", TankUnits, 𝓣, false, autodocs = false)
    const QTk{T} = Quantity{T, 𝓣}

    export QTk, Tk
end
using .ExtraUnits
