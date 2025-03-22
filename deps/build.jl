using Downloads
using JSON3
using JLD2
using OffsetArrays
using OrderedCollections

using PoGOGamemaster

const move_replacements = Dict{Int, String}()
function fixmove(move, name, fn::Symbol)
    if isa(move[fn], Integer)   # catch bugs in the gamemaster file
        move_replacements[move[fn]] = name
        move = Dict(move)
        move[fn] = name
    end
    return move
end
function fixmove(poke)
    # Palkia_origin and Dialga_origin do not have Spacial Rend and Roar of Time, respectively, in their
    # move lists (presumably because they are not learnable), so we need to add them manually.
    if get(poke, :form, nothing) == "PALKIA_ORIGIN"
        poke = Dict(poke)
        poke[:eliteCinematicMove] = ["SPACIAL_REND"]
    elseif get(poke, :form, nothing) == "DIALGA_ORIGIN"
        poke = Dict(poke)
        poke[:eliteCinematicMove] = ["ROAR_OF_TIME"]
    end
    # Same for the Necrozma forms
    if get(poke, :form, nothing) == "NECROZMA_DUSK_MANE"
        poke = Dict(poke)
        poke[:eliteCinematicMove] = ["SUNSTEEL_STRIKE"]
    elseif get(poke, :form, nothing) == "NECROZMA_DAWN_WINGS"
        poke = Dict(poke)
        poke[:eliteCinematicMove] = ["MOONGEIST_BEAM"]
    end
    # Sometimes the gamemaster file uses integers instead of strings for move IDs, so we need to fix that
    any(m -> isa(m, Integer), get(poke, :quickMoves, ())) ||
        any(m -> isa(m, Integer), get(poke, :cinematicMoves, ())) ||
        any(m -> isa(m, Integer), get(poke, :eliteQuickMove, ())) ||
        any(m -> isa(m, Integer), get(poke, :eliteCinematicMove, ())) || return poke
    poke = Dict(poke)
    poke[:quickMoves] = [get(move_replacements, m, m) for m in poke[:quickMoves]]
    poke[:cinematicMoves] = [get(move_replacements, m, m) for m in poke[:cinematicMoves]]
    if haskey(poke, :eliteQuickMove)
        poke[:eliteQuickMove] = [get(move_replacements, m, m) for m in poke[:eliteQuickMove]]
    end
    if haskey(poke, :eliteCinematicMove)
        poke[:eliteCinematicMove] = [get(move_replacements, m, m) for m in poke[:eliteCinematicMove]]
    end
    return poke
end

# Get the raw data from https://github.com/PokeMiners/game_masters (thanks!)
const gmfile = joinpath(@__DIR__, "gamemaster.json")
# Downloads.download("https://raw.githubusercontent.com/PokeMiners/game_masters/master/latest/latest.json", gmfile)
Downloads.download("https://raw.githubusercontent.com/alexelgt/game_masters/refs/heads/master/GAME_MASTER.json", gmfile)

# Update the rankings tables & meta (all from pvpoke, thanks!)
fnrankings = ("rankings-500.json", "rankings-1500.json", "rankings-2500.json", "rankings-10000.json")
for fn in fnrankings
    url = joinpath("https://raw.githubusercontent.com/pvpoke/pvpoke/master/src/data/rankings/all/overall/", fn)
    Downloads.download(url, fn)
end
fnmeta = (
    "littlegeneral.json" => "meta-500.json", "great.json" => "meta-1500.json", "ultra.json" => "meta-2500.json",
    "master.json" => "meta-10000.json",
)
for (srcname, destname) in fnmeta
    url = joinpath("https://raw.githubusercontent.com/pvpoke/pvpoke/master/src/data/groups/", srcname)
    Downloads.download(url, destname)
end

# Oddly, interpreting the type-effectiveness table seems to require extra information not encoded in the gamemaster file
# The integer is the defender index in the vector of attack effectiveness (i.e., the "column index")
typeorder = ["NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST", "STEEL", "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC", "ICE", "DRAGON", "DARK", "FAIRY"]

