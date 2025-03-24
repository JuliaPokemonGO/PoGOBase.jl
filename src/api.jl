## Match pokemon by name

const match_kwargs = (:tol, :complete)

"""
    matching_pokemon(name::AbstractString; tol=0.0, complete=false) → species

Return a list of `Species` objects that match the given name. If `complete` is `true`, the name must match exactly.

`tol` represents a tolerance on the Levenshtein distance between the name and the species name.

# Examples

```jldoctest
julia> matching_pokemon("rattata")
2-element Vector{Species}:
 RATTATA (NORMAL): (103, 70, 102); Fast: ["TACKLE_FAST", "QUICK_ATTACK_FAST"]; Charged: ["DIG", "HYPER_FANG", "BODY_SLAM"]
 RATTATA_ALOLA (DARK/NORMAL): (103, 70, 102); Fast: ["TACKLE_FAST", "QUICK_ATTACK_FAST"]; Charged: ["CRUNCH", "HYPER_FANG", "SHADOW_BALL"]

julia> matching_pokemon("rattata"; complete=true)
1-element Vector{Species}:
 RATTATA (NORMAL): (103, 70, 102); Fast: ["TACKLE_FAST", "QUICK_ATTACK_FAST"]; Charged: ["DIG", "HYPER_FANG", "BODY_SLAM"]

julia> matching_pokemon("rattatta")      # misspelled
Species[]

julia> matching_pokemon("rattatta"; tol=0.25)
2-element Vector{Species}:
 RATTATA (NORMAL): (103, 70, 102); Fast: ["TACKLE_FAST", "QUICK_ATTACK_FAST"]; Charged: ["DIG", "HYPER_FANG", "BODY_SLAM"]
 RATTATA_ALOLA (DARK/NORMAL): (103, 70, 102); Fast: ["TACKLE_FAST", "QUICK_ATTACK_FAST"]; Charged: ["CRUNCH", "HYPER_FANG", "SHADOW_BALL"]
```
"""
function matching_pokemon(name::AbstractString; tol = 0.0, complete::Bool = false)
    nameu = uppercase(name)
    matches = Species[]
    keys = Set{String}()
    for (key, pd) in pokemon
        pdname = uniquename(pd)
        ismatch = if iszero(tol)
            complete ? pdname == nameu : startswith(pdname, nameu)
        else
            (complete ? levfrac(nameu, pdname) : levfrac(trim2(nameu, pdname)...)) <= tol
        end
        if ismatch
            push!(matches, pd)
            push!(keys, key)
        end
    end
    length(matches) == 1 && return matches
    return denormal(matches, keys)
end

"""
    matching_pokemon(name::AbstractString, types::AbstractString; kwargs...) → species

Return a list of `Species` objects that match the given name and types.

# Examples

```jldoctest
julia> matching_pokemon("rattata", "dark/normal")
1-element Vector{Species}:
 RATTATA_ALOLA (DARK/NORMAL): (103, 70, 102); Fast: ["TACKLE_FAST", "QUICK_ATTACK_FAST"]; Charged: ["CRUNCH", "HYPER_FANG", "SHADOW_BALL"]
```
"""
function matching_pokemon(name::AbstractString, types::AbstractString; kwargs...)
    matches = matching_pokemon(name; kwargs...)
    length(matches) < 2 && return matches
    types = split(types, '/')
    filter!(matches) do match
        match.type == uppercase(types[1]) || return false
        if length(types) > 1
            match.type2 == uppercase(types[2]) || return false
        else
            match.type2 === nothing || return false
        end
        return true
    end
    return matches
end

const onlymatch_kwargs = (:exact, :equiv, match_kwargs...)
function _only_pokemon(name::AbstractString, matches; exact::Bool = false, equiv::Bool = false)
    if exact
        filter!(pd -> uniquename(pd) == uppercase(name), matches)
    end
    isempty(matches) && error("no pokemon matching $name were found")
    if equiv && allequal((coreproperties(pd) for pd in matches))
        return matches[findmin(uniquename, matches)[2]]
    end
    if length(matches) != 1
        ids = [uniquename(pd) for pd in matches]
        error("multiple matching pokemon were found: ", ids)
    end
    return only(matches)
end

