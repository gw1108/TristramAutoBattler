class_name Battle
extends RefCounted
## One auto battle — one party against one enemy group — resolved headlessly to
## completion in a single call, per the GDD's "Combat Mechanics" and
## BalanceNumbers. Nothing here touches the scene tree or waits a frame: the
## whole fight is decided up front and returned as an ordered event list that
## the dive scene replays at the doc's 0.6s per turn.
##
##     var result := Battle.resolve(Roster.parties[0], fight["enemies"], rng)
##     result["outcome"]     # "victory" | "defeat" | "stalemate"
##     result["events"]      # ordered dicts, each with a "type" key (see below)
##     result["combatants"]  # every fighter's final hp/morale/alive/fled state
##
## `party` takes Roster member dicts ({name, class, level}), optionally carrying
## "hp"/"morale" in from the previous fight of a dive; `enemies` takes Encounters
## specs (or bare bestiary ids). Ids in events index into `combatants`.
##
## Event types, in the order one round produces them: round_start, then per turn
## turn_start, (panic, cower | flee), (attack, attack_result... | ability |
## heal | summon | lifesteal), death; then regen, round_end, and possibly
## party_flee. battle_start and battle_end bookend the list.
##
## The battle owns the round structure and calls CombatMath for every attack —
## it never re-implements the hit/guard/crit/armor chain. Ability cadence is per
## battle: every counter here starts at 0 and dies with the instance.

const PARTY_SIDE := "party"
const ENEMY_SIDE := "enemy"

const OUTCOME_VICTORY := "victory"
const OUTCOME_DEFEAT := "defeat"
const OUTCOME_STALEMATE := "stalemate"

## Buff/debuff ability counts for initiative tiebreak rule 3 (BalanceNumbers
## "Class abilities"): Captain 1, Cleric 1, Knight 1, all others 0. Structural,
## not tunable — it is a property of which classes have an ability at all.
const ABILITY_COUNTS := {"Knight": 1, "Captain": 1, "Cleric": 1}

## The Lich's Raise Dead summons these; the only minion in the game.
const RAISED_MINION := "skeleton_warrior"

## Every fighter's live state, in spawn order. A combatant's id is its index.
var combatants: Array[Dictionary] = []
## The ordered replay of everything that happened.
var events: Array[Dictionary] = []
var rounds := 0
var outcome := ""

var _rng: RandomNumberGenerator
var _zero_damage_rounds := 0
var _party_damage_this_round := 0
## Whose turn is being resolved — an effect granted to that character during
## their own turn does not tick down at the end of it.
var _current_actor := -1


## Resolve one battle and return {outcome, rounds, events, combatants}.
static func resolve(
		party: Array,
		enemies: Array,
		rng: RandomNumberGenerator) -> Dictionary:
	return Battle.new().run(party, enemies, rng)


func run(party: Array, enemies: Array, rng: RandomNumberGenerator) -> Dictionary:
	_rng = rng
	for member in party:
		_add_adventurer(member)
	for spec in enemies:
		_add_enemy(spec, false)
	_emit("battle_start", {"party": _ids(PARTY_SIDE), "enemies": _ids(ENEMY_SIDE)})
	if not _check_outcome():
		# A real fight is ended by a wipe, a flee, or the stalemate rule. The
		# round cap only exists so a rules bug cannot hang the dive forever.
		var max_rounds := int(BalanceData.get_value("battle_max_rounds", 200.0))
		while outcome.is_empty() and rounds < max_rounds:
			rounds += 1
			_run_round()
		if outcome.is_empty():
			push_error("Battle: no outcome after %d rounds; forcing the party out" % rounds)
			_flee_party("round_cap")
			outcome = OUTCOME_STALEMATE
	_emit("battle_end", {"outcome": outcome, "rounds": rounds})
	return {
		"outcome": outcome,
		"rounds": rounds,
		"events": events,
		"combatants": combatants,
	}


