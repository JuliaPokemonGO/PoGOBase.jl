module PoGOGamemaster

# This module bridges between scraping the gamemaster file and the "user level" PoGOBase package
# Names of struct fields are taken directly from the gamemaster file

using StructTypes

dflt(jsonobj, key) = get(jsonobj, key, nothing)

export CombatSettings, StatMultipliers, AbstractMove, PvPMove, PvEMove, BaseStats, EvolutionBranch
export MegaEvolution, MegaOverride, ThirdMoveCost, Shadow, PowerUps, Species
export striptype, uniquename, coreproperties, type, ispvp, duration, power

struct CombatSettings
    roundDurationSeconds::Float64
    turnDurationSeconds::Float64
    minigameDurationSeconds::Float64
    sameTypeAttackBonusMultiplier::Float64
    fastAttackBonusMultiplier::Float64
    chargeAttackBonusMultiplier::Float64
    defenseBonusMultiplier::Float64
    minigameBonusBaseMultiplier::Float64
    minigameBonusVariableMultiplier::Float64
    maxEnergy::Float64
    defenderMinigameMultiplier::Float64
    changePokemonDurationSeconds::Float64
    minigameSubmitScoreDurationSeconds::Float64
    quickSwapCooldownDurationSeconds::Float64
    shadowPokemonAttackBonusMultiplier::Float64
    shadowPokemonDefenseBonusMultiplier::Float64
    purifiedPokemonAttackMultiplierVsShadow::Float64
end
CombatSettings(jsonobj) = CombatSettings(
    jsonobj[:roundDurationSeconds], jsonobj[:turnDurationSeconds],
    jsonobj[:minigameDurationSeconds], jsonobj[:sameTypeAttackBonusMultiplier],
    jsonobj[:fastAttackBonusMultiplier], jsonobj[:chargeAttackBonusMultiplier],
    jsonobj[:defenseBonusMultiplier], jsonobj[:minigameBonusBaseMultiplier],
    jsonobj[:minigameBonusVariableMultiplier], jsonobj[:maxEnergy],
    jsonobj[:defenderMinigameMultiplier], jsonobj[:changePokemonDurationSeconds],
    jsonobj[:minigameSubmitScoreDurationSeconds], jsonobj[:quickSwapCooldownDurationSeconds],
    jsonobj[:shadowPokemonAttackBonusMultiplier], jsonobj[:shadowPokemonDefenseBonusMultiplier],
    jsonobj[:purifiedPokemonAttackMultiplierVsShadow]
)

StructTypes.StructType(::Type{CombatSettings}) = StructTypes.Struct()

struct StatMultipliers{V <: AbstractVector}
    attack::V
    defense::V
end

striptype(str::AbstractString) = startswith(str, "POKEMON_TYPE_") ? str[14:end] : str
striptype(::Nothing) = nothing

duration(::Nothing) = 0.0
uniquename(::Nothing) = "nothing"

abstract type AbstractMove end

struct Buffs
    attackerAttackStatStageChange::Int8
    attackerDefenseStatStageChange::Int8
    targetAttackStatStageChange::Int8
    targetDefenseStatStageChange::Int8
    buffActivationChance::Float32
end
Buffs(jsonobj) = Buffs(
    get(jsonobj, :attackerAttackStatStageChange, 0),
    get(jsonobj, :attackerDefenseStatStageChange, 0),
    get(jsonobj, :targetAttackStatStageChange, 0),
    get(jsonobj, :targetDefenseStatStageChange, 0),
    get(jsonobj, :buffActivationChance, 0.0f0)
)

function Base.getproperty(buffs::Buffs, fieldname::Symbol)
    if fieldname ∈ (:self_attack, :attackerAttackStatStageChange)
        return getfield(buffs, :attackerAttackStatStageChange)
    elseif fieldname ∈ (:self_defense, :attackerDefenseStatStageChange)
        return getfield(buffs, :attackerDefenseStatStageChange)
    elseif fieldname ∈ (:target_attack, :targetAttackStatStageChange)
        return getfield(buffs, :targetAttackStatStageChange)
    elseif fieldname ∈ (:target_defense, :targetDefenseStatStageChange)
        return getfield(buffs, :targetDefenseStatStageChange)
    elseif fieldname ∈ (:chance, :buffActivationChance)
        return getfield(buffs, :buffActivationChance)
    else
        error("unknown field $fieldname")
    end