"""
    only_pokemon(name::AbstractString; exact=false, equiv=false, kwargs...) → species

Return the `Species` object that matches the given name, and throw an error if more than one matches.

If `exact` is `true`, only exact matches of the name are considered.
If `equiv` is `true`, an error is not thrown if all matches are equivalent in their types, base stats, and moves.

# Examples

```jldoctest
julia> only_pokemon("scatterbug")
ERROR: multiple matching pokemon were found: ["SCATTERBUG", "SCATTERBUG_ARCHIPELAGO", "SCATTERBUG_CONTINENTAL", "SCATTERBUG_ELEGANT", "SCATTERBUG_FANCY", "SCATTERBUG_GARDEN", "SCATTERBUG_HIGH_PLAINS", "SCATTERBUG_ICY_SNOW", "SCATTERBUG_JUNGLE", "SCATTERBUG_MARINE", "SCATTERBUG_MEADOW", "SCATTERBUG_MODERN", "SCATTERBUG_MONSOON", "SCATTERBUG_OCEAN", "SCATTERBUG_POKEBALL", "SCATTERBUG_POLAR", "SCATTERBUG_RIVER", "SCATTERBUG_SANDSTORM", "SCATTERBUG_SAVANNA", "SCATTERBUG_SUN", "SCATTERBUG_TUNDRA"]

julia> only_pokemon("scatterbug"; equiv=true)
SCATTERBUG (BUG): (63, 63, 116); Fast: ["BUG_BITE_FAST", "TACKLE_FAST"]; Charged: ["STRUGGLE"]
"""
function only_pokemon(name::AbstractString; exact::Bool = false, equiv::Bool = false, kwargs...)
    matches = matching_pokemon(name; kwargs...)
    return _only_pokemon(name, matches; exact, equiv)
end
function only_pokemon(name::AbstractString, types::AbstractString; exact::Bool = false, equiv::Bool = false, kwargs...)
    matches = matching_pokemon(name, types; kwargs...)
    return _only_pokemon(name, matches; exact, equiv)
end

function denormal(matches, keys)
    # Filter out "_NORMAL" duplicates
    return filter(matches) do pd
        uname = uniquename(pd)
        if (endswith(uname, "_NORMAL") || endswith(uname, "_ORDINARY")) && pd.pokemonId ∈ keys
            return false
        end
        true
    end
end
denormal(str::AbstractString) = endswith(str, "_NORMAL") ? str[1:(end - length("_NORMAL"))] :
    endswith(str, "_ORDINARY") ? str[1:(end - length("_ORDINARY"))] : str

## Pokemon identity

"""
    PoGOBase.isavailable(species::Species) → Bool

Return `true` if the species is currently available in the game.
To update this list, see the `dex_unavailable` constant in `src/consts.jl`.
"""
function isavailable(pd::Species)
    # https://pokemondb.net/go/unavailable
    dx = dex(pd)
    dx ∈ dex_unavilable && return false
    if dx == 244 && uniquename(pd) == "ENTEI_S"   # Shadow Apex Entei
        return false
    end
    if dx == 250 && uniquename(pd) == "HO_OH_S"
        return false
    end
    if dx == 555 && uniquename(pd) ∈ ("DARMANITAN_GALARIAN_ZEN", "DARMANITAN_ZEN")
        return false
    end
    if dx == 647 && uniquename(pd) == "KELDEO_RESOLUTE"
        return false
    end
    if dx == 888 && uniquename(pd) == "ZACIAN_CROWNED_SWORD"
        return false
    end
    return true
end
function isavailable(poke::Pokemon)
    pd = Species(poke)
    isavailable(pd) || return false
    if poke.mutation == 'S'
        dx = dex(pd)
        if dx == 144 && uniquename(pd) == "ARTICUNO_GALARIAN"
            return false
        end
        if dx == 145 && uniquename(pd) == "ZAPDOS_GALARIAN"
            return false
        end
        if dx == 146 && uniquename(pd) == "MOLTRES_GALARIAN"
            return false
        end
        if dx == 483 && uniquename(pd) == "DIALGA_ORIGIN"
            return false
        end
        if dx == 484 && uniquename(pd) == "PALKIA_ORIGIN"
            return false
        end
    end
    return true
end

function is_legendary_mythical(pd::Species)
    pd.pokemonClass === nothing && return false
    return endswith(pd.pokemonClass, "MYTHIC") || endswith(pd.pokemonClass, "LEGENDARY") || endswith(pd.pokemonClass, "ULTRA_BEAST")
end

is_adult(pd::Species) = pd.evolutionBranch === nothing || all(ev -> ev isa MegaEvolution, pd.evolutionBranch)
is_adult(poke::Pokemon) = is_adult(Species(poke))

isshadow(poke::Pokemon) = poke.mutation == 'S'
ispurified(poke::Pokemon) = poke.mutation == 'P'
isshiny(poke::Pokemon) = poke.isshiny

"""
    megaevolve(poke::Pokemon, mega::Union{Bool, Char} = true) → megapoke

Create a new `Pokemon` object that is a mega-evolution of `poke`. If `mega` is `true`, the default mega-evolution
is used. If `mega` is a `Char`, the mega-evolution with that name is used. If `mega` is `false`, the normal form is returned.
"""
megaevolve(poke::Pokemon, mega::Union{Bool, Char} = true) = Pokemon(; ntfromstruct(poke)..., mega)

