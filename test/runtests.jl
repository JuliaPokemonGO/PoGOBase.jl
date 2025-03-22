using PoGOBase
using Dates   # for today()
using Unitful
using Test

@testset "Name searches" begin
    @test uniquename(only(matching_pokemon("Vulpix"; complete = true))) == "VULPIX"
    pds = matching_pokemon("Vulpix")
    @test length(pds) == 2
    nms = map(uniquename, pds)
    @test "VULPIX" ∈ nms
    @test "VULPIX_ALOLA" ∈ nms
    @test isempty(matching_pokemon("Volpix"))
    @test matching_pokemon("Volpix"; tol = 0.2) == pds
    @test uniquename(only(matching_pokemon("Volpix"; tol = 0.2, complete = true))) == "VULPIX"

    pds = matching_pokemon("Nidoran")
    nms = map(uniquename, pds)
    @test "NIDORAN_FEMALE" ∈ nms
    @test "NIDORAN_MALE" ∈ nms

    pd = only_pokemon("Charizard"; exact = true)
    @test uniquename(pd) == "CHARIZARD"
    @test_throws "GOURGEIST_LARGE" only_pokemon("Gourgeist")
    pd = only_pokemon("GOURGEIST_LARGE")
    @test uniquename(pd) == "GOURGEIST_LARGE"
    @test_throws "_BLUE" only_pokemon("Florges")
    @test uniquename(only_pokemon("Florges"; equiv = true)) == "FLORGES"
end

@testset "Matching based on types" begin
    @test uniquename(only_pokemon("Voltorb", "ELECTRIC")) == "VOLTORB"
    @test uniquename(only_pokemon("Voltorb", "ELECTRIC/GRASS")) == "VOLTORB_HISUIAN"
    @test_throws "multiple matching pokemon were found" only_pokemon("Nidoran", "POISON")
end

@testset "Evolutions" begin
    # Zubat, Golbat, & Crobat have a "clean" linkage graph in the gamemaster
    zubat, golbat, crobat = only_pokemon("Zubat"), only_pokemon("Golbat"), only_pokemon("Crobat")
    @test PoGOBase.can_evolve_to(zubat, golbat)
    @test PoGOBase.can_evolve_to(zubat, crobat)
    @test PoGOBase.can_evolve_to(golbat, crobat)
    @test !PoGOBase.can_evolve_to(golbat, zubat)
    @test !PoGOBase.can_evolve_to(crobat, zubat)
    @test !PoGOBase.can_evolve_to(crobat, golbat)
    @test PoGOBase.baby(crobat) == PoGOBase.baby(golbat) == zubat
    @test PoGOBase.adults(zubat) == PoGOBase.adults(golbat) == [crobat]
    # In the gamemaster, obstagoon points all the way back to zigzagoon, and doesn't clearly distinguish
    # via backedges between the galarian and normal forme. The forward edges do make this distinction,
    # so make sure we exploit them.
    obstagoon, linooneg, zigzagoong = only_pokemon("Obstagoon"), only_pokemon("Linoone_galarian"), only_pokemon("Zigzagoon_galarian")
    linoone, zigzagoon = only_pokemon("Linoone"; complete = true), only_pokemon("Zigzagoon"; complete = true)
    @test !PoGOBase.can_evolve_to(zubat, obstagoon)
    @test !PoGOBase.can_evolve_to(zigzagoon, obstagoon)
    @test  PoGOBase.can_evolve_to(zigzagoong, obstagoon)
    @test  PoGOBase.can_evolve_to(zigzagoong, linooneg)
    @test  PoGOBase.can_evolve_to(linooneg, obstagoon)
    @test !PoGOBase.can_evolve_to(linooneg, zigzagoong)
    @test PoGOBase.baby(obstagoon) == zigzagoong
    @test PoGOBase.adults(zigzagoong) == [obstagoon]
    @test PoGOBase.adults(zigzagoon) == [linoone]
    @test PoGOBase.is_adult(obstagoon)
    @test !PoGOBase.is_adult(linooneg)
    # Check that we handle multiple evolution targets
    poliwag, poliwhirl, poliwrath, politoed = only_pokemon("poliwag"), only_pokemon("poliwhirl"), only_pokemon("poliwrath"), only_pokemon("politoed")
    @test PoGOBase.baby(poliwhirl) == PoGOBase.baby(poliwrath) == PoGOBase.baby(politoed) == poliwag
    @test Set(PoGOBase.adults(poliwag)) == Set([poliwrath, politoed])
    @test PoGOBase.can_evolve_to(poliwag, poliwhirl)
    @test PoGOBase.can_evolve_to(poliwag, poliwrath)
    @test PoGOBase.can_evolve_to(poliwag, politoed)

    haunter, gengar = only_pokemon("haunter"), only_pokemon("gengar"; exact = true)
    @test Set(PoGOBase.adults(haunter)) == Set([gengar])
    @test PoGOBase.is_adult(gengar)   # has a mega evolution