end

function Base.show(io::IO, buffs::Buffs)
    printed = Ref(false)
    function showbuff(displayname, fieldname)
        if printed[]
            print(io, ", ")
        end
        printed[] = false
        return if getproperty(buffs, fieldname) != 0
            print(io, displayname, "=", getproperty(buffs, fieldname))
            printed[] = true
        end
    end

    print(io, "Buffs(")
    showbuff("self_attack", :attackerAttackStatStageChange)
    showbuff("self_defense", :attackerDefenseStatStageChange)
    showbuff("target_attack", :targetAttackStatStageChange)
    showbuff("target_defense", :targetDefenseStatStageChange)
    printed[] && print(io, ", ")
    print(io, "chance=", 100 * buffs.buffActivationChance, "%")
    return print(io, ")")
end

struct PvPMove <: AbstractMove
    uniqueId::String
    type::String
    power::Float32
    vfxName::String
    durationTurns::Int8
    energyDelta::Int8
    buffs::Union{Buffs, Nothing}

    PvPMove(uniqueId, type, power, vfxName, durationTurns, energyDelta, buffs) =
        new(uniqueId, striptype(type), something(power, 0.0f0), vfxName, something(durationTurns, 0), something(energyDelta, 0), buffs)
end
function PvPMove(jsonobj)
    buffs = get(jsonobj, :buffs, nothing)
    if buffs !== nothing
        buffs = Buffs(buffs)
    end
    return PvPMove(jsonobj[:uniqueId], jsonobj[:type], dflt(jsonobj, :power), jsonobj[:vfxName], dflt(jsonobj, :durationTurns), dflt(jsonobj, :energyDelta), buffs)
end

uniquename(move::PvPMove) = move.uniqueId
type(move::PvPMove) = move.type
ispvp(::PvPMove) = true
duration(move::PvPMove) = (move.durationTurns + 1) * 0.5   # they seem to store turns-1
power(move::AbstractMove) = move.power

struct PvEMove <: AbstractMove
    movementId::String
    pokemonType::String
    power::Float32
    vfxName::String
    durationMs::Int16
    damageWindowStartMs::Int16
    damageWindowEndMs::Int16
    energyDelta::Int8

    PvEMove(movementId, pokemonType, power, vfxName, durationMs, damageWindowStartMs, damageWindowEndMs, energyDelta) =
        new(movementId, striptype(pokemonType), something(power, NaN32), vfxName, durationMs, damageWindowStartMs, damageWindowEndMs, something(energyDelta, 0))
end
PvEMove(jsonobj) = PvEMove(
    jsonobj[:movementId], jsonobj[:pokemonType], dflt(jsonobj, :power), jsonobj[:vfxName],
    jsonobj[:durationMs], get(jsonobj, :damageWindowStartMs, -1), jsonobj[:damageWindowEndMs], dflt(jsonobj, :energyDelta)
)
uniquename(move::PvEMove) = move.movementId
type(move::PvEMove) = move.pokemonType
ispvp(::PvEMove) = false
duration(move::PvEMove) = move.durationMs / 1000
power(move::PvEMove) = (p = move.power; isnan(p) ? zero(p) : p)

struct PowerUps
    upgradesPerLevel::Int
    allowedLevelsAbovePlayer::Int
    candyCost::Vector{Int}
    stardustCost::Vector{Int}
    shadowStardustMultiplier::Float64
    shadowCandyMultiplier::Float64
    purifiedStardustMultiplier::Float64
    purifiedCandyMultiplier::Float64
    maxNormalUpgradeLevel::Float64
    xlCandyMinPlayerLevel::Float64
    xlCandyCost::Vector{Int}
    # obMaxMegaLevel::Float64
end
PowerUps(jsonobj) = PowerUps(
    jsonobj[:upgradesPerLevel], jsonobj[:allowedLevelsAbovePlayer], jsonobj[:candyCost], jsonobj[:stardustCost],
    jsonobj[:shadowStardustMultiplier], jsonobj[:shadowCandyMultiplier], jsonobj[:purifiedStardustMultiplier],
    jsonobj[:purifiedCandyMultiplier], jsonobj[:maxNormalUpgradeLevel], jsonobj[:xlCandyMinPlayerLevel],
    jsonobj[:xlCandyCost]
) # , jsonobj[:obMaxMegaLevel])