"""
    purify(poke::Pokemon) → purified_poke

Create a new `Pokemon` object that is a purified form of `poke`.
"""
function purify(poke::Pokemon)
    isshadow(poke) || return poke
    level = max(maximum(poke.level), 25)
    ivs = min.(poke.ivs .+ 2, 15)
    return Pokemon(; ntfromstruct(poke)..., ivs, level, mutation = 'P')
end

## Lists of pokemon, sometimes matching some criteria (megas, legendaries, etc)

"""
    eachpokemon(; include_shadow=true, include_mega=true, level=31, ivs=(15, 15, 15)) → pokes

Return a list of one of each species of `Pokemon` at the given level and IVs. By default, include
shadows and megas.
"""
function eachpokemon(; include_shadow = true, include_mega = true, level = 31, ivs = (15, 15, 15))
    pokes = Pokemon[]
    formes = Dict{Int, Vector{String}}()
    for dnp in dex_name_pairs()
        push!(get!(Vector{String}, formes, dnp.first), dnp.second)
    end
    for (key, pd) in pokemon
        keydn = denormal(key)
        fms = formes[dex(pd)]
        length(fms) > 1 && pd.form !== nothing && keydn != key && keydn ∈ fms && continue    # prefer ones without "NORMAL"
        fms, cms = fastmoves(pd), chargedmoves(pd)
        if fms != struggle || cms != struggle
            push!(pokes, Pokemon(pd, level, ivs; warn = false))
            if include_shadow && pd.shadow !== nothing
                push!(pokes, Pokemon(pd, level, ivs; mutation = 'S', warn = false))
            end
            if include_mega
                mevs = megas(pd)
                if !isempty(mevs)
                    for mega in mevs
                        push!(pokes, Pokemon(pd, level, ivs; mega, warn = false))
                    end
                end
            end
        end
    end
    return pokes
end

function unique_pokemon(list)
    T = eltype(list)
    dlist = Dict{Int16, Vector{T}}()
    for poke in list
        push!(get!(Vector{T}, dlist, dex(poke)), poke)
    end
    statsmoves = Set{Any}()
    out = T[]
    for (_, pokes) in dlist
        if length(pokes) == 1
            push!(out, first(pokes))
        else
            empty!(statsmoves)
            for poke in pokes
                pd = Species(poke)
                pdkey = (base_stats(pd), fastmoves(pd), chargedmoves(pd))
                if pdkey ∉ statsmoves
                    push!(out, poke)
                    push!(statsmoves, pdkey)
                end
            end
        end
    end
    return sort!(out; by = dex)
end

function dex_name_pairs()
    prs = Pair{Int, String}[]
    for (key, pd) in pokemon
        push!(prs, pd.dex[] => key)
    end
    return prs
end

function getmega(pd::Species, mega::Union{Bool, Char})
    megaev = pd.tempEvoOverrides.evos
    if isa(mega, Bool)
        !mega && return pd
        return only(megaev)
    end
    idx = findfirst(ev -> endswith(uniquename(ev), mega), megaev)
    idx === nothing && error("no mega-evolution ", mega, " found")
    return megaev[idx]
end

const nomegas = Char[]
const simplemegas = [true]
function megas(pd::Species)
    evs = pd.tempEvoOverrides
    (evs === nothing || isempty(evs)) && return nomegas
    evs = filter!(ev -> !isempty(uniquename(ev)), evs)
    length(evs) == 1 && return simplemegas
    return map(ev -> last(uniquename(ev)), evs)
end
megas() = filter(pokemon) do (key, pd)
    !endswith(key, "NORMAL") && !isempty(megas(pd))
end

const struggle = ["STRUGGLE"]
function legendaries_mythicals()
    pds = Species[]
    covered = Set{String}()
    for (name, pd) in pokemon
        if is_legendary_mythical(pd)
            uname = denormal(uniquename(pd))
            uname ∈ covered && continue
            push!(covered, uname)
            # If STRUGGLE is the only move, it's not yet released
            fms, cms = fastmoves(pd), chargedmoves(pd)
            if fms != struggle || cms != struggle
                push!(pds, pd)
            end
        end
    end
    return pds
end

## Stats/CP/HP

"""
    base_stats(poke::Pokemon) → (a, d, h)
    base_stats(species::Species; mega::Union{Bool, Char} = false) → (a, d, h)

Return the base attack (`a`), defense (`d`), and stamina (`h`) stats for a `Pokemon` or `Species`.
If `poke` is a mega-evolution or `mega != false`, the base stats for the mega-evolution are returned.
"""
base_stats(poke::Pokemon) = base_stats(Species(poke); mega = mega_default(poke))
function base_stats(pd::Species; mega::Union{Bool, Char} = false)
    mega === false && return Tuple(pd.stats)
    return Tuple(getmega(pd, mega).stats)