end

@testset "HP, CP, and level" begin
    @test PoGOBase.base_stats("Venusaur") == (198, 189, 190)
    pds = collect(values(PoGOBase.pokemon))
    for _ in 1:10
        pd = pds[rand(1:length(pds))]
        ivs = (rand(0:15), rand(0:15), rand(0:15))
        for lvl in 1.0:0.5:51.0
            a, d, h = @inferred(PoGOBase.stats(pd, ivs, lvl))
            @test isa(a, AbstractFloat)
            l = @inferred(Union{Float64, typeof(1.0:0.5:2.0)}, PoGOBase.level(pd, ivs; hp = max(10, h)))
            @test lvl ∈ l
            # test that l is "tight", meaning that lower or higher levels are inconsistent with h
            if minimum(l) > 1.0
                @test PoGOBase.stats(pd, ivs, minimum(l) - 0.5)[3] < h
            end
            if maximum(l) < 51.0
                @test PoGOBase.stats(pd, ivs, maximum(l) + 0.5)[3] > h
            end

            cp = @inferred(PoGOBase.combat_power(pd, ivs, lvl))
            l = PoGOBase.level(pd, ivs; cp)
            @test lvl ∈ l
            if cp > 10 && minimum(l) > 1.0
                @test PoGOBase.combat_power(pd, ivs, minimum(l) - 0.5) < cp
            end
            if maximum(l) < 51.0
                @test PoGOBase.combat_power(pd, ivs, maximum(l) + 0.5) > cp
            end
        end
    end
    # Interesting special cases
    pd = only_pokemon("Shedinja")
    @test PoGOBase.level(pd, (0, 0, 0); hp = 10) == 1.0:0.5:51.0
    @test PoGOBase.level(pd, (0, 0, 0); cp = 79) == 38.0:0.5:38.5
    hps = PoGOBase.hp(pd, (12, 15, 15), 26.0:0.5:33.5)
    @test first(hps) == 10
    @test last(hps) == 12
    @test all(==(11), hps[(begin + 1):(end - 1)])
    pd = only(only_pokemon("Venusaur").tempEvoOverrides)
end