## GDD combat event order: roll initiative for everyone already in the battle,
## resolve those turns in order, then enemy end-of-round effects and the
## stalemate check.
func _run_round() -> void:
	_party_damage_this_round = 0
	var order := _initiative_order()
	_emit("round_start", {"round": rounds, "order": _entry_ids(order)})
	for entry in order:
		var c: Dictionary = combatants[entry["id"]]
		# Died or fled since initiative was rolled: the turn is simply skipped.
		if not _is_active(c):
			continue
		_take_turn(c)
		if _check_outcome():
			return
	_end_of_round()


func _end_of_round() -> void:
	for c in _active(ENEMY_SIDE):
		if c["signature"] != "regeneration":
			continue
		var restored := _heal(c, int(BalanceData.get_value("enemy_regeneration_hp", 3.0)))
		if restored > 0:
			_emit("regen", {"combatant": c["id"], "amount": restored, "hp": c["hp"]})
	# The counter measures damage the party *dealt*, so an enemy out-healing the
	# party still resets it (BalanceNumbers "Stalemate rule").
	if _party_damage_this_round > 0:
		_zero_damage_rounds = 0
	else:
		_zero_damage_rounds += 1
	_emit("round_end", {
		"round": rounds,
		"party_damage": _party_damage_this_round,
		"zero_damage_rounds": _zero_damage_rounds,
	})
	if _zero_damage_rounds >= int(BalanceData.get_value("stalemate_rounds", 3.0)):
		_flee_party("stalemate")
		outcome = OUTCOME_STALEMATE
		return
	_check_outcome()


func _take_turn(c: Dictionary) -> void:
	_current_actor = c["id"]
	_emit("turn_start", {"actor": c["id"], "round": rounds})
	# Only the player's adventurers can panic; enemies always fight to the death.
	if c["side"] == PARTY_SIDE:
		match _panic_check(c):
			"flee":
				_flee(c)
				_current_actor = -1
				return
			"cower":
				c["turns"] += 1
				_cower(c)
				_tick_effects(c)
				_current_actor = -1
				return
	c["turns"] += 1
	_act(c)
	_tick_effects(c)
	_current_actor = -1


## "" (acts normally), "flee", or "cower" — the doc's two rolls at the same
## odds, so the flee chance is the panic chance squared.
func _panic_check(c: Dictionary) -> String:
	var chance := CombatMath.panic_chance(c["morale"], c["max_morale"])
	if chance <= 0.0 or _rng.randf() >= chance:
		return ""
	var result := "flee" if _rng.randf() < chance else "cower"
	_emit("panic", {"actor": c["id"], "result": result, "chance": chance})
	return result


## The cowering adventurer skipped their turn; they claw back 20% of their *max*
## morale afterward, which is what makes low morale a spiral they can escape.
func _cower(c: Dictionary) -> void:
	var restore := roundi(
		c["max_morale"] * BalanceData.get_value("cowering_morale_restore_pct", 0.2))
	c["morale"] = mini(c["morale"] + restore, c["max_morale"])
	_emit("cower", {"actor": c["id"], "morale_restored": restore, "morale": c["morale"]})


func _flee(c: Dictionary) -> void:
	c["fled"] = true
	_emit("flee", {"actor": c["id"]})


func _flee_party(cause: String) -> void:
	var fled: Array[int] = []
	for c in _active(PARTY_SIDE):
		c["fled"] = true
		fled.append(c["id"])
	_emit("party_flee", {"cause": cause, "actors": fled})


func _act(c: Dictionary) -> void:
	if c["side"] == ENEMY_SIDE:
		_act_enemy(c)
		return
	match c["class"]:
		"Knight":
			_act_knight(c)
		"Captain":
			_act_captain(c)
		"Mage":
			_aoe_attack(c, _active(ENEMY_SIDE), "aoe_bolt")
		"Cleric":
			_act_cleric(c)
		_:
			# Berserker and Rogue attack normally; Frenzy is a passive resolved
			# in _effective_stats, and the Rogue just rides its crit stats.
			_single_attack(c, "attack")


## Shield Bash: a normal single-target attack, after which his guard chance is
## doubled (capped at 75% by CombatMath) through the end of his next turn. The
## doubling lands whether or not the bash itself connected.
func _act_knight(c: Dictionary) -> void:
	_single_attack(c, "shield_bash")
	_apply_effect(c, "shield_bash", {
		"duration": int(BalanceData.get_value("knight_shield_bash_duration_turns", 1.0)),
	})