struct BaseStats
    baseStamina::Int16
    baseAttack::Int16
    baseDefense::Int16
end

Base.Tuple(bs::BaseStats) = (bs.baseAttack, bs.baseDefense, bs.baseStamina)
Tuple{Int16, Int16, Int16}(bs::BaseStats) = Tuple(bs)
BaseStats(stats::Tuple{I, I, I} where {I <: Integer}) = BaseStats(stats[3], stats[1], stats[2])

Base.convert(::Type{BaseStats}, stats::BaseStats) = stats
Base.convert(::Type{BaseStats}, jsonobj) = BaseStats(jsonobj[:baseStamina], jsonobj[:baseAttack], jsonobj[:baseDefense])

Base.show(io::IO, bs::BaseStats) = show(io, Tuple(bs))

abstract type Evolution end

struct EvolutionBranch <: Evolution
    evolution::String
    evolutionItemRequirement::Union{String, Nothing}
    candyCost::Int16
    form::Union{String, Nothing}
    obPurificationEvolutionCandyCost::Union{Int16, Nothing}
end
EvolutionBranch(jsonobj) = EvolutionBranch(
    jsonobj[:evolution], dflt(jsonobj, :evolutionItemRequirement), jsonobj[:candyCost],
    dflt(jsonobj, :form), dflt(jsonobj, :obPurificationEvolutionCandyCost)
)

struct EvolutionBranchSlim <: Evolution
    evolution::String
    evolutionItemRequirement::Union{String, Nothing}
end
EvolutionBranchSlim(jsonobj) = EvolutionBranchSlim(jsonobj[:evolution], dflt(jsonobj, :evolutionItemRequirement))

struct MegaEvolution <: Evolution
    temporaryEvolution::String
    temporaryEvolutionEnergyCost::Int16
    temporaryEvolutionEnergyCostSubsequent::Int16
end
MegaEvolution(jsonobj) = MegaEvolution(jsonobj[:temporaryEvolution], jsonobj[:temporaryEvolutionEnergyCost], jsonobj[:temporaryEvolutionEnergyCostSubsequent])

StructTypes.StructType(::Type{Evolution}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{Evolution}, obj)
    sdict = Dict(Symbol(key) => value for (key, value) in obj)
    if haskey(obj, "candyCost")
        return StructTypes.constructfrom(EvolutionBranch, sdict)
    end
    if haskey(obj, "temporaryEvolutionEnergyCost")
        return StructTypes.constructfrom(MegaEvolution, sdict)
    end
    return StructTypes.constructfrom(EvolutionBranchSlim, sdict)
end
Base.convert(::Type{Evolution}, ev::Evolution) = ev
function Base.convert(::Type{Evolution}, jsonobj)
    if haskey(jsonobj, :candyCost)
        return EvolutionBranch(jsonobj)
    end
    if haskey(jsonobj, :temporaryEvolutionEnergyCost)
        return MegaEvolution(jsonobj)
    end
    return EvolutionBranchSlim(jsonobj)
end

struct MegaOverride
    tempEvoId::String
    stats::BaseStats
    typeOverride1::String
    typeOverride2::Union{String, Nothing}

    MegaOverride(tempEvoId, stats, type1, type2) = new(tempEvoId, stats, striptype(type1), striptype(type2))
    function MegaOverride(::Nothing, ::Nothing, ::Nothing, ::Nothing)
        @warn "parsing error on MegaOverride"
        return new("", BaseStats(0, 0, 0), "", nothing)
    end
end
MegaOverride(jsonobj) = MegaOverride(jsonobj[:tempEvoId], jsonobj[:stats], jsonobj[:typeOverride1], dflt(jsonobj, :typeOverride2))

uniquename(megaev::MegaOverride) = megaev.tempEvoId
type(megaev::MegaOverride) = megaev.typeOverride2 === nothing ? (megaev.typeOverride1,) : (megaev.typeOverride1, megaev.typeOverride2)

struct TempEvoOverrides
    evos::Union{Vector{MegaOverride}, Nothing}