@testset "Pokemon individuals" begin
    @test Pokemon("Venusaur", 20.0, (15, 15, 15)) == Pokemon("VENUSAUR_NORMAL", 20.0, (15, 15, 15))
    @test isequal(Pokemon("Venusaur", 20.0, (15, 15, 15)), Pokemon("VENUSAUR_NORMAL", 20.0, (15, 15, 15)))
    @test hash(Pokemon("Venusaur", 20.0, (15, 15, 15))) == hash(Pokemon("VENUSAUR_NORMAL", 20.0, (15, 15, 15)))

    poke = Pokemon("Venusaur", 20.0, (15, 15, 15))
    @test PoGOBase.combat_power(poke) == 1554
    @test PoGOBase.hp(poke) === 122
    stats = PoGOBase.stats(poke)
    @test round(stats[1]; digits = 1) == 127.2
    @test 121.8 <= round(stats[2]; digits = 1) <= 121.9
    @test stats[3] == 122
    @test PoGOBase.stats(poke, 30)[3] == 149
    @test PoGOBase.stat_product(poke) == prod(stats) / 1000
    @test PoGOBase.stat_product(Species(poke), poke.ivs) ≈ 8907.66  # with CPM=1
    @test PoGOBase.raid_boss_stats("Venusaur", 3) == (155.49, 148.92, 3600)
    @test sprint(show, poke) == "Venusaur; CP: 1554; level: 20.0; IVs: (15, 15, 15)"
    @test PoGOBase.baby(poke) == only_pokemon("Bulbasaur"; complete = true)
    poke = Pokemon("Venusaur", 21, (0, 14, 11); name = "Gr8Ven")
    @test sprint(show, poke) == "Gr8Ven (Venusaur); CP: 1498; level: 21.0; IVs: (0, 14, 11)"
    @test PoGOBase.type(poke) == ("GRASS", "POISON")
    @test !PoGOBase.isshadow_default(poke)
    @test !PoGOBase.mega_default(poke)
    poke = Pokemon("Venusaur", 20.0, (15, 15, 15); islucky = true)
    @test poke.islucky
    @test sprint(show, poke; context = :color => true) == "\e[33mVenusaur\e[39m; CP: 1554; level: 20.0; IVs: (15, 15, 15)"
    poke = Pokemon("Venusaur", 20.0, (15, 15, 15); mutation = 'S')
    @test PoGOBase.isshadow_default(poke)
    @test sprint(show, poke; context = :color => true) == "\e[90mVenusaur\e[39m; CP: 1554; level: 20.0; IVs: (15, 15, 15)"
    poke = Pokemon("Venusaur", 20.0, (15, 15, 15); mega = true)
    @test PoGOBase.mega_default(poke)
    @test sprint(show, poke; context = :color => true) == "Venusaur (Mega Venusaur); CP: 2113; level: 20.0; IVs: (15, 15, 15)"
    poke = Pokemon("charizard", 20.0, (15, 15, 15); mega = 'Y')
    @test PoGOBase.mega_default(poke) == 'Y'
    @test sprint(show, poke; context = :color => true) == "Charizard (Mega Charizard Y); CP: 2546; level: 20.0; IVs: (15, 15, 15)"

    poke = Pokemon("Ralts", 15, (8, 12, 10))
    @test Set(PoGOBase.adults(poke)) == Set([only_pokemon("Gardevoir"), only_pokemon("Gallade")])
    @test !PoGOBase.is_adult(poke)
    @test PoGOBase.adult_ids([poke]) == Set(["GARDEVOIR", "GALLADE"])
    @test PoGOBase.lineage_ids(poke) == PoGOBase.lineage_ids([poke]) == sort!(["RALTS", "KIRLIA", "GARDEVOIR", "GALLADE"])
    @test PoGOBase.can_evolve_to(poke, "KIRLIA")

    poke = Pokemon("VULPIX", (11, 14, 5); cp = 419, name = "Vulpix")
    @test uniquename(poke) == "VULPIX"
    @test PoGOBase.type(poke) == ("FIRE",)

    poke = Pokemon("VENUSAUR"; raid_tier = 3)
    @test PoGOBase.combat_power(poke) == 18253
    @test PoGOBase.hp(poke) == 3600
    @test sprint(show, poke) == "Venusaur; CP: 18253; HP: 3600 (raid tier 3.0)"
    @test !PoGOBase.isshadow_default(poke)

    poke = Pokemon("charizard"; mega = 'Y', raid_tier = 4)
    @test base_stats(poke) == (319, 212, 186)
    @test combat_power(poke) == 47739
    @test PoGOBase.type(poke) == ("FIRE", "FLYING")
    @test PoGOBase.stats(poke)[3] == PoGOBase.raids.hp[poke.raid_tier]
    poke = Pokemon("charizard"; mega = 'X', raid_tier = 4)
    @test base_stats(poke) == (273, 213, 186)
    @test combat_power(poke) == 41255
    @test PoGOBase.type(poke) == ("FIRE", "DRAGON")

    poke = Pokemon("vulpix_alola", (8, 15, 15); name = "Chilly", cp = 567)
    @test combat_power(poke) == 567
    @test PoGOBase.type(poke) == ("ICE",)

    poke = Pokemon(only_pokemon("rattata"; exact = true), (12, 12, 10); cp = 155, mutation = 'S')
    @test combat_power(poke) == 155
    @test PoGOBase.isshadow(poke)
    @test PoGOBase.isshadow_default(poke)
    @test sprint(show, poke; context = :color => true) == "\e[90mRattata\e[39m; CP: 155; level: 8.0; IVs: (12, 12, 10)"

    poke = Pokemon("ampharos", 40, (15, 15, 15); mega = true)
    @test PoGOBase.type(poke) == ("ELECTRIC", "DRAGON")

    boss = Pokemon(only_pokemon("Cryogonal"); max_tier = 3)
    @test sprint(show, boss) == "Cryogonal; max tier: 3.0"