end
base_stats(pd::MegaOverride) = Tuple(pd.stats)
base_stats(key::AbstractString; mega = false, kwargs...) = base_stats(only_pokemon(key; kwargs...); mega)

stats(pd::Species, ivs::IVsType; mega::Union{Bool, Char} = false) = base_stats(pd; mega) .+ ivs
stats(pd::MegaOverride, ivs::IVsType) = base_stats(pd) .+ ivs
stats(pd::Species, ivs::IVsType, level::Real; mega::Union{Bool, Char} = false) =
    floorh(cpm_from_level(level) .* stats(pd, ivs; mega))
stats(pd::MegaOverride, ivs::IVsType, level::Real) =
    floorh(cpm_from_level(level) .* stats(pd, ivs))
stats(sts::Union{StatsType, IVsType}, level::Real) = floorh(cpm_from_level(level) .* sts)

"""
    stats(poke::Pokemon, level = poke.level; mega = false) → (a, d, h)

Return the attack, defense, and stamina stats for `poke`. Optionally you can override
the level and whether to use the mega-evolution stats, for example to see how the stats change
when you mega-evolve this Pokemon.
"""
function stats(poke::Pokemon, level::Real = scalarlevel(something(poke.level, NaN)); kwargs...)
    pd = getmega(Species(poke), poke.mega)
    poke.raid_tier !== nothing && return float.(raid_boss_stats(pd, poke.raid_tier))
    poke.max_tier !== nothing && return float.(max_boss_stats(pd, Int(poke.max_tier)))
    return stats(pd, poke.ivs, level; kwargs...)
end

floorh(a, d, h) = (a, d, floor(h))
floorh(t::Tuple{Real, Real, Real}) = floorh(t...)

combat_power(a::T, d::T, h::T, cpm::T) where {T <: AbstractFloat} = max(10, floor(Int, (a * sqrt(d * h) * cpm^2 / 10)))
combat_power(a::Real, d::Real, h::Real, cpm::AbstractFloat) = combat_power(promote(a, d, h, cpm)...)
function combat_power(pd::Species, ivs::IVsType, level; kwargs...)
    a, d, h = stats(pd, ivs; kwargs...)
    cpm = cpm_from_level.(level)
    return combat_power.(a, d, h, cpm)
end

"""
    combat_power(poke::Pokemon, level = poke.level) → cp

Return the combat power of `poke`. Optionally you can override the level, for example to see how the CP changes
when you power up the Pokemon.
"""
function combat_power(poke::Pokemon, level = poke.level)
    pd = Species(poke)
    if poke.raid_tier !== nothing
        # The stated combat power on the intro screen of a raid does not include the CPM
        # Thus we bypass the usual stats computations
        (; pd, raid_tier) = poke
        a, d, _ = base_stats(pd; mega = poke.mega)
        offsets = default_ivs(pd, raid_tier)
        a, d, h = a + offsets[1], d + offsets[2], raids.hp[raid_tier]
        return combat_power(a, d, h, 1.0)
    end
    # return combat_power(raid_boss_stats(pd, poke.raid_tier; mega=poke.mega)..., 1.0)
    return combat_power(pd, poke.ivs, level; mega = poke.mega)
end

hp(pd::Species, ivs::IVsType, level::Real) = max(10, Int(stats(pd, ivs, level)[3]))
hp(pd::Species, ivs::IVsType, level::AbstractVector) = [hp(pd, ivs, l) for l in level]

"""
    hp(poke::Pokemon, level = poke.level) → hp

Return the hit points of `poke`. Optionally you can override the level, for example to see how the HP changes
when you power up the Pokemon.
"""
function hp(poke::Pokemon, level = poke.level)
    raid_tier(poke) !== nothing && return raids.hp[poke.raid_tier]
    poke.max_tier !== nothing && return maxbattles.hp[Int(poke.max_tier)]
    return hp(Species(poke), poke.ivs, level)
end

"""
    statproduct(poke) → sp
    statproduct(stats) → sp

Compute the "stat product" for a specific Pokemon.
"""
statproduct(poke::Pokemon) = statproduct(stats(poke))
statproduct(stats::StatsType) = prod(stats) / 1000
statproduct(stats::IVsType) = statproduct(float.(stats))
statproduct(args...; kwargs...) = statproduct(stats(args...; kwargs...))

bulk(a, d, h) = sqrt(d * h)
bulk(stats::StatsType) = bulk(stats...)
# function bulk(poke::Pokemon)
#     stats = stats(Species(poke), poke.ivs, scalarlevel(poke))
#     stats = apply_shadow(stats, isshadow(poke))
#     return bulk(stats...)
# end

