class_name Expedition
extends RefCounted
## One party's whole dungeon dive, and the expedition that wraps up to three of
## them — the layer between Battle (which resolves one fight) and the summary
## panel, per BalanceNumbers "Rewards", "Minions" and "Core rules".
##
##     var dive := Expedition.run_dive(party, Encounters.build_level(1, day, rng), rng)
##     dive["outcome"]    # "cleared" | "wiped" | "fled" | "stalemate"
##     dive["completed"]  # the boss fell: this level is done
##     dive["members"]    # per-member ledger, level-ups already applied
##
##     var summary := Expedition.resolve(Roster.parties, day, unlocked_level, rng)
##     summary["tax_copy"]        # the player's 10%, floored exactly once
##     summary["unlocked_level"]  # what a boss clear opened for future expeditions
##
## The dive is the whole difficulty. Adventurers heal to full outside the
## dungeon, so nothing here is about a single fight: HP and morale carry from
## fight to fight and only hp_regen / morale_regen claw any of it back, between
## battles and never per turn. Stats stay frozen for the dive — XP banks as it is
## earned and every level-up lands at the summary, after the last fight.
##
## Rewards are paid at the moment an enemy dies, to whoever is still standing in
## that fight right then. That timing is the whole of the doc's fled/dead rule:
## a member who flees later keeps everything already banked (XP included), and a
## member who dies keeps nothing at all — though the gold they earned still feeds
## the player's tax-copy, which is why the ledger tracks earned and kept apart.
##
## Nothing here reads GameState: `day`, `unlocked_level` and the RNG all come in
## as parameters, so an expedition is reproducible from its inputs alone and
## stays headlessly testable (same rule as Encounters).

## The dive ended with the boss dead — the level is complete.
const OUTCOME_CLEARED := "cleared"
## Every member who entered the last fight died in it.
const OUTCOME_WIPED := "wiped"
## The party was pushed out with survivors: panic flees, or a wipe that at least
## some of them ran from.
const OUTCOME_FLED := "fled"
## The zero-damage stalemate rule pushed the party out.
const OUTCOME_STALEMATE := "stalemate"

## There are only ever four dungeon levels — endless mode adds no new ones
## (BalanceNumbers "Endless mode"), it re-runs level 4 at rising tiers. This is
## structural: the bestiary in data/enemy_stats.csv has exactly four tiers.
const MAX_DUNGEON_LEVEL := 4

## Per-member ledgers for this dive, in party order.
var members: Array[Dictionary] = []
## One report per fight actually fought: {index, is_boss, outcome, rounds, events}.
var fights: Array[Dictionary] = []
var outcome := ""
var completed := false

var _rng: RandomNumberGenerator
## Summoner identities that have already paid their minions' XP this dive. A
## "summon" is one summoning-enemy instance in one party's one expedition
## (BalanceNumbers "Minions"), so the key is the fight it stands in plus its id.
var _paid_summons := {}


## Walk [param party] through [param fight_list] (an Encounters.build_level
## result) and return the resolved dive.
static func run_dive(
		party: Array,
		fight_list: Array[Dictionary],
		rng: RandomNumberGenerator) -> Dictionary:
	return Expedition.new()._run(party, fight_list, rng)


