# Version for absolute units and ferocity
damage(power::Real, attack::Real, defense::Real, modifier::Real) =
    floor(Int, power * attack * modifier / (2 * defense)) + 1
# Version for %HP units
damage(power::Real, attack::Real, tankiness::QTk, modifier::Real) =
    Unitful.percent * power * attack * modifier / ustrip(tankiness) / 2

"""
    damage(move::AbstractMove, attacker, defender; kwargs...)

Calculate the damage caused by a `move` from `attacker` against `defender`.
If `defender` is a `Pokemon`, the damage is an integer number of HP.
If `defender` is a `BossFT`, the damage is a percentage of the boss's HP.

Allowed `kwargs` depend on whether `move` is a PvP or PvE move.

For PvP moves, the following `kwargs` are allowed:
- `buffs::Real`: a multiplier for the damage, default is 1
- `charge::Real`: a multiplier for the damage, default is 1

For PvE moves, the following `kwargs` are allowed:
- `current_weather`: the current weather, default is missing (alternatively supply a numeric `weather=1.2` directly)
- `friendship`: the friendship level, default is missing (alternatively supply a numeric `friendshipbonus=1.0` directly)
- `dodged`: a multiplier for the damage, default is 1
- `mushroom::Bool`: a flag for the mushroom effect, default is false
- `helpericons`: the number of helper icons, default is 0 (alternatively supply a numeric `helperbonus=1.0` directly)
- `attack_multiplier`: a multiplier for the attacker's attack, default is 1
- `defense_multiplier`: a multiplier for the defender's defense, default is 1
"""
damage(move::AbstractMove, attacker::Pokemon, defender::Pokemon; kwargs...) =
    damage(power(move), stats(attacker)[1], stats(defender)[2], modifier(move, attacker, defender; kwargs...))
damage(::Nothing, attacker::Pokemon, defender::Pokemon; kwargs...) = 0  # no charged move

# Damage caused by a BossFT
function damage(
        move::Union{PvEMove, MaxAttack}, attacker::BossFT, defender::Pokemon;
        current_weather = missing, weather = weathereffect(move, current_weather)
    )
    m = modifier(move, type(attacker), type(defender)) * weather
    return damage(power(move), attacker.ferocity, stats(defender)[2], m)
end

# Damage caused to a BossFT
damage(move::Union{PvEMove, MaxAttack}, attacker::Pokemon, defender::BossFT; kwargs...) =
    damage(power(move), stats(attacker)[1], defender.tankiness * Tk, modifier(move, type(attacker), type(defender); kwargs...))
damage(::Nothing, attacker::Pokemon, defender::BossFT; kwargs...) =
    zero(1.0f0 * stats(attacker)[1] / ustrip(defender.tankiness)) * Unitful.percent


typeeffect(attacktype::AbstractString, defensetype::AbstractString) = typetable[String(attacktype) => String(defensetype)]
function typeeffect(attacktype::AbstractString, defensetype)
    f = 1.0f0
    for d in defensetype
        f *= typeeffect(attacktype, d)
    end
    return f
end

typeeffect(attacktype::AbstractString, defender::Union{Pokemon, Species}) = typeeffect(attacktype, type(defender))
typeeffect(move::AbstractMove, defender::Union{Pokemon, Species}) = typeeffect(type(move), defender)

function type_stab_effect(attacktype::AbstractString, type_attacker::TypeStrings, type_defender::TypeStrings)
    _typeeffect = typeeffect(attacktype, type_defender)
    STAB = attacktype ∈ type_attacker ? 1.2f0 : 1.0f0
    return _typeeffect * STAB
end
type_stab_effect(move::AbstractMove, type_attacker::TypeStrings, type_defender::TypeStrings) =
    type_stab_effect(type(move), type_attacker, type_defender)
type_stab_effect(attacktype::AbstractString, attacker::Union{Pokemon, Species}, defender::Union{Pokemon, Species}) =
    type_stab_effect(attacktype, type(attacker), type(defender))