# Only for use in battles (does not apply to combat power calculations, though useful to estimate effective bulk)
apply_shadow(a, d, h) = ((a * 6) / 5, (d * 5) / 6, h)
apply_shadow(stats::StatsType) = apply_shadow(stats...)
apply_shadow(stats::StatsType, isshadow::Bool) = isshadow ? apply_shadow(stats...) : stats

function raid_boss_stats(pd::Species, tier::Real; mega = false)
    a, d, _ = base_stats(pd; mega)
    return tier_correct(a, d, pd, tier)
end
function raid_boss_stats(pd::MegaOverride, tier::Real)
    a, d, _ = base_stats(pd)
    return tier_correct(a, d, pd, tier)
end
function tier_correct(a, d, pd, tier)
    offsets = default_ivs(pd, tier)
    cpm = raids.cpm[tier]
    return cpm * (a + offsets[1]), cpm * (d + offsets[2]), raids.hp[tier]
end
raid_boss_stats(key::AbstractString, tier::Real; kwargs...) =
    raid_boss_stats(only_pokemon(key; kwargs...), tier)

function max_boss_stats(pd::Species, tier::Real)
    cpm = maxbattles.cpm[tier]
    a, d, _ = base_stats(pd)
    return cpm * (a + 15), cpm * (d + 15), maxbattles.hp[tier]
end

default_ivs(key, ::Nothing) = (15, 15, 15)
default_ivs(key, ::Real) = (15, 15, 0)  # the hp is set by the raid tier

# Enraged stats in shadow raids
# https://www.reddit.com/r/TheSilphRoad/comments/1gfjczs/more_indepth_analysis_details_of_max_battles_raids/
enrage_attack(a) = a + floor(typeof(a), 0.8f0 * a)
enrage_defense(d) = d + floor(typeof(d), 2.2f0 * d)

## Level

function level(pd::Species, ivs; hp = nothing, cp = nothing)
    hpc(h, cpm) = max(10, floor(Int, h * cpm))
    cpc(lvl::Real) = combat_power(pd, ivs, lvl)
    function scandown(f, val, lvlmax)
        # There may be multiple levels that are consistent with val
        lvlmin = lvlmax - 0.5
        while lvlmin >= 1.0 && f(lvlmin) == val
            lvlmin -= 0.5
        end
        lvlmin += 0.5
        return lvlmin == lvlmax ? lvlmax : (lvlmin:0.5:lvlmax)
    end

    hp === nothing && cp === nothing && error("must supply either hp or cp")

    if hp !== nothing
        _, _, h = stats(pd, ivs)
        hpl(l) = hpc(h, cpm_from_level(l))
        lvl, hp′ = binary_search(hpl, hp, 1.0, 51.0, 0.5)
        hp′ != hp && error("no level found that is consistent with HP, IVs, and key")
        return scandown(hpl, hp, lvl)
    else
        # Identify level from CP
        lvl, cp′ = binary_search(cpc, cp, 1.0, 51.0, 0.5)
        cp == cp′ || error("cp $cp not found for key $(uniquename(pd)) and IVs $ivs")
        return scandown(cpc, cp, lvl)
    end
end

function cpm_from_level(level::Real)
    1.0 <= level <= 51.0 || throw(ArgumentError("invalid level $level"))
    isinteger(level) && return combat_power_multiplier[Int(level)]
    lvlf, lvlc = floor(Int, level), ceil(Int, level)
    # @assert level == (lvlf + lvlc)/2   # why was this here?
    cf, cc = combat_power_multiplier[lvlf], combat_power_multiplier[lvlc]
    if lvlc <= 40
        return sqrt((cf^2 + cc^2) / 2)
    end
    # Above level 40, it's linear
    return (cf + cc) / 2
end


## Simple API and computations

dex(pd::Species) = pd.dex[]
dex(poke::Pokemon) = dex(Species(poke))
dex(key::AbstractString) = dex(pokemon[key])

lvlidx(lvl) = Int(2 * (lvl - 1.0)) + 1

scalarlevel(x::Real) = x
scalarlevel(rng::AbstractRange) = (first(rng) + last(rng)) / 2
scalarlevel(poke::Pokemon) = scalarlevel(poke.level)

isshadow_default(poke::Pokemon) = isshadow(poke)

mega_default(poke::Pokemon) = poke.mega

raid_tier(poke::Pokemon) = poke.raid_tier

## Battles

# Energy meter charging from damage done
max_battle_energy(dmgfrac::Real) = max(floor(Int, 200 * dmgfrac), 1)
max_battle_energy(dmg::Int, bosshp::Int) = max_battle_energy(dmg / bosshp)