end

@testset "Power-up costs" begin
    pk = Pokemon("Dragonite", (15, 13, 15); cp = 2156)
    @test PoGOBase.stardust(pk, 21.0) == 5000
    @test PoGOBase.stardust(pk.level => 21.0) == 5000
    @test PoGOBase.stardust(pk.level => 21.0; lucky = true) == 2500
    @test PoGOBase.stardust(pk, 21.5) == 8000
    @test PoGOBase.candy(pk, 21.0) == (4, 0)
    @test PoGOBase.candy(pk.level => 21.0) == (4, 0)
    @test PoGOBase.candy(35 => 35.5; kind = :normal) == (10, 0)
    @test PoGOBase.candy(35 => 35.5; kind = :shadow) == (12, 0)
    @test PoGOBase.candy(35 => 35.5; kind = :purified) == (9, 0)
    @test PoGOBase.candy(pk, 21.5) == (7, 0)
    pk = Pokemon("Dragonite", (15, 13, 15); islucky = true, cp = 2156)
    @test PoGOBase.stardust(pk, 21.5) == 4000
    pk = Pokemon("Dragonite", (15, 13, 15); mutation = 'S', cp = 2156)
    @test PoGOBase.stardust(pk, 21.5) == 9600
    @test PoGOBase.candy(pk, 21.5) == (10, 0)
    pk = Pokemon("Dragonite", 39.5, (15, 13, 15))
    @test PoGOBase.stardust(pk, 41.5) == 41000
    @test PoGOBase.candy(pk, 42.5) == (15, 52)
    pk = Pokemon("Ralts", 15, (14, 14, 15))
    @test PoGOBase.candy(pk, 15.5; as = only_pokemon("Gardevoir")) == PoGOBase.candy(pk, 15.5) .+ (125, 0)

    poke = Pokemon("vulpix_alola", 8, (15, 15, 15))
    as = only_pokemon("ninetales_alola")
    @test PoGOBase.kmcost(poke, 22.5; as, add_move = false) == PoGOBase.kmcost(poke, 1500; as, add_move = false) == 105 * 3
    @test PoGOBase.kmcost(poke, 22.5; as) == PoGOBase.kmcost(poke, 1500; as) == 155 * 3
    @test PoGOBase.kmcost(poke, 2500, 125; as) == PoGOBase.kmcost(poke, 2500, 130; as) + 15  # dominated by regular candy
    @test PoGOBase.kmcost(poke, 2500, 200; as) == PoGOBase.kmcost(poke, 2500, 250; as) ≈ 148 / 0.75 * 3  # dominated by XL
end

@testset "Low level utilities" begin
    PoGOBase.split_kwargs((:a, :z); a = 5, b = "hello", z = nothing) == ((a = 5, z = nothing), (b = "hello",))
    @test [80 => "SLOWBRO", 80 => "SLOWBRO_GALARIAN"] ⊆ PoGOBase.dex_name_pairs()
    pd = only_pokemon("Venusaur")
    poke = Pokemon("Venusaur", 20.0, (10, 10, 10))
    @test PoGOBase.dex(pd) == PoGOBase.dex(poke) == 3
    @test @inferred(PoGOBase.scalarlevel(20.0)) == 20.0
    @test @inferred(PoGOBase.scalarlevel(20.0:0.5:20.5)) == 20.25
    @test PoGOBase.type(pd) == PoGOBase.type(poke) == ("GRASS", "POISON")
    @test PoGOBase.base_stats(pd) == PoGOBase.base_stats(poke) == (198, 189, 190)

    @test Set(PoGOBase.weather["FOG"]) == Set(["DARK", "GHOST"])

    @test all(PoGOBase.is_legendary_mythical, [only_pokemon("Articuno"; exact = true), only_pokemon("Buzzwole"), only_pokemon("Mew"; exact = true)])
    @test !PoGOBase.is_legendary_mythical(only_pokemon("Venusaur"; exact = true))
    lms = PoGOBase.legendaries_mythicals()
    @test only_pokemon("moltres"; exact = true) ∈ lms
    @test !PoGOBase.isavailable(only_pokemon("glastrier"; exact = true))
    @test  PoGOBase.isavailable(only_pokemon("moltres"; exact = true))
    allpokes = PoGOBase.eachpokemon(; level = 31, ivs = (15, 15, 15))
    @test Pokemon("glastrier", 31, (15, 15, 15); warn = false) ∈ allpokes
    @test Pokemon("venusaur", 31, (15, 15, 15); mutation = 'S') ∈ allpokes
    @test Pokemon("scatterbug_tundra", 31, (15, 15, 15)) ∈ allpokes
    @test Pokemon("scatterbug_tundra", 31, (15, 15, 15); mutation = 'S') ∉ allpokes
    # all formes
    @test Pokemon("hoopa_unbound", 31, (15, 15, 15)) ∈ allpokes
    @test Pokemon("hoopa_confined", 31, (15, 15, 15)) ∈ allpokes