func _act_captain(c: Dictionary) -> void:
	var interval := int(BalanceData.get_value("captain_horn_turn_interval", 3.0))
	if interval > 0 and c["turns"] % interval == 0:
		_rallying_horn(c)
	else:
		_single_attack(c, "attack")


## Rallying Horn: morale to every living party member and +1 power on each of
## their next attacks. The power buff is one shared stacking instance, so a
## second Horn raises its magnitude and refreshes its duration.
func _rallying_horn(c: Dictionary) -> void:
	var morale := int(BalanceData.get_value("captain_horn_morale", 2.0))
	var power := BalanceData.get_value("captain_horn_power", 1.0)
	var duration := int(BalanceData.get_value("captain_horn_power_duration_turns", 1.0))
	var targets: Array[int] = []
	for ally in _active(PARTY_SIDE):
		ally["morale"] = mini(ally["morale"] + morale, ally["max_morale"])
		_apply_effect(ally, "horn_power", {
			"duration": duration, "magnitude": power, "stack_magnitude": true,
		})
		targets.append(ally["id"])
	_emit("ability", {
		"actor": c["id"], "ability": "rallying_horn", "targets": targets,
		"morale": morale, "power": power,
	})


## Heal power + 1 to the lowest-HP living ally (itself included), or Blessing
## when the whole party is untouched. The heal is deterministic — no ±1 roll,
## no crit.
func _act_cleric(c: Dictionary) -> void:
	var wounded: Array[Dictionary] = []
	var lowest := 0
	for ally in _active(PARTY_SIDE):
		if ally["hp"] >= ally["max_hp"]:
			continue
		if wounded.is_empty() or ally["hp"] < lowest:
			lowest = ally["hp"]
			wounded = [ally]
		elif ally["hp"] == lowest:
			wounded.append(ally)
	if wounded.is_empty():
		_blessing(c)
		return
	var target: Dictionary = wounded[_rng.randi() % wounded.size()]
	var amount := roundi(_effective_stats(c)["power"]
			+ BalanceData.get_value("cleric_heal_power_bonus", 1.0))
	var healed := _heal(target, amount)
	_emit("heal", {
		"actor": c["id"], "target": target["id"], "amount": healed, "hp": target["hp"],
	})


func _blessing(c: Dictionary) -> void:
	var allies := _active(PARTY_SIDE)
	if allies.is_empty():
		return
	var target: Dictionary = allies[_rng.randi() % allies.size()]
	_apply_effect(target, "blessing", {
		"duration": int(BalanceData.get_value("cleric_blessing_duration_turns", 3.0)),
		"magnitude": BalanceData.get_value("cleric_blessing_armor", 1.0),
	})
	_emit("ability", {"actor": c["id"], "ability": "blessing", "targets": [target["id"]]})


func _act_enemy(c: Dictionary) -> void:
	# Eruption: the Demon Prince's every-3rd-turn attack hits the whole party.
	if c["signature"] == "eruption":
		var interval := int(
			BalanceData.get_value("demon_prince_eruption_turn_interval", 3.0))
		if interval > 0 and c["turns"] % interval == 0:
			_aoe_attack(c, _active(PARTY_SIDE), "eruption")
			return
	if c["archetype"] == EnemyStats.CASTER:
		_aoe_attack(c, _active(PARTY_SIDE), "aoe_attack")
		return
	_single_attack(c, "attack")


## Targeting for single-target attacks on both sides: a uniformly random living
## enemy.
func _single_attack(c: Dictionary, ability: String) -> void:
	var foes := _active(_opposing(c["side"]))
	if foes.is_empty():
		return
	var target: Dictionary = foes[_rng.randi() % foes.size()]
	var stats := _effective_stats(c, true)
	var attack := CombatMath.roll_attack(stats, _rng)
	_emit("attack", {
		"actor": c["id"], "ability": ability, "targets": [target["id"]], "aoe": false,
	})
	_resolve_hit(c, stats, attack, target)
	_consume_horn(c)