max_battle_energy(dmg::Int, boss::Pokemon) = max_battle_energy(dmg, hp(boss))
max_battle_energy(dmg::Quantity{<:Real, NoDims}, ::BossFT) = max_battle_energy(ustrip(dmg) / 100)

helperbonus(helpericons::Integer) = iszero(helpericons) ? 1.0f0 : 1.0f0 + maxbattles.helper_bonus[helpericons]

## Evolutions

"""
    baby(poke::Pokemon) → baby_species
    baby(species::Species) → baby_species

Return the baby species (base stage evolution) for `poke` or `species`.
"""
function baby(pd::Species; tmp = Set{String}())
    while pd.parentPokemonId !== nothing && pd.pokemonId != pd.parentPokemonId
        found = false
        for babyname in formes[pd.parentPokemonId]
            b = pokemon[babyname]
            empty!(tmp)
            _lineage_ids!(tmp, b)
            if uniquename(pd) ∈ tmp
                pd = b
                found = true
                break
            end
        end
        found || return pd
    end
    return pd
end
baby(poke::Pokemon; kwargs...) = baby(Species(poke); kwargs...)

adults(pd::Species) = sort!(collect(_adults!(Set{Species}(), pd)); by = pd -> pd.pokemonId)
function _adults!(pds, pd)
    if pd.evolutionBranch === nothing
        push!(pds, pd)
        return pds
    end
    for ev in pd.evolutionBranch
        if ev isa EvolutionBranch
            _adults!(pds, pokemon[denormal(uniquename(ev))])
        else
            push!(pds, pd)  # adult that can mega
        end
    end
    return pds
end
adults(poke::Pokemon) = adults(Species(poke))

function adult_ids(list)
    ids = Set{String}()
    for poke in list
        ads = adults(poke)
        for ad in ads
            push!(ids, ad.pokemonId)
        end
    end
    return ids
end

"""
    lineage_ids(poke::Pokemon) → ids
    lineage_ids(species::Species) → ids
    lineage_ids(list) → ids

Return the further evolutions of `poke` or `species` as a list of IDs.

# Examples

```jldoctest
julia> PoGOBase.lineage_ids(only_pokemon("ivysaur"))
2-element Vector{String}:
 "IVYSAUR"
 "VENUSAUR"

julia> PoGOBase.lineage_ids(only_pokemon("ralts"))
4-element Vector{String}:
 "GALLADE"
 "GARDEVOIR"
 "KIRLIA"
 "RALTS"
```
"""
lineage_ids(pd::Species) = sort!(collect(_lineage_ids!(Set{String}(), pd)))
function _lineage_ids!(ids, pd)
    push!(ids, denormal(uniquename(pd)))
    pd.evolutionBranch === nothing && return ids
    for ev in pd.evolutionBranch
        ev isa EvolutionBranch || continue # skip megas
        _lineage_ids!(ids, pokemon[uniquename(ev)])
    end
    return ids
end
lineage_ids(poke::Pokemon) = lineage_ids(Species(poke))
function lineage_ids(list)
    ids = Set{String}()
    for item in list
        pd = isa(item, Species) ? item : Species(item)
        _lineage_ids!(ids, pd)
    end
    return sort!(collect(ids))
end

can_evolve_to(pd::Species, to::AbstractString) = to ∈ lineage_ids(pd)
can_evolve_to(pd::Species, to::Species) = can_evolve_to(pd, uniquename(to))
can_evolve_to(poke::Pokemon, to) = can_evolve_to(Species(poke), to)

## Power-up and evolution cost

function powerup_cost(level::Real; kind = :normal, lucky::Bool = false)
    kind ∈ (:normal, :shadow, :purified) || error("kind can only be :normal, :shadow, or :purified, got ", kind)
    # inlined because many callers will use only one of the outputs
    i = floor(Int, level)
    sd = powerups.stardustCost[i]
    c = powerups.candyCost[i]
    istart = length(powerups.candyCost) - length(powerups.xlCandyCost)
    cxl = i < istart ? 0 : powerups.xlCandyCost[i - istart + 1]
    if lucky
        sd = sd ÷ 2
    elseif kind == :shadow
        sd = round(Int, sd * powerups.shadowStardustMultiplier)
        mult = powerups.shadowCandyMultiplier
        c, cxl = ceil(Int, mult * c), ceil(Int, mult * cxl)
    elseif kind == :purified
        sd = round(Int, sd * powerups.purifiedStardustMultiplier)
        mult = powerups.purifiedCandyMultiplier
        c, cxl = ceil(Int, mult * c), ceil(Int, mult * cxl)
    end
    return (stardust = sd, candy = c, candyxl = cxl)
end

