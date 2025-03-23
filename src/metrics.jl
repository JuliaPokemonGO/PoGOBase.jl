# These are kind of a mess, consider refactoring or splitting out into a separate package

"""
    league_max_level(poke::Pokemon, league_cp::Int; level_limit=50.0) → level, cp
    league_max_level(poke::Pokemon, level::Real, league_cp::Int; level_limit=50.0) → level, cp
    league_max_level(name::AbstractString, ivs, level, league_cp::Int; level_limit=50.0) → level, cp

Return the maximum `level` and corresponding `cp` to stay at or below `league_cp`.
This errors if `poke.level` is already too high, although you can manually supply an
alternate `level` if you wish (1.0 is a good choice as it enables the most opportunities).
"""
league_max_level(poke::Pokemon, league_cp::Int; as::Species = Species(poke), kwargs...) =
    league_max_level(as, poke.ivs, poke.level, league_cp; kwargs...)

league_max_level(poke::Pokemon, level::Real, league_cp::Int; as::Species = Species(poke), kwargs...) =
    league_max_level(as, poke.ivs, level, league_cp; kwargs...)

function league_max_level(pd::Species, ivs, level, league_cp::Int; level_limit = 50.0, kwargs...)
    minlevel = minimum(level)
    combat_power(pd, ivs, minlevel; kwargs...) > league_cp && error("not eligible")
    cpl(level) = combat_power(pd, ivs, level; kwargs...)
    return binary_search(cpl, league_cp, minlevel, level_limit, 0.5)
end
function league_max_level(name::AbstractString, ivs, level, league_cp::Int; kwargs...)
    kwmatch, kwlml = split_kwargs(onlymatch_kwargs; kwargs...)
    return league_max_level(only_pokemon(name; kwmatch...), ivs, level, league_cp; kwlml...)
end

"""
    league_catch_cp(catch_name::AbstractString, league_cp::Int, as_name::AbstractString = catch_name; kwargs...) → cparray
    league_catch_cp(pd::Species, league_cp::Int, as::Species = pd; kwargs...) → cparray

Return a 3d `cparray` indexed by the IVs that returns the maximum cp to wild-catch a CP to be just at or below
`league_cp` when evolved to `as_uid`.
"""
function league_catch_cp(pd::Species, league_cp::Int, as::Species = pd; kwargs...)
    function cpiv(ivs)
        lvl, _ = league_max_level(as, ivs, 1.0, league_cp; kwargs...)
        return combat_power(pd, ivs, lvl)
    end
    return [cpiv((a, d, h)) for a in Base.IdentityUnitRange(0:15), d in Base.IdentityUnitRange(0:15), h in Base.IdentityUnitRange(0:15)]
end
league_catch_cp(catch_name::AbstractString, league_cp::Int, as_name::AbstractString = catchname; kwargs...) =
    league_catch_cp(only_pokemon(catch_name; kwargs...), league_cp, only_pokemon(as_name; kwargs...); kwargs...)

"""
    statproduct_league(pd::Species, ivs, league_cp::Int; kwargs...) → level => (cp, statprod)
    statproduct_league(name::AbstractString, ivs, league_cp::Int; kwargs...) → level => (cp, statprod)

Compute the `level`, `cp`, and ["stat product"](https://gostadium.club/rank-checker) for a pokemon with the given
`ivs` when powered up as high as allowed by `league_cp`. The same `kwargs` as [`league_max_level`](@ref) are supported.
"""
function statproduct_league(pd::Species, ivs, league_cp::Int; kwargs...)
    lvl, cp = league_max_level(pd, ivs, 1.0, league_cp; kwargs...)
    return lvl => (cp, statproduct(stats(pd, ivs, lvl)))
end
function statproduct_league(name::AbstractString, ivs, league_cp::Int; kwargs...)
    kwmatch, kwlml = split_kwargs(onlymatch_kwargs; kwargs...)
    return statproduct_league(only_pokemon(name; kwmatch...), ivs, league_cp; kwlml...)
end
statproduct_league(poke::Pokemon, league_cp::Int; kwargs...) = statproduct_league(Species(poke), poke.ivs, league_cp; kwargs...)

"""
    statproducts_league(pd, league_cp; level_limit=50.0, iv_floor=0) → statprods

Calculates the stat product associated with each possible IV combination.
`statprods[a, d, h]` returns the stat-product for `pd` with IVs `(a, d, h)`.
Note indexing of `statprods` starts at 0.

`level_limit` sets the power-up limit, and `iv_floor` sets the minimum IV in
all three categories. The following floors apply:

- raids, egg hatches, and research: 10
- weather boosted: 4
- trades:
  + good friends: 1
  + great friends: 2
  + ultra friends: 3
  + best friends: 5
  + lucky: 12

`statprods[a, d, h]` is zero for any IV combination not meeting these requirements.
"""
function statproducts_league(pd::Union{Species, MegaOverride}, league_cp::Int; iv_floor = 0, mega = false, kwargs...)
    bs = base_stats(pd; mega)
    z = zero(statproduct(bs))
    return OffsetArray([any(<(iv_floor), (i, j, k)) ? z : statproduct(bs .+ (i, j, k), league_max_level(pd, (i, j, k), 1.0, league_cp; kwargs...).first) for i in 0:15, j in 0:15, k in 0:15], -1, -1, -1)