# Parse the gamemaster file
gmraw = JSON3.read(read(gmfile, String))
gm = Dict{String, Any}(
    "pvp_moves" => Dict{String, PvPMove}(), "pve_moves" => Dict{String, PvEMove}(),
    "gmax_moves" => Dict{String, String}(),
    "pokemon" => OrderedDict{String, Species}(),
    "friendship" => Pair{Int, Float32}[], "weather" => Dict{String, Vector{String}}(),
    "typeeffectiveness" => Dict{Pair{String, String}, Float32}()
)
gmax_pokemon_id = Dict{String, String}()   # temporary mapping pokemonkey => moveid
gmax_id_type = Dict{String, String}()      # temporary mapping moveid => type
for (i, entry) in enumerate(gmraw)
    key = entry[:templateId]
    m = match(r"^POKEMON_TYPE_([A-Z]*)$", key)
    if m !== nothing
        te = gm["typeeffectiveness"]
        atk = only(m.captures)
        data = entry[:data][:typeEffective][:attackScalar]
        for (def, val) in zip(typeorder, data)
            te[atk => def] = val
        end
    end
    m = match(r"^COMBAT_V\d{4}_MOVE_(.*)", key)
    if m !== nothing
        move = fixmove(entry[:data][:combatMove], only(m.captures), :uniqueId)
        gm["pvp_moves"][only(m.captures)] = PvPMove(move)
        continue
    end
    m = match(r"^V\d{4}_MOVE_(.*)", key)
    if m !== nothing
        move = fixmove(entry[:data][:moveSettings], only(m.captures), :movementId)
        gm["pve_moves"][only(m.captures)] = PvEMove(move)
        continue
    end
    m = match(r"^VN_BM_(\d{3})$", key)
    if m !== nothing
        move = entry[:data][:moveSettings]
        gmax_id_type[move[:movementId]] = move[:pokemonType][(length("POKEMON_TYPE_") + 1):end]
    end
    if key == "SOURDOUGH_MOVE_MAPPING_SETTINGS"  # yum!
        # This maps the gigantamax moves to the pokemon
        data = entry[:data][:sourdoughMoveMappingSettings][:mappings]
        for item in data
            gmax_pokemon_id[item[:pokemonId]] = item[:move]
        end
    end
    m = match(r"^V(\d{4})_POKEMON_(.*)$", key)
    if m !== nothing
        data = entry[:data]
        settings = get(data, :pokemonSettings, nothing)
        if settings !== nothing
            isempty(settings[:stats]) && continue  # unreleased
            dex, key = parse(Int, m.captures[1]), m.captures[2]
            occursin("_COPY_", key) && continue
            try
                poke = Species(fixmove(settings), dex)
                gm["pokemon"][uniquename(poke)] = poke  # not using `key` fixes NIDORAN_(MALE|FEMALE)
                # the FLABEBE/FLORGES line defaults to "red" form, which messes up lineages in the default
                if poke.dex ∈ 669:670
                    if poke.pokemonId ∈ ("FLABEBE", "FLOETTE")
                        eb = only(poke.evolutionBranch)
                        poke.evolutionBranch[1] = PoGOGamemaster.EvolutionBranch(eb.evolution, eb.evolutionItemRequirement, eb.candyCost, eb.evolution, eb.obPurificationEvolutionCandyCost)
                    end
                end
            catch err
                @warn "got an error on $key, see 'broken.txt' for more information"
                # display(settings)
                write("broken.txt", JSON3.write(settings))
                isa(err, MethodError) && err.f === Base.convert && err.args === (BaseStats, nothing) && continue
                throw(err)
            end
            continue
        end
    end
    m = match(r"^FRIENDSHIP_LEVEL_(\d)$", key)
    if m !== nothing
        data = entry[:data][:friendshipMilestoneSettings]
        push!(gm["friendship"], parse(Int, only(m.captures)) => Float32(data[:attackBonusPercentage]))
        continue
    end
    m = match(r"^WEATHER_AFFINITY_(.*)", key)
    if m !== nothing
        data = entry[:data][:weatherAffinities]
        gm["weather"][data[:weatherCondition]] = striptype.(data[:pokemonType])
        continue
    end
    if key == "COMBAT_STAT_STAGE_SETTINGS"
        data = entry[:data][:combatStatStageSettings]
        rng = data[:minimumStatStage]:data[:maximumStatStage]
        gm["buffmultiplier"] = StatMultipliers(
            OffsetArray(copy(data[:attackBuffMultiplier]), rng),
            OffsetArray(copy(data[:defenseBuffMultiplier]), rng)
        )
    elseif key == "COMBAT_SETTINGS"
        gm["combat_settings"] = CombatSettings(entry[:data][:combatSettings])
    elseif key == "PLAYER_LEVEL_SETTINGS"
        gm["combat_power_multiplier"] = copy(entry[:data][:playerLevel][:cpMultiplier])
    elseif key == "POKEMON_UPGRADE_SETTINGS"
        gm["powerups"] = PowerUps(entry[:data][:pokemonUpgrades])
    end
end

for (key, id) in gmax_pokemon_id
    type = gmax_id_type[id]
    gm["gmax_moves"][key] = type
end

jldsave("gamemaster.ser"; gm)

# pvpoke rankings
rankings = Dict{Int, Dict{String, typeof((score = 0.0f0, moveset = ["a"]))}}()
for fn in fnrankings
    m = match(r"rankings-(\d*).json", fn)
    cp = parse(Int, only(m.captures))
    league = valtype(rankings)()
    r = JSON3.read(read(fn, String))
    for entry in r
        league[uppercase(entry[:speciesId])] = (score = entry[:score], moveset = copy(entry[:moveset]))
    end
    rankings[cp] = league
end

jldsave("rankings.ser"; rankings)

meta = Dict{Int, Dict{String, typeof((fastMove = "", chargedMoves = ["a"]))}}()
for (_, fn) in fnmeta
    m = match(r"meta-(\d*).json", fn)
    cp = parse(Int, only(m.captures))
    league = valtype(meta)()
    r = JSON3.read(read(fn, String))
    for entry in r
        league[uppercase(entry[:speciesId])] = (
            fastMove = uppercase(entry[:fastMove]),
            chargedMoves = uppercase.(entry[:chargedMoves]),
        )
    end
    meta[cp] = league
end

jldsave("meta.ser"; meta)