function powerup_cost(poke::Pokemon, level = minimum(poke.level))
    return powerup_cost(
        level; kind = isshadow(poke) ? :shadow :
            ispurified(poke) ? :purified : :normal, lucky = poke.islucky
    )
end

"""
    evolution_cost(poke::Pokemon, as::Species = Species(poke)) → cost

Return the candy `cost` to evolve `poke` to `as`.
"""
function evolution_cost(poke::Pokemon, as::Species = Species(poke))
    c = 0
    pd = Species(poke)
    mult = isshadow(poke) ? powerups.shadowCandyMultiplier :
        ispurified(poke) ? powerups.purifiedCandyMultiplier : 1.0
    while pd != as
        # Add evolution costs
        pdold = pd
        pds = map(ev -> pokemon[denormal(uniquename(ev))], pd.evolutionBranch)
        pd = as ∈ pds ? as : only(pds)
        c += ceil(Int, mult * pdold.evolutionBranch[findfirst(==(pd), pds)].candyCost)
    end
    return c
end

function stardust(poke::Pokemon, level)
    sd = 0
    for lvl in minimum(poke.level):0.5:(level - 0.5)
        sd += powerup_cost(poke, lvl).stardust
    end
    return sd
end
function stardust((from, to)::Pair{<:Real, <:Real}; lucky::Bool = false)
    sd = 0
    for lvl in from:0.5:(to - 0.5)
        cost = powerup_cost(lvl; lucky)
        sd += cost.stardust
    end
    return sd
end

function candy(poke::Pokemon, level; as::Species = Species(poke))
    c = cxl = 0
    for lvl in minimum(poke.level):0.5:(level - 0.5)
        cost = powerup_cost(poke, lvl)
        c += cost.candy
        cxl += cost.candyxl
    end
    c += evolution_cost(poke, as)
    return c, cxl
end
function candy((from, to)::Pair{<:Real, <:Real}; kind = :normal)
    c = cxl = 0
    for lvl in from:0.5:(to - 0.5)
        cost = powerup_cost(lvl; kind)
        c += cost.candy
        cxl += cost.candyxl
    end
    return c, cxl
end


function xlrates(level::Real)
    # Probability of getting an XL candy when transferring or walking a buddy
    # https://thesilphroad.com/science/quick-discovery/early-look-buddy-candy-xl-rates, which concludes
    # it's likely the same rate as https://thesilphroad.com/science/guide-candy-xl-part-3-transferring
    return level < 15 ? 1 / 40 :
        level < 20 ? 1 / 8 :
        level < 23 ? 1 / 4 :
        level < 26 ? 3 / 8 :
        level < 31 ? 1 / 2 : 3 / 4
end

"""
    kmcost(poke::Pokemon, target_level_or_cplimit, candy=0, candyxl=0; add_move=true, as=Species(poke))

Estimate the buddy walk distance needed to get enough candy to power up `poke` to `target_level`.
`candy` and `candyxl` are the amounts of candy you own and can devote to powering up.
`target_level_or_cplimit` is interpreted as a battle league CP limit if it is 500 or larger,
otherwise it it interpreted as a target level. Set `add_move=false` if you don't need to purchase
a third move.

Note that for XL candy the distance is probabilistic, and the XL rate for walking increases
with buddy level, maxing out at level 31: see
https://thesilphroad.com/science/quick-discovery/early-look-buddy-candy-xl-rates.
If you need to walk to earn XL candy, the calculation assumes that you power up at least to level 31 as
quickly as you can (e.g., powering up as you earn regular candy, and waiting to evolve and/or purchase a 3rd move
until you reach level 31). Failing to follow this strategy may increase your distance requirement.
Alternatively, your distance requirement may decrease if you walk a different pokemon of the same species that
is already level 31 or higher.
"""
function kmcost(poke::Pokemon, target_level_or_cplimit::Real, candy = 0, candyxl = 0; as::Species = Species(poke), add_move::Bool = true)
    function earn(candy, n)
        if candy >= n
            candy -= n
            return candy, 0
        end
        nf = ceil(Int, n - candy)
        candy = candy - n + nf
        return candy, nf
    end

    target_level = target_level_or_cplimit < 500 ? target_level_or_cplimit : league_max_level(as, poke.ivs, scalarlevel(poke), target_level_or_cplimit)[1]
    nfound = 0.0
    candy, candyxl = convert(Float64, candy), convert(Float64, candyxl)
    lvl = minimum(poke.level)
    cevolve = evolution_cost(poke, as)
    cmove = add_move ? as.thirdMove.candyToUnlock : 0
    while lvl < target_level || !iszero(cevolve) || !iszero(cmove)
        # power up first to earn XL faster
        if lvl < target_level
            cost = powerup_cost(poke, lvl)
            candy_need, candyxl_need = cost.candy, cost.candyxl
            if candy_need > 0
                @assert candyxl_need == 0
                c = min(candy, candy_need)
                candy -= c
                nf = candy_need - c
                nfound += nf
                candyxl += nf * xlrates(lvl)
            elseif candyxl_need > 0
                cxl = min(candyxl, candyxl_need)
                candyxl -= cxl
                nf = (candyxl_need - cxl) / xlrates(lvl)
                candy += nf
                nfound += nf
            end
        elseif !iszero(cevolve)
            candy, nf = earn(candy, cevolve)
            cevolve = 0
            nfound += nf
        else
            @assert !iszero(cmove)
            candy, nf = earn(candy, cmove)
            cmove = 0
            nfound += nf
        end
        lvl += 0.5
    end
    return nfound * as.kmBuddyDistance