## The standard AOE rule: damage and crit are rolled ONCE for the whole volley
## and applied against every target, each of whom still resolves its own
## accuracy, guard, crit-downgrade and armor.
func _aoe_attack(c: Dictionary, targets: Array[Dictionary], ability: String) -> void:
	if targets.is_empty():
		return
	var stats := _effective_stats(c, true)
	var attack := CombatMath.roll_attack(stats, _rng)
	_emit("attack", {
		"actor": c["id"], "ability": ability, "targets": _ids_of(targets), "aoe": true,
	})
	for target in targets:
		if not _is_active(target):
			continue
		_resolve_hit(c, stats, attack, target)
	_consume_horn(c)


## Apply one already-rolled attack to one target: HP damage, then the immediate
## on-damage effects (lifesteal, Raise Dead), then the death.
func _resolve_hit(
		attacker: Dictionary,
		attacker_stats: Dictionary,
		attack: Dictionary,
		target: Dictionary) -> void:
	var result := CombatMath.resolve_against(
		attack, attacker_stats, _effective_stats(target), _rng)
	var event := {
		"actor": attacker["id"], "target": target["id"],
		"hit": result["hit"], "blocked": result["blocked"], "crit": result["crit"],
		"hp_damage": result["hp_damage"], "morale_damage": 0,
	}
	if not result["hit"]:
		_emit("attack_result", event)
		return
	# Enemies are immune to morale, so only adventurers can take it — including
	# on an attack their guard fully absorbed.
	if target["side"] == PARTY_SIDE and result["morale_damage"] > 0:
		event["morale_damage"] = result["morale_damage"]
		target["morale"] = maxi(target["morale"] - int(result["morale_damage"]), 0)
	var damage: int = result["hp_damage"]
	if damage > 0:
		target["hp"] = maxi(target["hp"] - damage, 0)
		if attacker["side"] == PARTY_SIDE:
			_party_damage_this_round += damage
	event["hp"] = target["hp"]
	event["morale"] = target["morale"]
	_emit("attack_result", event)
	if damage <= 0:
		return
	if attacker["signature"] == "lifesteal":
		var stolen := _heal(attacker, damage)
		if stolen > 0:
			_emit("lifesteal", {
				"actor": attacker["id"], "amount": stolen, "hp": attacker["hp"],
			})
	if target["hp"] <= 0:
		_kill(target)
	else:
		_check_raise_dead(target)


## Raise Dead: the first time the Lich drops below half HP in a battle — and
## only if it survived the hit — it raises 2 Skeleton Warriors. They enter now
## but cannot act until the next round, which falls out of initiative already
## having been rolled for this one.
func _check_raise_dead(c: Dictionary) -> void:
	if c["signature"] != "raise_dead" or not c["raise_dead_armed"]:
		return
	var threshold := BalanceData.get_value("lich_raise_dead_hp_threshold", 0.5)
	if float(c["hp"]) >= c["max_hp"] * threshold:
		return
	c["raise_dead_armed"] = false
	var spawned: Array[int] = []
	for _i in int(BalanceData.get_value("lich_raise_dead_count", 2.0)):
		var id := _add_enemy(RAISED_MINION, true)
		if id >= 0:
			spawned.append(id)
	_emit("summon", {"actor": c["id"], "ability": "raise_dead", "spawned": spawned})


## A death immediately deals 2 morale damage to every surviving party member.
## Fleeing does not — only dying does.
func _kill(c: Dictionary) -> void:
	c["hp"] = 0
	c["alive"] = false
	var morale_damage := 0
	if c["side"] == PARTY_SIDE:
		morale_damage = int(BalanceData.get_value("death_morale_damage", 2.0))
		for ally in _active(PARTY_SIDE):
			ally["morale"] = maxi(ally["morale"] - morale_damage, 0)
	_emit("death", {
		"combatant": c["id"], "side": c["side"], "party_morale_damage": morale_damage,
	})