end
Base.convert(::Type{TempEvoOverrides}, teo::TempEvoOverrides) = teo
Base.convert(::Type{TempEvoOverrides}, ::Nothing) = TempEvoOverrides(nothing)
Base.convert(::Type{TempEvoOverrides}, jsonobj) = TempEvoOverrides([MegaOverride(item) for item in jsonobj if haskey(item, :tempEvoId)])
Base.iterate(teo::TempEvoOverrides) = teo.evos === nothing ? nothing : iterate(teo.evos)
Base.iterate(teo::TempEvoOverrides, state) = iterate(teo.evos, state)
Base.filter!(f, teo::TempEvoOverrides) = filter!(f, teo.evos)
Base.:(==)(teo1::TempEvoOverrides, teo2::TempEvoOverrides) = teo1.evos == teo2.evos
const hash_temp_evo_overrides = Int === Int64 ? 0x0d82d0be3bc5bfc9 : 0xb12a2e28
Base.hash(teo::TempEvoOverrides, h::UInt) = hash(teo.evos, hash(hash_temp_evo_overrides, h))

StructTypes.StructType(::Type{TempEvoOverrides}) = StructTypes.CustomStruct()
function StructTypes.construct(::Type{TempEvoOverrides}, obj)
    megas = MegaOverride[]
    for item in obj
        if haskey(item, "tempEvoId")
            sdict = Dict(Symbol(key) => value for (key, value) in item)
            sdict[:stats] = Dict(Symbol(key) => value for (key, value) in sdict[:stats])
            push!(megas, StructTypes.constructfrom(MegaOverride, sdict))
        end
    end
    return TempEvoOverrides(isempty(megas) ? nothing : megas)
end

struct ThirdMoveCost
    stardustToUnlock::Int32
    candyToUnlock::Int32    # sentinel values overflow Int16

    ThirdMoveCost(stardustToUnlock, candyToUnlock) = new(something(stardustToUnlock, -1), candyToUnlock)
end
Base.convert(::Type{ThirdMoveCost}, tmc::ThirdMoveCost) = tmc
Base.convert(::Type{ThirdMoveCost}, jsonobj) = ThirdMoveCost(get(jsonobj, :stardustToUnlock, -1), jsonobj[:candyToUnlock])

struct Shadow
    purificationStardustNeeded::Int32
    purificationCandyNeeded::Int8
    purifiedChargeMove::String
    shadowChargeMove::String
end
Base.convert(::Type{Shadow}, sh::Shadow) = sh
Base.convert(::Type{Shadow}, jsonobj) = Shadow(
    jsonobj[:purificationStardustNeeded], jsonobj[:purificationCandyNeeded],
    jsonobj[:purifiedChargeMove], jsonobj[:shadowChargeMove]
)

struct Species
    pokemonId::String
    dex::Union{Int16, Nothing}
    type::String
    type2::Union{String, Nothing}
    stats::BaseStats
    quickMoves::Union{Vector{String}, Nothing}   # Nothing indicates a wide variety of moves (e.g., Smeargle)
    cinematicMoves::Union{Vector{String}, Nothing}
    pokemonClass::Union{String, Nothing}
    familyId::String
    kmBuddyDistance::Float32
    form::Union{String, Int, Nothing}             # some Pikachu are designated by number
    parentPokemonId::Union{String, Nothing}
    evolutionBranch::Union{Vector{Evolution}, Nothing}
    tempEvoOverrides::TempEvoOverrides
    thirdMove::ThirdMoveCost
    shadow::Union{Shadow, Nothing}
    eliteQuickMove::Union{Vector{String}, Nothing}
    eliteCinematicMove::Union{Vector{String}, Nothing}
    buddyWalkedMegaEnergyAward::Union{Int16, Nothing}

    Species(
        pokemonId, dex, type, type2, stats, quickMoves, cinematicMoves, pokemonClass, familyId, kmBuddyDistance,
        form, parentPokemonId, evolutionBranch, tempEvoOverrides, thirdMove, shadow, eliteQuickMove, eliteCinematicMove, buddyWalkedMegaEnergyAward
    ) =
        new(
        pokemonId, dex, striptype(type), striptype(type2), stats, quickMoves, cinematicMoves, pokemonClass, familyId, kmBuddyDistance,
        form, parentPokemonId, evolutionBranch, tempEvoOverrides, thirdMove, shadow, eliteQuickMove, eliteCinematicMove, buddyWalkedMegaEnergyAward
    )
    Species(jsonobj, dex) = Species(
        jsonobj[:pokemonId], dex, jsonobj[:type], dflt(jsonobj, :type2), jsonobj[:stats],
        dflt(jsonobj, :quickMoves), dflt(jsonobj, :cinematicMoves), dflt(jsonobj, :pokemonClass), jsonobj[:familyId],
        jsonobj[:kmBuddyDistance],
        dflt(jsonobj, :form), dflt(jsonobj, :parentPokemonId), dflt(jsonobj, :evolutionBranch), dflt(jsonobj, :tempEvoOverrides),
        jsonobj[:thirdMove], dflt(jsonobj, :shadow), dflt(jsonobj, :eliteQuickMove),
        dflt(jsonobj, :eliteCinematicMove), dflt(jsonobj, :buddyWalkedMegaEnergyAward)
    )
