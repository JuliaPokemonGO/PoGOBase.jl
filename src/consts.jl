const datadir = joinpath(dirname(@__DIR__), "deps")

"""
    joinpath_and_register(path, filename) → fullpath

Return the absolute path and also add it as an `include` dependency, so that the package
gets recompiled if the file `fullpath` is updated.
"""
function joinpath_and_register(args...)
    filename = joinpath(args...)
    include_dependency(filename)
    return filename
end

__gm__ = load_object(joinpath_and_register(datadir, "gamemaster.ser"))
const pvp_moves = __gm__["pvp_moves"]
const pve_moves = __gm__["pve_moves"]
const gmax_moves = __gm__["gmax_moves"]
const move_names = titlecase.(collect(keys(pvp_moves)))
const pokemon = __gm__["pokemon"]
const friendship_bonus = (f = Dict(__gm__["friendship"]); Dict("" => f[0], "good" => f[1], "great" => f[2], "ultra" => f[3], "best" => f[4]))
const buffmultiplier = (sm = __gm__["buffmultiplier"]; @assert sm.attack == sm.defense; sm.attack)
const combat_settings = __gm__["combat_settings"]
const combat_power_multiplier = __gm__["combat_power_multiplier"]
const powerups = __gm__["powerups"]
const typetable = __gm__["typeeffectiveness"]
const weather = __gm__["weather"]

const pokedex = Vector{Species}[]
for (_, pd) in pokemon
    dex = pd.dex[]
    while dex > length(pokedex)
        push!(pokedex, Species[])
    end
    push!(pokedex[dex], pd)
end

const formes = Dict{String, Vector{String}}()
for (key, pd) in pokemon
    endswith(key, "_NORMAL") && continue
    push!(get!(Vector{String}, formes, pd.pokemonId), key)
end

const leagues = load_object(joinpath_and_register(datadir, "rankings.ser"))
const meta = load_object(joinpath_and_register(datadir, "meta.ser"))

"""
    PoGOBase.dex_unavailable

A set of Pokémon IDs that are not available in the game.
"""
const dex_unavilable = Set(
    [
        489; 490; 493; 672; 673; 679; 680; 681; 721; 746; 749; 750;
        771:774; 778; 801; 807; 824:830; 833:847; 850:853; 859:861; 868:869; 871:876; 878:884; 890;
        896; 897; 898; 917; 918; 931:934; 940:959; 963:964; 967:970; 973; 976:978; 981:995; 1001:1008
    ]
)

const region_dex = Dict(
    "Kanto" => 1:151,
    "Johto" => 152:251,
    "Hoenn" => 252:386,
    "Sinnoh" => 387:493,
    "Unova" => 494:649,
    "Kalos" => 650:721,
    "Alola" => 722:809,
    "Galar" => 810:904,
    "Paldea" => 905:1008,
)

# Raid settings by tier (these have changed over time and should periodically be checked for updating)
# https://docs.google.com/spreadsheets/d/1k8X7IJ7tB5z9ZrHs8Le1v64CHrYNYsCVJwLIwlRH5WQ/edit?gid=1693717215#gid=1693717215
# https://www.reddit.com/r/TheSilphRoad/comments/1fkrjxx/analysis_dynamax_raid_mechanics_even_more_move/
# https://pokemongo.fandom.com/wiki/Raid_Battle
const raids = (;
    cm_prob = 0.3,    # chance of throwing a charged move when energy is full
    # boss parameters indexed by tier (tier 4 is mega, 5.5 is elite raids, anything missing is unknown)
    cpm = Dict(1 => 0.5974, 3 => 0.73, 4 => 0.79, 5 => 0.79),
    cpm_shadow = Dict(1 => 0.5974, 3 => 0.76, 5 => 0.82),
    hp = Dict(1 => 600, 2 => 1800, 3 => 3600, 4 => 9000, 5 => 15000, 5.5 => 20000, 6 => 22500),
)

# Max battle settings by tier
# https://docs.google.com/spreadsheets/d/1k8X7IJ7tB5z9ZrHs8Le1v64CHrYNYsCVJwLIwlRH5WQ/edit?gid=1693717215#gid=1693717215
# https://www.reddit.com/r/TheSilphRoad/comments/1fxjzpn/battle_mechanics_raids_and_bugs_information/
const maxbattles = (;
    move_dodgetime_targeted = 2,            # an extra 2s for targeted moves for the dodge window
    meter = 100,
    orb_interval = 15,                      # interval (seconds) between dynamax energy orbs
    orb_energy = 10,                        # dynamax energy gained from an orb
    movepower_bonus_gmax = 100,             # extra attack power for Gigantamax (adds to `movepower` below)
    # boss parameters indexed by tier (tier 6 is G-max)
    cpm = [0.15, 0.38, 0.5, 0.6, 0.7, 0.85], # often these are modified by attack and/or defense multipliers
    hp = [1700, 5000, 10000, 20000, 17500, 60000],   # FIXME
    move_cd = [10, 10, 10, 10, 10, 3],      # gap between moves (+ duration)
    # indexing by "timing level"
    dodge = [0.5, 0.6, 0.7],                # fraction of targeted attack damage that is dodged (depending on timing of dodge)
    # indexing by number of helper icons at start of battle
    helper_bonus = [0.1f0, 0.15f0, 0.188f0, 0.2f0],
    # challenger max moves (indexed by level)
    movepower = [250, 300, 350],            # max attack
    shield = [20, 40, 60],                  # max guard, amount of hp absorbed (per level)
    heal = [0.08, 0.12, 0.16],              # max heal as a fraction of total recipient hp (per level)
)

struct DustReward
    dust::Int
    time::Float64   # in minutes
    coins::Int
    limit::Int      # per day
end
DustReward(dust, time, coins) = DustReward(dust, time, coins, typemax(Int))

const dust_table = [
    "catch" => DustReward(100, 1 / 3, 0.0),
    "gift" => DustReward(200, 1 / 3, 0.0, 20),
    "raid" => DustReward(500, 15, 85),                  # except for one free raid
    "gymberries" => DustReward(20, 1 / 3, 0.0, 10),       # ~20 berries earned per 5min spinning (15s/berry), 5s per feed
    "pvp" => DustReward(4500, 15, 0.0, 5),
    "pvppremium" => DustReward(9000 * 1.5, 15, 165, 5),       # premium battle pass + starpiece
    "pvppremium4x" => DustReward(18000 * 1.5, 15, 165, 5),    #    "
    "egghatch" => DustReward(1800, 0.0, 100, 18),             # estimated based on frequency of 2/5/7/10/12km eggs
    "grunts" => DustReward(500, 2, 0.0),
]