type_stab_effect(move::AbstractMove, attacker::Union{Pokemon, Species}, defender::Union{Pokemon, Species}) =
    type_stab_effect(type(move), attacker, defender)

weathereffect(::PvPMove, _) = 1.0f0
weathereffect(move::Union{PvEMove, MaxAttack}, current_weather) = weathereffect(type(move), current_weather)
function weathereffect(movetype::AbstractString, current_weather)
    if current_weather !== missing && !isempty(current_weather)
        wtypes = weather[uppercase(current_weather)]
        if movetype ∈ wtypes
            return 1.2f0
        end
    end
    return 1.0f0
end

function modifier(
        move::PvPMove, atype::TypeStrings, dtype::TypeStrings;
        buffs::Real = 1, charge = 1.0f0
    )
    return type_stab_effect(move, atype, dtype) * buffs * charge * #= PvP bonus =# 1.3f0
end

function modifier(move::PvPMove, attacker::Pokemon, defender::Pokemon; kwargs...)
    return modifier(move, type(attacker), type(defender); kwargs...) *
        (#= 20% attack boost =# shadow_bonus(attacker) * #= 20% defense drop =# shadow_bonus(defender))
end

function modifier(
        move::Union{PvEMove, MaxAttack}, atype::TypeStrings, dtype::TypeStrings;
        current_weather = missing, weather = weathereffect(move, current_weather),
        friendship = "", friendshipbonus = friendship === missing ? oneunit(valtype(friendship_bonus)) : friendship_bonus[friendship],
        dodged = 1.0f0, mushroom::Bool = false,
        helpericons = 0, helperbonus = PoGOBase.helperbonus(helpericons),
        attack_multiplier = 1.0f0, defense_multiplier = 1.0f0
    )
    return type_stab_effect(move, atype, dtype) * weather * friendshipbonus * dodged *
        (1 + mushroom) * helperbonus * attack_multiplier / defense_multiplier
end

modifier(move::Union{PvEMove, MaxAttack}, attacker::Pokemon, defender::Pokemon; kwargs...) =
    modifier(move, type(attacker), type(defender); kwargs...) *
    shadow_bonus(attacker) * shadow_bonus(defender)

shadow_bonus(poke::Pokemon) = isshadow_default(poke) ? 1.2f0 : 1.0f0

## Simplified battle mechanics

# Convert the full system to a simplified system
ferocity(cpm::Real, attackstat::Real, attack_multiplier::Real = 1) = cpm * attackstat * attack_multiplier
tankiness(cpm::Real, defensestat::Real, hpstat::Real, defense_multiplier::Real = 1) = cpm * defensestat * hpstat * defense_multiplier / 100

# Extract the simplified parameters from observed data
function ferocity(move::PvEMove, boss::Species, defender::Pokemon, damagehp::Int; weather = missing)
    stats_def = PoGOBase.stats(defender)
    return 2 * stats_def[2] * (damagehp - (0 .. 1)) / (power(move) * weathereffect(move, weather) * type_stab_effect(move, boss, defender))
end

# From max attacks
function tankiness(
        movetype::String, max_attack_level::Int, gmax::Bool, attacker::Pokemon, boss::Species, damagepct::Real;
        weather = missing, friendship = missing, helpericons::Int = 0, mushroom::Bool = false
    )
    if !isa(friendship, Real)
        friendship = friendship === missing ? 1.0f0 : PoGOBase.friendship_bonus[friendship]
    end
    helpermod = helpericons == 0 ? 1.0f0 : 1.0f0 + mbparams.helper_bonus[helpericons]
    mod = weathereffect(movetype, weather) * friendship * helpermod * (1 + mushroom) * type_stab_effect(movetype, attacker, boss)
    p = mbparams.movepower[max_attack_level] + gmax * mbparams.movepower_bonus_gmax
    stats_atk = PoGOBase.stats(attacker)
    return p * mod * stats_atk[2] / (2 * damagepct)
end
