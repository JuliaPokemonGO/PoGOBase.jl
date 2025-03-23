module PoGOBase

using StringDistances
using OffsetArrays
using JLD2
using PoGOGamemaster
using OrderedCollections
using Unitful

export Pokemon, Species, PvEMove, PvPMove, MaxAttack, BossFT
export matching_pokemon, only_pokemon, uniquename, eachpokemon
export base_stats, stats, combat_power, hp, statproduct
export megaevolve, purify, baby, lineage_ids
export damage
export league_max_level, league_catch_cp, statproduct_league, statproducts_league, best_for_league, statranks_league
export candy, stardust, evolution_cost, kmcost

const unavail_shown = Set{Int}()   # in each session, warn about updating dex_unavailable only once per dex entry

include("consts.jl")
include("types.jl")
include("utils.jl")
include("api.jl")
include("metrics.jl")
include("damage.jl")

function __init__()
    return Unitful.register(ExtraUnits)
end

end # module PoGOBase