end

@testset "Moves" begin
    move = PoGOBase.pvp_moves["COUNTER_FAST"]
    @test uniquename(move) == "COUNTER_FAST"
    @test PoGOBase.type(move) == "FIGHTING"
    @test PoGOBase.ispvp(move)
    @test PoGOBase.duration(move) == 1.0
    @test PoGOBase.power(move) == 8
    @test move.energyDelta == 6
    move = PoGOBase.pve_moves["COUNTER_FAST"]
    @test uniquename(move) == "COUNTER_FAST"
    @test PoGOBase.type(move) == "FIGHTING"
    @test !PoGOBase.ispvp(move)
    @test PoGOBase.duration(move) == 1.0
    @test PoGOBase.power(move) == 13
    move = PoGOBase.pvp_moves["PSYSTRIKE"]
    @test move.energyDelta == -45
    @test PoGOBase.power(move) == 90

    @test PoGOBase.power(PoGOBase.pvp_moves["YAWN_FAST"]) == 0
end

@testset "Leagues" begin
    @test PoGOBase.league_max_level("Buzzwole", (1, 14, 12), 1.0, 2500) == (27.0 => 2498)
    @test_throws "not eligible" PoGOBase.league_max_level("Buzzwole", (1, 14, 12), 27.5, 2500)
    lvl, (cp, sp) = PoGOBase.statproduct_league("Buzzwole", (1, 14, 12), 2500)
    @test lvl == 27.0 && cp == 2498 && round(Int, sp) == 3789
    sps = PoGOBase.statproducts_league("medicham", 1500)
    @test argmax(sps) ∈ (CartesianIndex(5, 15, 15), CartesianIndex(5, 15, 14))   # tie
    sps = PoGOBase.statproducts_league("medicham", 1500; level_limit = 40)
    @test argmax(sps) == CartesianIndex(15, 15, 15)
    sps = PoGOBase.statproducts_league("cobalion", 2500)
    @test argmax(sps) == CartesianIndex(0, 14, 15)
    sps = PoGOBase.statproducts_league("cobalion", 2500; iv_floor = 10)
    @test argmax(sps) == CartesianIndex(11, 15, 15)

    ranks = PoGOBase.statranks_league("Buzzwole", 2500)
    @test ranks[1, 14, 12] == 5
    cps = PoGOBase.league_catch_cp("Phantump", 1500, "Trevenant")
    @test extrema(cps) == (594, 658)
    @test 151 <= PoGOBase.bulk_best_league("Buzzwole", 2500) <= 153

    b = PoGOBase.bulk_best_league("Machamp", 2500)
    bs = PoGOBase.bulk_best_league("Machamp", 2500; isshadow = true)
    @test bs * sqrt(1.2) ≈ b

    idx = findfirst(==(1), PoGOBase.statranks_league("Medicham", 1500))
    @test PoGOBase.league_max_level("Medicham", Tuple(idx), 1.0, 1500) == (50.0 => 1494)
end