end
function statproducts_league(name::AbstractString, league_cp::Int; kwargs...)
    kwmatch, kwlml = split_kwargs(onlymatch_kwargs; kwargs...)
    return statproducts_league(only_pokemon(name; kwmatch...), league_cp; kwlml...)
end

"""
    statranks_league(pd, league_cp; level_limit=50.0) → ranks

`ranks[a, d, h]` returns the statproduct rank for a poke with IVs `(a, d, h)`.
Note indexing of `ranks` starts at 0; the top statproduct is rank 1.
"""
function statranks_league(pd::Species, league_cp::Int; kwargs...)
    sps = statproducts_league(pd, league_cp; kwargs...)
    return reshape(invperm(sortperm(vec(sps); rev = true)), axes(sps))
end
function statranks_league(name::AbstractString, league_cp::Int; kwargs...)
    kwmatch, kwlml = split_kwargs(onlymatch_kwargs; kwargs...)
    return statranks_league(only_pokemon(name; kwmatch...), league_cp; kwlml...)
end

# """
#     best_statsproducts_league(name, league_cp::Int; nbest=100, level_limit=50.0) → ivlist
#     best_statsproducts_league(pd::Species, league_cp::Int; nbest=100, level_limit=50.0) → ivlist

# Return a list of the `nbest` best IVs for a battle league with CP limit `league_cp`.
# """
# function best_statsproducts_league(pd::Species, league_cp::Int; nbest::Int=100, kwargs...)
#     sps = statproducts_league(pd, league_cp; kwargs...)
#     p = sortperm(vec(sps))
#     return Tuple.(CartesianIndices(sps)[p[end-(nbest-1):end]])
# end
# function best_statsproducts_league(name::AbstractString, league_cp::Int; kwargs...)
#     kwmatch, kwlml = split_kwargs(onlymatch_kwargs; kwargs...)
#     best_statsproducts_league(only_pokemon(name; kwmatch...), league_cp; kwlml...)
# end

"""
    bulk_best_league(name, league_cp::Int; level_limit=50.0) → bulk
    bulk_best_league(pd::Species, league_cp::Int; level_limit=50.0) → bulk

Return the pokemon's bulk for a specific CP limit, assuming the best IVs and fully powered-up.
"""
function bulk_best_league(pd::Species, league_cp::Int; isshadow::Bool = false, kwargs...)
    sps = statproducts_league(pd, league_cp; kwargs...)
    p = sortperm(vec(sps))
    ivs = Tuple(CartesianIndices(sps)[p[end]])
    lvl = league_max_level(pd, ivs, 1.0, league_cp; kwargs...).first
    sts = apply_shadow(stats(pd, ivs, lvl), isshadow)
    d, h = sts[2:3]
    return sqrt(d * h)
end
function bulk_best_league(name::AbstractString, league_cp::Int; kwargs...)
    kwmatch, kwlml = split_kwargs(onlymatch_kwargs; kwargs...)
    return bulk_best_league(only_pokemon(name; kwmatch...), league_cp; kwlml...)
end

"""
    best_for_league(pd::Species, league_cp; kwargs...) → poke

Create the pokemon with highest statproduct given the league CP limit.
"""
function best_for_league(pd::Species, league_cp::Int; iv_floor = 0, kwargs...)
    sps = statproducts_league(pd, league_cp; iv_floor, kwargs...)
    ivs = Tuple(argmax(sps))
    lvl = league_max_level(pd, ivs, 1.0, league_cp; kwargs...)[1]
    return Pokemon(uniquename(pd), lvl, ivs)
end
function best_for_league(name::AbstractString, league_cp::Int; kwargs...)
    kwmatch, kwlml = split_kwargs(onlymatch_kwargs; kwargs...)
    return best_for_league(only_pokemon(name; kwmatch...), league_cp; kwlml...)
end

"""
    raid_power(pd::Species, ivs::IVsType, level::Real)
    raid_power(poke::Pokemon; as::Species=Species(poke), level=scalarlevel(poke))

Calculate the "abstract raid power," based on the standard `DPS^3*TDO`. Since `DPS ∝ a` (attack stat),
and `TDO ∝ a*d*h`, (the full stat product), this simply returns `(a^4 * d * h)^(1/6)`.
(The 1/6th power returns a value scaled like individual stats.)

This is most useful for comparing within-species, where all the move options are (in principle) identical.
"Full" raid power also depends on the raid boss and specific moves of all combatants.
If used to compare across species, "abstract raid power" may overrate pokemon with good stats but poor move options.
"""
raid_power(pd::Species, ivs::IVsType, level::Union{Real, Nothing}; isshadow = false, kwargs...) =
    raid_power(apply_shadow(stats(pd, ivs, level; kwargs...), isshadow)...)
raid_power(poke::Pokemon; as::Species = Species(poke), level = scalarlevel(poke), kwargs...) =
    raid_power(as, poke.ivs, level; isshadow = isshadow_default(poke), kwargs...)
raid_power(a::Real, d::Real, h::Real) = sqrt(cbrt(a^4 * d * h))