## Turn order is re-rolled every round: d20 + speed, highest first, with the
## doc's five tiebreaks applied in order.
func _initiative_order() -> Array[Dictionary]:
	var sides := int(BalanceData.get_value("initiative_die_sides", 20.0))
	var entries: Array[Dictionary] = []
	for c in _active(""):
		var stats := _effective_stats(c)
		entries.append({
			"id": c["id"],
			"roll": _rng.randi_range(1, sides) + stats.get("speed", 0.0),
			"speed": stats.get("speed", 0.0),
			"is_enemy": c["side"] == ENEMY_SIDE,
			"abilities": ABILITY_COUNTS.get(c["class"], 0),
			"power": stats.get("power", 0.0),
			# Tiebreak 5 is random, and is rolled up front so the comparator
			# stays a pure ordering rather than a coin flip per comparison.
			"coin": _rng.randf(),
		})
	entries.sort_custom(_initiative_before)
	return entries


static func _initiative_before(a: Dictionary, b: Dictionary) -> bool:
	if a["roll"] != b["roll"]:
		return a["roll"] > b["roll"]
	if a["speed"] != b["speed"]:
		return a["speed"] > b["speed"]
	if a["is_enemy"] != b["is_enemy"]:
		return a["is_enemy"]
	if a["abilities"] != b["abilities"]:
		return a["abilities"] > b["abilities"]
	if a["power"] != b["power"]:
		return a["power"] > b["power"]
	return a["coin"] > b["coin"]


## A combatant's stats with its live buffs and passives folded in. `attacking`
## adds the buffs that only a swing spends, so a Cleric's heal never rides the
## Rallying Horn's attack buff.
func _effective_stats(c: Dictionary, attacking: bool = false) -> Dictionary:
	var stats: Dictionary = c["stats"].duplicate()
	var effects: Dictionary = c["effects"]
	# Frenzy is a continuous passive with no counter: it is evaluated here, at
	# the moment of each attack.
	if c["class"] == "Berserker":
		var threshold := BalanceData.get_value("berserker_frenzy_hp_threshold", 0.5)
		if float(c["hp"]) < c["max_hp"] * threshold:
			stats["power"] += BalanceData.get_value("berserker_frenzy_power", 1.0)
	if effects.has("shield_bash"):
		# CombatMath.guard_chance applies the 75% cap this doubling slams into.
		stats["guard_pct"] *= BalanceData.get_value("knight_shield_bash_guard_mult", 2.0)
	if effects.has("blessing"):
		stats["armor"] += effects["blessing"]["magnitude"]
	if attacking and effects.has("horn_power"):
		stats["power"] += effects["horn_power"]["magnitude"]
	return stats


func _apply_effect(target: Dictionary, id: String, effect: Dictionary) -> void:
	var existing: Dictionary = target["effects"].get(id, {})
	var magnitude: float = effect.get("magnitude", 0.0)
	# Only Horn power stacks its magnitude; Shield Bash and Blessing refuse to
	# stack and merely refresh their duration, which reassignment already does.
	if effect.get("stack_magnitude", false) and not existing.is_empty():
		magnitude += existing["magnitude"]
	target["effects"][id] = {
		"duration": int(effect.get("duration", 1)),
		"magnitude": magnitude,
		# Durations tick at the end of the affected character's turn, so an
		# effect granted during that character's own turn would evaporate
		# before it did anything. Both grants that can hit their own caster
		# ("through the end of his next turn", "lasts through the recipient's
		# next turn") mean the turn after this one, so skip the first tick.
		"skip_next_tick": target["id"] == _current_actor,
	}


func _tick_effects(c: Dictionary) -> void:
	var effects: Dictionary = c["effects"]
	for id in effects.keys():
		var effect: Dictionary = effects[id]
		if effect["skip_next_tick"]:
			effect["skip_next_tick"] = false
			continue
		effect["duration"] -= 1
		if effect["duration"] <= 0:
			effects.erase(id)


## The Horn's buff is "+1 power on their next attack" — the attack spends it,
## however many targets that attack hit.
func _consume_horn(c: Dictionary) -> void:
	c["effects"].erase("horn_power")


func _heal(c: Dictionary, amount: int) -> int:
	var healed := clampi(amount, 0, c["max_hp"] - c["hp"])
	c["hp"] += healed
	return healed


func _check_outcome() -> bool:
	if not outcome.is_empty():
		return true
	if _active(ENEMY_SIDE).is_empty():
		outcome = OUTCOME_VICTORY
		return true
	if _active(PARTY_SIDE).is_empty():
		outcome = OUTCOME_DEFEAT
		return true
	return false


