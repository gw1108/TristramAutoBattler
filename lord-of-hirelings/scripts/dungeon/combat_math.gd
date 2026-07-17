class_name CombatMath
extends Object
## The attack-resolution atom of the auto battle, per BalanceNumbers "Core
## rules used by these numbers". Everything here is pure: it takes stat
## dictionaries (as produced by ClassStats.stats_at_level or
## EnemyStats.stats_for) and an RNG, and returns what happened. The battle loop
## owns the round structure, turn order, and applying these results.
##
## Resolution order for one attack against one defender:
##   accuracy check -> guard check -> crit roll -> (on crit) a second evasion
##   check that downgrades the crit to a normal hit -> armor subtraction.
##
## An AOE attack rolls its damage and its crit ONCE and applies that single
## result against every target, while each target still resolves its own
## accuracy, guard, crit-downgrade and armor. That is why rolling and resolving
## are two calls: roll_attack() once, then resolve_against() per target. Only an
## ability that explicitly fires multiple projectiles would roll per target —
## none currently does.

## Chance for an attack to land, as a 0-1 fraction:
##   AA * 1.25 * 100 / (AA + DE * 0.3), clamped to [5%, 100%].
static func chance_to_hit(accuracy: float, evasion: float) -> float:
	var mult := _balance("hit_formula_accuracy_mult", 1.25)
	var weight := _balance("hit_formula_evasion_weight", 0.3)
	var denominator := accuracy + evasion * weight
	if denominator <= 0.0:
		return 1.0
	return clampf(accuracy * mult / denominator, 0.05, 1.0)


## Damage roll: a uniform integer in [power - 1, power + 1], minimum 1, rolled
## before armor.
static func damage_roll(power: float, rng: RandomNumberGenerator) -> int:
	var centre := roundi(power)
	return maxi(rng.randi_range(centre - 1, centre + 1), 1)


## Effective guard chance as a 0-1 fraction, capped at 75% for every character.
static func guard_chance(stats: Dictionary) -> float:
	var pct: float = stats.get("guard_pct", 0.0) / 100.0
	return clampf(pct, 0.0, _balance("guard_chance_max", 0.75))


## Roll the attack once: its damage and whether the whole attack crits. Crits
## are all or nothing — the roll multiplies the damage before armor.
static func roll_attack(attacker: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var crit_chance: float = attacker.get("crit_pct", 0.0) / 100.0
	var crit: bool = crit_chance > 0.0 and rng.randf() < crit_chance
	return {
		"damage": damage_roll(attacker.get("power", 0.0), rng),
		"crit": crit,
	}


## Resolve one already-rolled attack against one defender. Returns:
##   hit           — the attack was not evaded (a blocked attack still hit)
##   blocked       — the defender guarded it: no HP damage, full morale damage
##   crit          — it landed as a crit (false if the downgrade check caught it)
##   hp_damage     — HP the defender loses
##   morale_damage — morale the defender loses; applied on every landed hit,
##                   including blocked ones. Adventurers deal none.
static func resolve_against(
		attack: Dictionary,
		attacker: Dictionary,
		defender: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var result := {
		"hit": false, "blocked": false, "crit": false,
		"hp_damage": 0, "morale_damage": 0,
	}
	var hit_chance := chance_to_hit(
		attacker.get("accuracy", 0.0), defender.get("evasion", 0.0))
	if rng.randf() >= hit_chance:
		return result
	result["hit"] = true
	result["morale_damage"] = roundi(attacker.get("morale_damage", 0.0))

	# Guard is checked before the crit roll, so a blocked attack never crits.
	if rng.randf() < guard_chance(defender):
		result["blocked"] = true
		return result

	var crit: bool = attack.get("crit", false)
	# A crit must beat evasion twice: a second successful evasion check at the
	# same odds downgrades it to a normal hit rather than making it miss.
	if crit and rng.randf() >= hit_chance:
		crit = false
	result["crit"] = crit

	var damage := float(attack.get("damage", 0))
	if crit:
		var bonus: float = attacker.get(
			"crit_dmg_pct", _balance("crit_damage_bonus_default", 0.5) * 100.0)
		damage = damage * (1.0 + bonus / 100.0)
	if not attacker.get("ignores_armor", false):
		damage -= defender.get("armor", 0.0)
	# A landed, unblocked hit always deals at least 1.
	result["hp_damage"] = maxi(roundi(damage), 1)
	return result


## Roll and resolve a single-target attack in one call.
static func resolve_attack(
		attacker: Dictionary,
		defender: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	return resolve_against(roll_attack(attacker, rng), attacker, defender, rng)


## Chance an adventurer panics at the start of their turn, as a 0-1 fraction:
## clamp((0.5 - m) * 2, 0, 1) where m is current morale over max. On a panic,
## a second roll at the same odds decides flee (success) or cower (failure), so
## the flee chance is this squared.
static func panic_chance(morale: float, max_morale: float) -> float:
	if max_morale <= 0.0:
		return 1.0
	var threshold := _balance("panic_morale_threshold", 0.5)
	return clampf((threshold - morale / max_morale) * 2.0, 0.0, 1.0)


## BalanceData.get_value for static context — Godot 4.7 cannot resolve autoload
## identifiers inside static functions (same shim as ClassStats._balance).
static func _balance(id: String, default_value: float) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return default_value
	var balance := tree.root.get_node_or_null("BalanceData")
	if balance == null:
		return default_value
	return balance.get_value(id, default_value)