end
function type(pd::Species)
    t2 = pd.type2
    return t2 === nothing ? (pd.type,) : (pd.type, t2)
end

uniquename(pd::Species) = pd.form === nothing ? pd.pokemonId : string(pd.form)
uniquename(ebr::EvolutionBranch) = ebr.form === nothing ? ebr.evolution : ebr.form
canonical_form(pokemonId, ::Nothing) = pokemonId
canonical_form(pokemonId, form::String) = endswith(form, "_NORMAL") ? pokemonId : form
coreproperties(pd::Species) = (
    type = pd.type, type2 = pd.type2, stats = pd.stats,
    quickMoves = pd.quickMoves, cinematicMoves = pd.cinematicMoves,
    eliteQuickMove = pd.eliteQuickMove, eliteCinematicMove = pd.eliteCinematicMove,
)

function Base.show(io::IO, pd::Species)
    print(io, uniquename(pd))
    print(io, " (", pd.type)
    if pd.type2 !== nothing
        print(io, '/', pd.type2)
    end
    print(io, "): ", pd.stats)
    print(io, "; Fast: ", pd.quickMoves)
    print(io, "; Charged: ", pd.cinematicMoves)
    if pd.eliteQuickMove !== nothing
        print(io, "; Elite fast: ", pd.eliteQuickMove)
    end
    return if pd.eliteCinematicMove !== nothing
        print(io, "; Elite charged: ", pd.eliteCinematicMove)
    end
end

# function Base.:(==)(pd1::Species, pd2::Species)
#     return pd1.pokemonId == pd2.pokemonId &&
#         pd1.dex == pd2.dex &&
#         pd1.type == pd2.type &&
#         pd1.type2 == pd2.type2 &&
#         pd1.stats == pd2.stats &&
#         pd1.quickMoves == pd2.quickMoves &&
#         pd1.cinematicMoves == pd2.cinematicMoves &&
#         pd1.pokemonClass == pd2.pokemonClass &&
#         pd1.familyId == pd2.familyId &&
#         pd1.kmBuddyDistance == pd2.kmBuddyDistance &&
#         canonical_form(pd1.pokemonId, pd1.form) == canonical_form(pd2.pokemonId, pd2.form) &&
#         pd1.parentPokemonId == pd2.parentPokemonId &&
#         pd1.evolutionBranch == pd2.evolutionBranch &&
#         pd1.tempEvoOverrides == pd2.tempEvoOverrides &&
#         pd1.thirdMove == pd2.thirdMove &&
#         pd1.shadow == pd2.shadow &&
#         pd1.eliteQuickMove == pd2.eliteQuickMove &&
#         pd1.eliteCinematicMove == pd2.eliteCinematicMove &&
#         pd1.buddyWalkedMegaEnergyAward == pd2.buddyWalkedMegaEnergyAward
# end
# const hash_Species = Int === Int64 ? 0xa88fda9d33a54252 : 0x1c5447f2
# function Base.hash(pd::Species, h::UInt)
#     return hash(pd.pokemonId, hash(pd.dex, hash(pd.type, hash(pd.type2, hash(pd.stats, hash(pd.quickMoves, hash(pd.cinematicMoves,
#            hash(pd.pokemonClass, hash(pd.familyId, hash(pd.kmBuddyDistance, hash(canonical_form(pd.pokemonId, pd.form),
#            hash(pd.parentPokemonId, hash(pd.evolutionBranch, hash(pd.tempEvoOverrides, hash(pd.thirdMove, hash(pd.shadow,
#            hash(pd.eliteQuickMove, hash(pd.eliteCinematicMove, hash(pd.buddyWalkedMegaEnergyAward, hash(hash_Species, h))))))))))))))))))))
# end

end # module PoGOGamemaster