## Optional "hp"/"morale" on the member dict carry a dive's attrition in from the
## previous fight; without them the adventurer enters at full, which is what
## healing to full outside the dungeon means (BalanceNumbers "Core rules").
func _add_adventurer(member: Dictionary) -> int:
	var adventurer_class: String = member.get("class", "")
	var level := maxi(int(member.get("level", 1)), 1)
	var stats := ClassStats.stats_at_level(adventurer_class, level)
	if stats.is_empty():
		push_error("Battle: unknown adventurer class '%s'" % adventurer_class)
		return -1
	var hp := roundi(stats.get("hp", 1.0))
	var morale := roundi(stats.get("max_morale", 0.0))
	return _add_combatant({
		"side": PARTY_SIDE,
		"name": member.get("name", adventurer_class),
		"class": adventurer_class,
		"variant": "",
		"archetype": "",
		"signature": "",
		"minion": false,
		"trait": "",
		"gold_mult": 1,
		"level": level,
		"stats": stats,
		"hp": clampi(int(member.get("hp", hp)), 0, hp), "max_hp": hp,
		"morale": clampi(int(member.get("morale", morale)), 0, morale),
		"max_morale": morale,
		"raise_dead_armed": false,
	})


## [param spec] is an Encounters enemy spec — {variant, archetype, trait,
## gold_mult, stats}, with any gold trait already folded into its stats — or a
## bare bestiary id, which is that enemy untraited (what a summon is). The trait
## rides along untouched by the fight: it is the rewards layer that spends it.
func _add_enemy(spec: Variant, minion: bool) -> int:
	var enemy: Dictionary = spec if spec is Dictionary else {"variant": spec}
	var variant_id: String = enemy.get("variant", "")
	var stats: Dictionary = enemy["stats"].duplicate() \
			if enemy.has("stats") else EnemyStats.stats_for(variant_id)
	if stats.is_empty():
		push_error("Battle: unknown enemy variant '%s'" % variant_id)
		return -1
	var signature := EnemyStats.signature_of(variant_id)
	var hp := roundi(stats.get("hp", 1.0))
	return _add_combatant({
		"side": ENEMY_SIDE,
		"name": EnemyStats.display_name(variant_id),
		"class": "",
		"variant": variant_id,
		"archetype": EnemyStats.archetype_of(variant_id),
		"signature": signature,
		"minion": minion,
		"trait": enemy.get("trait", ""),
		# Minions never drop gold, so they never carry a multiplier either.
		"gold_mult": 1 if minion else int(enemy.get("gold_mult", 1)),
		"level": EnemyStats.dungeon_of(variant_id),
		"stats": stats,
		"hp": hp, "max_hp": hp,
		# Enemies are immune to morale; they carry none to lose.
		"morale": 0, "max_morale": 0,
		# Once-per-fight triggers re-arm at the start of every battle, which is
		# what constructing the battle fresh already means.
		"raise_dead_armed": signature == "raise_dead",
	})


func _add_combatant(fields: Dictionary) -> int:
	var c := fields.duplicate()
	c["id"] = combatants.size()
	c["alive"] = true
	c["fled"] = false
	# The character's own turns taken this battle — what "every 3rd turn" counts.
	c["turns"] = 0
	c["effects"] = {}
	combatants.append(c)
	return c["id"]


## Combatants still in the fight on [param side], or on both sides when it is "".
func _active(side: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in combatants:
		if _is_active(c) and (side.is_empty() or c["side"] == side):
			out.append(c)
	return out


func _is_active(c: Dictionary) -> bool:
	return c["alive"] and not c["fled"]


func _opposing(side: String) -> String:
	return ENEMY_SIDE if side == PARTY_SIDE else PARTY_SIDE


func _ids(side: String) -> Array[int]:
	return _ids_of(_active(side))


func _ids_of(group: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for c in group:
		out.append(c["id"])
	return out


func _entry_ids(entries: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for entry in entries:
		out.append(entry["id"])
	return out


func _emit(type: String, data: Dictionary) -> void:
	var event := data.duplicate()
	event["type"] = type
	events.append(event)