end

## Moves

"""
    PvEMove(name::AbstractString) → move

Return the PvE move with the given name. For a fast move, append "_fast" to the name.
"""
PoGOGamemaster.PvEMove(name::AbstractString) = pve_moves[uppercase(name)]

"""
    PvPMove(name::AbstractString) → move

Return the PvP move with the given name. For a fast move, append "_fast" to the name.
"""
PoGOGamemaster.PvPMove(name::AbstractString) = pvp_moves[uppercase(name)]

"""
    fastmoves(species::Species; elite = true) → moves

Return a list of the names of the fast moves that `species` can learn.
By default, include any elite fast moves.
"""
fastmoves(pd::Species; elite::Bool = true) = !elite || pd.eliteQuickMove === nothing ? pd.quickMoves : [pd.quickMoves; pd.eliteQuickMove]

"""
    chargedmoves(species::Species; elite = true) → moves

Return a list of the names of the charged moves that `species` can learn.
By default, include any elite charged moves.
"""
chargedmoves(pd::Species; elite::Bool = true) = !elite || pd.eliteCinematicMove === nothing ? pd.cinematicMoves : [pd.cinematicMoves; pd.eliteCinematicMove]

function validate_moves(fastmove, chargedmoves...; name = nothing, min_score = 2)
    function _validate(movename)
        movename === missing && return missing
        stdname = replace(movename, " " => "_")
        stdname ∈ move_names && return stdname
        name, _ = findnearest(stdname, move_names, Partial(Levenshtein()))
        return name === nothing ? missing :
            Partial(Levenshtein())(stdname, name) <= min_score ? name : missing
    end

    fastmove = _validate(fastmove * "_Fast")
    if fastmove !== missing
        endswith(fastmove, "_Fast") || error("for $name, $fastmove is a charged move, not a fast move")
    end
    chargedmoves = _validate.(chargedmoves)
    return Union{String, Missing}[fastmove, chargedmoves...]
end
validate_moves(; kwargs...) = Union{String, Missing}[]

function learnable_move_counts!(fastmoves, chargedmoves, pd::Species)
    function learnable!(counts, movesets)
        for moveset in movesets
            moveset === nothing && continue
            for move in moveset
                counts[move] = get(counts, move, 0) + 1
            end
        end
        return counts
    end

    learnable!(fastmoves, (pd.quickMoves, pd.eliteQuickMove))
    learnable!(chargedmoves, (pd.cinematicMoves, pd.eliteCinematicMove))
    return fastmoves, chargedmoves
end
learnable_move_counts!(fastmoves, chargedmoves, poke::Pokemon) = learnable_move_counts!(fastmoves, chargedmoves, Species(poke))
function learnable_move_counts(pokes)
    fastmoves = Dict{String, Int}()
    chargedmoves = Dict{String, Int}()
    for poke in pokes
        learnable_move_counts!(fastmoves, chargedmoves, poke)
    end
    return fastmoves, chargedmoves
end
learnable_move_counts() = learnable_move_counts(Iterators.filter(isavailable, values(pokemon)))

learnable_moves() = keys.(learnable_move_counts())
learnable_moves(pokes) = keys.(learnable_move_counts(pokes))

function buffscore(move::PvPMove)
    b = move.buffs
    b === nothing && return 0.0f0
    return (-b.target_attack - b.target_defense + b.self_attack + b.self_defense) * b.buffActivationChance
end

function move_displayname(name, isfast)
    if isfast
        name = replace(name, "_FAST" => "")  # properly handles WATER_GUN_FAST_BLASTOISE
    else
        # Encode buffs/debuffs in move name
        move = PoGOBase.pvp_moves[name]
        s = PoGOBase.buffscore(move)
        if !iszero(s)
            name *= " ($(s > 0 ? "+" : "")$(round(s; digits = 1)))"
        end
    end
    return replace(titlecase(name), "_" => " ")
end

signedstring(val) = val > 0 ? "+" * string(val) : string(val)