@testset "Raids" begin
    # Ref: https://pokemongohub.net/post/meta/chandelure-as-a-ghost-type-and-fire-type-raid-attacker-is-poltergeist-useful/
    gengar40 = Pokemon("gengar", 40, (15, 15, 15))
    chandy40 = Pokemon("chandelure", 40, (15, 15, 15))
    chandy30 = Pokemon("chandelure", 30, (15, 15, 15))
    hound40 = Pokemon("houndoom", 40, (15, 15, 15))
    @test 1 < PoGOBase.raid_power(chandy40) / PoGOBase.raid_power(gengar40) < 1.1
    @test 1 < PoGOBase.raid_power(gengar40) / PoGOBase.raid_power(chandy30) < 1.1
    litwick30 = Pokemon("litwick", 30, (15, 15, 15))
    @test PoGOBase.raid_power(litwick30) < PoGOBase.raid_power(chandy30)
    @test PoGOBase.raid_power(litwick30; as = PoGOBase.pokemon["CHANDELURE"]) == PoGOBase.raid_power(chandy30)
    @test PoGOBase.raid_power(litwick30; as = PoGOBase.pokemon["CHANDELURE"], level = 40) == PoGOBase.raid_power(chandy40)
    @test PoGOBase.raid_power(hound40) < PoGOBase.raid_power(chandy40) < PoGOBase.raid_power(hound40; mega = true)
    for P in (Pokemon, Pokemon)
        mewtwo = P("mewtwo"; level = 20)
        mewtwo_s = P("mewtwo"; level = 20, mutation = 'S')
        @test PoGOBase.raid_power(mewtwo_s) / PoGOBase.raid_power(mewtwo) ≈ sqrt(1.2)
    end
end

@testset "type effectiveness" begin
    @test PoGOBase.typeeffect("NORMAL", "NORMAL") == 1.0
    @test PoGOBase.typeeffect("FIGHTING", "NORMAL") ≈ 1.6
    @test PoGOBase.typeeffect("NORMAL", "GHOST") ≈ 1 / 1.6^2
    @test PoGOBase.typeeffect("GHOST", "DARK") ≈ 1 / 1.6
    @test PoGOBase.typeeffect("WATER", ("FIRE", "POISON")) ≈ 1.6
    @test PoGOBase.typeeffect("WATER", ("FIRE", "ROCK")) ≈ 1.6^2
    @test PoGOBase.typeeffect("WATER", ("FIRE", "GRASS")) ≈ 1.0
end

