```@meta
CurrentModule = PoGOBase
DocTestSetup  = quote
    using PoGOBase
end
```

# Tutorial/Recipes

This tutorial illustrates a few of the things you can do with this package. For detailed explanations of all the options for each function, see the [Reference](@ref).

## Create Pokemon

```jldoctest
julia> poke = Pokemon("gastly", (0, 14, 11); cp = 730, name = "Gus")
Gus (Gastly); CP: 730; level: 23.0; IVs: (0, 14, 11)
```

In this example, the level was determined from the `CP`. Alternatively, you can also supply the level directly:

```jldoctest
julia> gira = Pokemon("Giratina_altered", 31, (10, 13, 15))
Giratina_Altered; CP: 2860; level: 31.0; IVs: (10, 13, 15)
```

and then it computes the CP for you. If you supply an impossible combination, it will throw an error:

```jldoctest
julia> poke = Pokemon("gastly", (0, 14, 11); cp = 731, name = "Gus")
ERROR: cp 731 not found for key GASTLY and IVs (0, 14, 11)
```

Raid bosses can be created:

```jldoctest
julia> Pokemon("Mewtwo"; raid_tier=5, mutation='S')
Mewtwo; CP: 54148; HP: 15000 (raid tier 5.0)
```

`mutation = 'S'` indicates a shadow Pokemon; you may notice that `Mewtwo` is printed in a gray text.
Conversely,

```jldoctest
julia> Pokemon("Mewtwo", 20, (12, 12, 12); islucky=true)
Mewtwo; CP: 2331; level: 20.0; IVs: (12, 12, 12)
```

will print the name in yellow to indicate its lucky status.

You can also create max-battle bosses:

```jldoctest
julia> Pokemon("Charizard"; max_tier=6)
G-Charizard; max tier: 6.0
```

The `G-` stands for Gigantamax. `D-` is not printed for dynamax, since there are many dynamax pokemon, but you can specify their parameters:

```jldoctest dmax
julia> tox = Pokemon("Toxtricity", (15, 13, 14); cp=1473, max='D', maxlevel=(2, 0, 0))
Toxtricity; CP: 1473; level: 20.0; IVs: (15, 13, 14)
```

In this case you've powered up the max attack to level 2 but not added shields or healing.
Not all the details are printed, but you can get them like this:

```jldoctest dmax
julia> tox.maxlevel
(2, 0, 0)
```

## Damage

In a Dialga raid, which will do more damage with its charged attack, a level 40 Primal Groudon or a level 42 Mega Lucario?

```jldoctest damage
julia> boss = Pokemon("dialga_origin"; raid_tier=5)
Dialga_Origin; CP: 54074; HP: 15000 (raid tier 5.0)

julia> pgroud = Pokemon("Groudon", 40, (15, 15, 15); mega=true)
Groudon (Mega Groudon); CP: 5902; level: 40.0; IVs: (15, 15, 15)

julia> mluc = Pokemon("Lucario", 42, (15, 15, 15); mega=true)
Lucario (Mega Lucario); CP: 3923; level: 42.0; IVs: (15, 15, 15)

julia> prec = PvEMove("precipice_blades")
PRECIPICE_BLADES (GROUND): 120.0 power, 1.5 s, -100 energy

julia> aurs = PvEMove("aura_sphere")
AURA_SPHERE (FIGHTING): 100.0 power, 2.0 s, -50 energy

julia> damage(prec, pgroud, boss)
177

julia> damage(aurs, mluc, boss)
132
```

One hit of Precipice Blades does a lot more damage, but it takes longer to charge (100 energy rather than 50 energy).

Weather and friendship can affect the damage:

```jldoctest damage
julia> damage(aurs, mluc, boss; current_weather="overcast", friendship="best")
190
```

## Battle leagues

What's the best Sableye for Great League?

```jldoctest
julia> best_for_league(only_pokemon("sableye"; exact=true), 1500)
Sableye; CP: 1499; level: 49.5; IVs: (0, 15, 15)
```

Where does mine rank?

```jldoctest
julia> ranks = statranks_league(only_pokemon("sableye"; exact=true), 1500);

julia> ranks[3, 13, 14]   # index `ranks` with the IVs
72
```

How good is it in terms of stat product?

```jldoctest statproduct
julia> sp = statproduct_league(Pokemon("sableye", 20, (3, 13, 14)), 1500)
48.5 => (1498, 1860.11676288)
```

This means that at level 48.5, it will achieve a CP of 1498 and a [`statproduct`](@ref) that's a little over 1860.
How does this compare to the best?

```jldoctest statproduct
julia> sp.second[2] / statproduct(best_for_league(only_pokemon("sableye"; exact=true), 1500))
0.9800759079235911
```

So it is within 98% of the best possible Sableye.

## Power-up costs

How much candy will I need to power up my Ho-Oh to the max?

```jldoctest powerup
julia> hooh = Pokemon("Ho_Oh", 20, (14, 15, 15); islucky=true)
Ho_Oh; CP: 2198; level: 20.0; IVs: (14, 15, 15)

julia> candy(hooh, 50)
(248, 296)
```

So it will require 248 regular Ho-Oh candy and 296 XL. What about stardust?

```jldoctest powerup
julia> stardust(hooh, 50)
237500
```

The stardust was discounted because it is a lucky.

## Strategy

Let's find all released Pokemon that resist each of Aerodactyl's fast moves:

```
julia> aero = only_pokemon("aerodactyl"; exact=true)
AERODACTYL (ROCK/FLYING): (221, 159, 190); Fast: ["STEEL_WING_FAST", "BITE_FAST", "ROCK_THROW_FAST"]; Charged: ["ANCIENT_POWER", "IRON_HEAD", "HYPER_BEAM", "ROCK_SLIDE", "EARTH_POWER"]

julia> fms = PvPMove.(fastmoves(aero))
3-element Vector{PvPMove}:
 STEEL_WING_FAST (STEEL): 7.0 power, 1.0 s, 6 energy, nothing
 BITE_FAST (DARK): 4.0 power, 0.5 s, 2 energy, nothing
 ROCK_THROW_FAST (ROCK): 8.0 power, 1.0 s, 5 energy, nothing

julia> filter(eachpokemon(include_shadow=false, include_mega=false)) do pk
           PoGOBase.isavailable(pk) && all(fm -> typeeffect(fm, pk) < 1, fms)
       end
13-element Vector{Pokemon}:
 Poliwrath; CP: 2253; level: 31.0; IVs: (15, 15, 15)
 Tauros_Paldea_Aqua; CP: 2472; level: 31.0; IVs: (15, 15, 15)
 Lucario; CP: 2355; level: 31.0; IVs: (15, 15, 15)
 Pawniard; CP: 1249; level: 31.0; IVs: (15, 15, 15)
 Bisharp; CP: 2478; level: 31.0; IVs: (15, 15, 15)
 Cobalion; CP: 2634; level: 31.0; IVs: (15, 15, 15)
 Keldeo; CP: 3223; level: 31.0; IVs: (15, 15, 15)
 Zamazenta; CP: 3337; level: 31.0; IVs: (15, 15, 15)
 Zamazenta_Crowned_Shield; CP: 3320; level: 31.0; IVs: (15, 15, 15)
 Urshifu_Rapid_Strike; CP: 3143; level: 31.0; IVs: (15, 15, 15)
 Quaquaval; CP: 2630; level: 31.0; IVs: (15, 15, 15)
 Pawmo; CP: 1132; level: 31.0; IVs: (15, 15, 15)
 Pawmot; CP: 2296; level: 31.0; IVs: (15, 15, 15)
```