## Resolve a whole expedition: every non-empty party picks its dungeon level,
## dives its own independent copy of it, and the results are totalled into one
## summary. Returns {day, dives, gold_earned, tax_copy, unlocked_level}.
static func resolve(
		parties: Array,
		day: int,
		unlocked_level: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var unlocked := clampi(unlocked_level, 1, MAX_DUNGEON_LEVEL)
	var dives: Array[Dictionary] = []
	var gold_earned := 0
	for i in parties.size():
		var party: Array = parties[i]
		# An empty party is treated as if it does not exist (GDD): no dive row,
		# no summary column.
		if party.is_empty():
			continue
		# Every party picks against the level unlocked when the expedition
		# began, so a clear today never re-aims a party already underground.
		var n := Encounters.choose_dungeon_level(party, unlocked)
		var dive := run_dive(party, Encounters.build_level(n, day, rng), rng)
		dive["party_index"] = i
		dive["dungeon_level"] = n
		dives.append(dive)
		for member in dive["members"]:
			gold_earned += member["gold_earned"]
	# One party clearing a level is enough to open the next for everyone.
	var opened := unlocked
	for dive in dives:
		if dive["completed"]:
			opened = maxi(opened, mini(dive["dungeon_level"] + 1, MAX_DUNGEON_LEVEL))
	return {
		"day": day,
		"dives": dives,
		"gold_earned": gold_earned,
		"tax_copy": tax_copy(gold_earned),
		"unlocked_level": opened,
	}


## The player's cut: 10% of every coin the adventurers earned across the WHOLE
## expedition, minted alongside their purses rather than deducted from them.
## Accumulate, then multiply, then floor — ONCE, at the end. Flooring per drop
## pays the player exactly zero on dungeon level 1, where a grunt drops 0-2 gold
## and floor(0.1 * 2) is 0 (BalanceNumbers "The two taxes").
static func tax_copy(gold_earned: int) -> int:
	return floori(maxi(gold_earned, 0) * _balance("tax_copy_pct", 0.1))


## XP to reach the next level from [param level]: 8 * current level.
static func xp_to_next_level(level: int) -> int:
	return maxi(roundi(_balance("growth_xp_per_level_step", 8.0) * maxi(level, 1)), 1)


## Spend [param xp] on levels from [param level], returning {level, xp} with the
## leftover progress toward the next. An adventurer can gain several levels at
## once — a single dungeon level 1 clear is worth nearly two — which is why this
## loops rather than checking a single threshold.
static func apply_levels(level: int, xp: int) -> Dictionary:
	var new_level := maxi(level, 1)
	var remaining := maxi(xp, 0)
	while remaining >= xp_to_next_level(new_level):
		remaining -= xp_to_next_level(new_level)
		new_level += 1
	return {"level": new_level, "xp": remaining}


func _run(
		party: Array,
		fight_list: Array[Dictionary],
		rng: RandomNumberGenerator) -> Dictionary:
	_rng = rng
	for member in party:
		_add_member(member)
	for fight in fight_list:
		var roster := _still_diving()
		if roster.is_empty():
			break
		var report := _run_fight(fight, roster)
		fights.append(report)
		if report["outcome"] != Battle.OUTCOME_VICTORY:
			outcome = _exit_reason(report["outcome"], roster)
			break
		if fight.get("is_boss", false):
			completed = true
			break
		# Regen is the only healing inside a dive, and it lands between fights
		# rather than per turn — which is exactly why attrition down a level is
		# the difficulty (BalanceNumbers "Core rules").
		_regenerate()
	if outcome.is_empty():
		outcome = OUTCOME_CLEARED
	return {
		"outcome": outcome,
		"completed": completed,
		"members": _summarize(),
		"fights": fights,
	}


## Why the dive stopped, from the fight that stopped it. A defeat that left
## somebody standing means they ran; one that left nobody means the party wiped.
func _exit_reason(battle_outcome: String, roster: Array[Dictionary]) -> String:
	if battle_outcome == Battle.OUTCOME_STALEMATE:
		return OUTCOME_STALEMATE
	for ledger in roster:
		if ledger["alive"]:
			return OUTCOME_FLED
	return OUTCOME_WIPED


func _run_fight(fight: Dictionary, roster: Array[Dictionary]) -> Dictionary:
	var party: Array = []
	for ledger in roster:
		party.append({
			"name": ledger["name"],
			"class": ledger["class"],
			# Frozen for the dive: this is the level they walked in on, whatever
			# XP they have banked since.
			"level": ledger["start_level"],
			"hp": ledger["hp"],
			"morale": ledger["morale"],
		})
	var result := Battle.resolve(party, fight["enemies"], _rng)
	# Party combatants are added in roster order; match on side rather than
	# assuming their ids start at 0.
	var by_id := {}
	var next := 0
	for c in result["combatants"]:
		if c["side"] == Battle.PARTY_SIDE and next < roster.size():
			by_id[c["id"]] = roster[next]
			next += 1
	_award(fight, result, by_id)
	_carry_forward(result, by_id)
	return {
		"index": fight.get("index", fights.size() + 1),
		"is_boss": fight.get("is_boss", false),
		"outcome": result["outcome"],
		"rounds": result["rounds"],
		"events": result["events"],
	}


## Replay the fight's event list and pay every enemy death out to whoever was
## still in the fight at that instant.
func _award(fight: Dictionary, result: Dictionary, by_id: Dictionary) -> void:
	var enemies := {}
	for c in result["combatants"]:
		if c["side"] == Battle.ENEMY_SIDE:
			enemies[c["id"]] = c
	# Insertion-ordered, so the per-member gold rolls stay reproducible.
	var standing := {}
	## minion combatant id -> whether its wave is the one that pays.
	var pays := {}
	## Whoever holds the floor right now, and so the killer of anyone who dies
	## in it — a party member only ever dies inside somebody's turn.
	var actor := -1
	for event in result["events"]:
		match event["type"]:
			"battle_start":
				for id in event["party"]:
					standing[id] = true
			"turn_start":
				actor = event["actor"]
			"summon":
				var summoner := "%d:%d" % [fight.get("index", 0), event["actor"]]
				var first := not _paid_summons.has(summoner)
				_paid_summons[summoner] = true
				# A summoner pays for its first wave only: re-summoning after
				# that wave died pays nothing, so no summoner can be farmed.
				for id in event["spawned"]:
					pays[id] = first
			"flee":
				standing.erase(event["actor"])
			"party_flee":
				for id in event["actors"]:
					standing.erase(id)
			"death":
				if event["side"] == Battle.PARTY_SIDE:
					standing.erase(event["combatant"])
					# The summary names the enemy who struck the blow.
					if by_id.has(event["combatant"]) and enemies.has(actor):
						by_id[event["combatant"]]["killed_by"] = enemies[actor]["name"]
				else:
					_pay_out(enemies[event["combatant"]], standing, by_id, pays)


## One dead enemy's rewards, to each living member individually — never split.
func _pay_out(
		enemy: Dictionary,
		standing: Dictionary,
		by_id: Dictionary,
		pays: Dictionary) -> void:
	var archetype: String = enemy["archetype"]
	var n: int = enemy["level"]
	var minion: bool = enemy["minion"]
	var xp := 0
	if not minion:
		xp = EnemyStats.xp_reward(archetype, n)
	elif pays.get(enemy["id"], false):
		xp = EnemyStats.minion_xp_reward(archetype, n)
	var gold_range := EnemyStats.gold_range(archetype, n)
	var gold_mult: int = enemy.get("gold_mult", 1)
	for id in standing:
		if not by_id.has(id):
			continue
		var ledger: Dictionary = by_id[id]
		ledger["xp_earned"] += xp
		# Minions never drop gold. Everyone else's drop is rolled separately per
		# member, so two members rarely take the same cut off one corpse.
		if not minion:
			ledger["gold_earned"] += \
					_rng.randi_range(gold_range[0], gold_range[1]) * gold_mult


func _carry_forward(result: Dictionary, by_id: Dictionary) -> void:
	for c in result["combatants"]:
		if not by_id.has(c["id"]):
			continue
		var ledger: Dictionary = by_id[c["id"]]
		ledger["hp"] = c["hp"]
		ledger["morale"] = c["morale"]
		ledger["alive"] = c["alive"]
		ledger["fled"] = c["fled"]


func _regenerate() -> void:
	for ledger in _still_diving():
		ledger["hp"] = mini(ledger["hp"] + ledger["hp_regen"], ledger["max_hp"])
		ledger["morale"] = mini(
			ledger["morale"] + ledger["morale_regen"], ledger["max_morale"])


func _add_member(member: Dictionary) -> void:
	var adventurer_class: String = member.get("class", "")
	var level := maxi(int(member.get("level", 1)), 1)
	var stats := ClassStats.stats_at_level(adventurer_class, level)
	if stats.is_empty():
		push_error("Expedition: unknown adventurer class '%s'" % adventurer_class)
		return
	var hp := roundi(stats.get("hp", 1.0))
	var morale := roundi(stats.get("max_morale", 0.0))
	members.append({
		"member": member,
		"name": member.get("name", adventurer_class),
		"class": adventurer_class,
		"start_level": level,
		"start_xp": maxi(int(member.get("xp", 0)), 0),
		"start_gold": maxi(int(member.get("gold", 0)), 0),
		# Everyone enters fresh: the roster heals to full outside the dungeon.
		"hp": hp, "max_hp": hp,
		"morale": morale, "max_morale": morale,
		"hp_regen": roundi(stats.get("hp_regen", 0.0)),
		"morale_regen": roundi(stats.get("morale_regen", 0.0)),
		"xp_earned": 0,
		"gold_earned": 0,
		"alive": true,
		"fled": false,
		# The enemy who killed them, for the summary's status line ("" if they
		# walked out).
		"killed_by": "",
	})


## Members still walking deeper — the dead and the fled are out of the dive.
func _still_diving() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ledger in members:
		if ledger["alive"] and not ledger["fled"]:
			out.append(ledger)
	return out


## The summary the panel reads: what each member earned, what they actually keep,
## and the levels that spend it. `gold_earned` stays on a dead member's row
## because the tax-copy still counts it even though their purse is gone.
func _summarize() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ledger in members:
		var alive: bool = ledger["alive"]
		# Dead members get nothing: no XP, no level, and their purse is destroyed
		# along with everything else they carried.
		var progression := apply_levels(
			ledger["start_level"],
			ledger["start_xp"] + (ledger["xp_earned"] if alive else 0))
		var gold_kept: int = ledger["gold_earned"] if alive else 0
		out.append({
			"name": ledger["name"],
			"class": ledger["class"],
			"alive": alive,
			"fled": ledger["fled"],
			"killed_by": ledger["killed_by"],
			"xp_earned": ledger["xp_earned"],
			"gold_earned": ledger["gold_earned"],
			"gold_kept": gold_kept,
			"gold": (ledger["start_gold"] + gold_kept) if alive else 0,
			"start_level": ledger["start_level"],
			"level": progression["level"],
			"levels_gained": progression["level"] - ledger["start_level"],
			"xp": progression["xp"],
			"xp_to_next": xp_to_next_level(progression["level"]),
			"hp": ledger["hp"], "max_hp": ledger["max_hp"],
			"morale": ledger["morale"], "max_morale": ledger["max_morale"],
		})
	return out


## BalanceData.get_value for static context — Godot 4.7 cannot resolve autoload
## identifiers inside static functions, so it is fetched through the tree
## (same shim as EnemyStats._balance).
static func _balance(id: String, default_value: float) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return default_value
	var balance := tree.root.get_node_or_null("BalanceData")
	if balance == null:
		return default_value
	return balance.get_value(id, default_value)