@testset "damage" begin
    @test damage(10, 1, 1, 1) == damage(11, 1, 1, 1) == 6
    @test damage(10, 0.99, 1, 1) == damage(10, 1, 1.01, 1) == damage(10, 1, 1, 0.99) == 5

    # Note: Niantic periodically updates move parameters.
    # To guard against this, use an "archived" (or fake) move.
    # Compare against the example in https://pokemongohub.net/post/featured/move-damage-output-actually-calculated/
    # with the following changes:
    # - their effectiveness should be updated to 1.6 (1.4 was an old value)
    # - vaporeon's base stat for defense is (now?) 161, not 177
    attacker = Pokemon("VENUSAUR", 30, (15, 15, 15))
    defender = Pokemon("VAPOREON", 30, (15, 15, 15))
    sbf_pve = PoGOBase.PvEMove("SOLAR_BEAM_FAKE", "GRASS", 180.0f0, "solar_beam", 5000, 2800, 4800, -100)
    @test damage(sbf_pve, attacker, defender) == floor(Int, 0.5 * sbf_pve.power * 155.8521 / 128.7792 * 1.2 * 1.6) + 1
    @test damage(nothing, attacker, defender) == 0   # convenience for evaluating fast-move only damage (charged moved = nothing)

    # Steel attacks example (raid bosses)
    swf_pve = PoGOBase.PvEMove("STEEL_WING_FAKE", "STEEL", 14.0f0, "steel_wing_fast", 1000, 700, 1000, 8)
    swf_pvp = PoGOBase.PvPMove("STEEL_WING_FAKE", "STEEL", 7.0f0, "steel_wing_fast", 1, 6, nothing)
    # Checked against https://pokechespin.net
    dv = Pokemon("Cetoddle"; raid_tier = 3)   # vulnerable (ice)
    dr = Pokemon("Wailord"; raid_tier = 3)    # resistant (water)
    for (lvl, dmg) in ((27, 22), (27.5, 23), (29.5, 23), (30, 24), (34.5, 24), (35, 25))   # check breakpoints
        a = Pokemon("Skarmory", lvl, (15, 15, 15))
        @test damage(swf_pve, a, dv) == dmg
    end
    # note: we disagree with pokechespin.net on where the breakpoint is, lvl 28 or 28.5
    for (lvl, dmg) in ((26, 26), (26.5, 27), (28, 27), (29, 28), (31, 28), (31.5, 29))   # check breakpoints
        a = Pokemon("Skarmory", lvl, (15, 15, 15))
        @test damage(swf_pve, a, dv; current_weather = "snow") == dmg
    end
    # Friendship bonuses changed in the season of Might and Mastery, make sure we know what we're using
    friendship = deepcopy(PoGOBase.friendship_bonus)
    merge!(PoGOBase.friendship_bonus, Dict{String, Float32}("good" => 1.06, "great" => 1.1, "ultra" => 1.14, "best" => 1.2))
    for (lvl, dmg) in ((24.5, 23), (25, 24), (26.5, 24), (27, 25), (29, 25), (29.5, 26))   # check breakpoints
        a = Pokemon("Skarmory", lvl, (15, 15, 15))
        @test damage(swf_pve, a, dv; friendship = "great") == dmg
    end
    merge!(PoGOBase.friendship_bonus, friendship)
    # Use very high damage to check more precisely
    # There's an off-by-one difference with pokechespin in some cases
    sss_pve = PoGOBase.PvEMove("SUNSTEEL_STRIKE", "STEEL", 230.0f0, "sunsteel_strike", 3000, 2200, 3000, -100)
    for (lvl, dmgv, dmgr) in ((24, 609, 222), (24.5, 615, 224), (25, 621, 226), (25.5, 628, 229), (26, 634, 231), (26.5, 640, 233), (27, 646, 235))
        a = Pokemon("Necrozma_dusk_mane", lvl, (15, 15, 15))
        @test damage(sss_pve, a, dv) == dmgv
        @test damage(sss_pve, a, dr) == dmgr
    end

    defender = Pokemon("Groudon"; raid_tier = 5)
    hcf_pve = PoGOBase.PvEMove("HYDRO_CANNON_FAKE", "WATER", 90.0f0, "hydro_cannon", 2000, 600, 1700, -50)
    @test damage(hcf_pve, Pokemon("Swampert", 31, (15, 15, 15)), defender) == 75
    @test damage(hcf_pve, Pokemon("Swampert", 31, (15, 15, 15); mega = true), defender) == 99
end

@testset "BossFT and max battles" begin
    pk = Pokemon("Charizard", 31, (15, 15, 15); max = 'G', maxlevel = (2, 0, 2))
    dbf = PoGOBase.PvEMove("DRAGON_BREATH_FAKE", "DRAGON", 6.0f0, "dragon_breath_fast", 500, 300, 500, 4)
    mx = PoGOBase.MaxAttack(dbf, pk)
    @test PoGOBase.type(mx) == "FIRE"
    @test PoGOBase.power(mx) == 400
    bosspd = only_pokemon("Cryogonal")
    bossft = PoGOBase.BossFT(bosspd, 3)
    boss = Pokemon(bosspd; max_tier = 3)
    @test uniquename(boss) == uniquename(bossft)
    @test damage(dbf, pk, boss) == 5    # pokechespin.net
    @test damage(mx, pk, boss) == 579   # pokechespin.net
    @test damage(mx, pk, boss; current_weather = "clear") == 695   # pokechespin.net
    d = damage(dbf, pk, bossft)
    @test d / (100Unitful.percent) ≈ damage(dbf, pk, boss) / PoGOBase.hp(boss) rtol = 0.1
    d = damage(mx, pk, bossft)
    @test d / (100Unitful.percent) ≈ damage(mx, pk, boss) / PoGOBase.hp(boss) rtol = 0.01
    @test damage(nothing, pk, boss) == damage(nothing, pk, bossft) == 0

    wpf = PoGOBase.PvEMove("WATER_PULSE_FAKE", "WATER", 65.0f0, "water_pulse", 3000, 2000, 2700, -50)
    @test damage(wpf, bossft, pk) == damage(wpf, boss, pk)

    @test PoGOBase.max_battle_energy(99, boss) == PoGOBase.max_battle_energy(0.99Unitful.percent, bossft) == 1
    @test PoGOBase.max_battle_energy(100, boss) == PoGOBase.max_battle_energy(1.0Unitful.percent, bossft) == 2
end
