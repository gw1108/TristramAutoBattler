class_name EnemyStats
extends Object
## Static reader for the BalanceNumbers "Enemies" section: the three archetype
## formulas (grunt / caster / boss, valid for any dungeon level N), the
## bestiary's per-variant tweaks, and the XP/gold reward tables.
##
## The archetype formulas are the source of truth — the doc's stat table is
## generated from them, not hand-written — so their terms live in balance.csv
## and the closed forms live here. The bestiary itself (which variants exist,
## on which level, with what deltas) is structural data in data/enemy_stats.csv.
##
## Stats are returned in the same keys ClassStats uses, so an adventurer and an
## enemy present the same shape to the combat math (CombatMath).

const CSV_PATH := "res://data/enemy_stats.csv"

const GRUNT := "grunt"
const CASTER := "caster"
const BOSS := "boss"

## variant id -> {display_name, dungeon, archetype, stock_grunt, deltas, signature}
static var _bestiary: Dictionary = {}


## Every stat of a stock archetype enemy at dungeon level n, as {stat_key: float}.
## The closed forms from BalanceNumbers "Archetype formulas (valid for any level N)".
static func archetype_stats(archetype: String, n: int) -> Dictionary:
	var level := maxi(n, 1)
	var steps := level - 1
	var growth: float = pow(_balance("enemy_hp_growth", 1.6), steps)
	var power_step := _balance("enemy_power_per_level", 2.0) * steps
	return {
		"hp": float(roundi(_balance("enemy_%s_hp_base" % archetype, 8.0) * growth)),
		"hp_regen": 0.0,
		"power": _balance("enemy_%s_power_base" % archetype, 3.0) + power_step,
		"speed": _balance("enemy_%s_speed" % archetype, 4.0),
		# Only the boss has armor, and it is exactly its dungeon level.
		"armor": float(level) if archetype == BOSS else 0.0,
		# Blocking and critting are adventurer-side mechanics: every enemy is 0/0.
		"guard_pct": 0.0,
		"evasion": _balance("enemy_evasion_per_level", 40.0) * level \
				+ _balance("enemy_%s_evasion_base" % archetype, 20.0),
		"accuracy": _balance("enemy_accuracy_per_level", 40.0) * level \
				+ _balance("enemy_%s_accuracy_base" % archetype, 60.0),
		"crit_pct": 0.0,
		"crit_dmg_pct": 0.0,
		# Enemies are immune to morale but deal it; only this side of it exists.
		# Left fractional: CombatMath rounds it once, at the moment a hit lands.
		"morale_damage": _balance("enemy_morale_damage_per_level", 1.0) * level \
				+ (_balance("enemy_morale_damage_boss_bonus", 1.0) \
						if archetype == BOSS else 0.0),
	}


## Full stats for a bestiary variant — its archetype row at the dungeon level it
## appears on, plus that variant's tweaks. Empty on an unknown id.
static func stats_for(variant_id: String) -> Dictionary:
	var entry := _entry(variant_id)
	if entry.is_empty():
		return {}
	var stats := archetype_stats(entry["archetype"], entry["dungeon"])
	stats["hp"] = maxf(stats["hp"] + entry["hp_delta"], 1.0)
	stats["power"] = maxf(stats["power"] + entry["power_delta"], 0.0)
	stats["speed"] = stats["speed"] + entry["speed_delta"]
	# The Bandit King's Cheap Shot is the only signature the attack math itself
	# has to know about; the rest are resolved by the battle loop.
	stats["ignores_armor"] = entry["signature"] == "cheap_shot"
	return stats


static func display_name(variant_id: String) -> String:
	var entry := _entry(variant_id)
	return entry.get("display_name", "")


static func archetype_of(variant_id: String) -> String:
	var entry := _entry(variant_id)
	return entry.get("archetype", "")


static func dungeon_of(variant_id: String) -> int:
	var entry := _entry(variant_id)
	return entry.get("dungeon", 0)


## The variant's ability flag from the bestiary ("lifesteal", "raise_dead",
## "eruption", "regeneration", "cheap_shot"), or "" for a stock enemy.
static func signature_of(variant_id: String) -> String:
	var entry := _entry(variant_id)
	return entry.get("signature", "")


## The two stock grunt variants of a dungeon level — the 50/50 pool a grunt slot
## rolls from. The Slime is a tutorial grunt outside this pool.
static func stock_grunts(n: int) -> Array[String]:
	_ensure_loaded()
	var ids: Array[String] = []
	for id in _bestiary:
		var entry: Dictionary = _bestiary[id]
		if entry["dungeon"] == n and entry["archetype"] == GRUNT and entry["stock_grunt"]:
			ids.append(id)
	ids.sort()
	return ids


## The caster / boss variant of a dungeon level; each level has exactly one.
static func variant_of(archetype: String, n: int) -> String:
	_ensure_loaded()
	for id in _bestiary:
		var entry: Dictionary = _bestiary[id]
		if entry["dungeon"] == n and entry["archetype"] == archetype:
			return id
	return ""


## Gold dropped to each living party member, as [min, max] of the roll.
## gold_min(N) = max(0, 2(N-2)); gold_max(N) = (3N^2 - 5N + 6) / 2; a boss pays
## 2.5x-5x a normal enemy's *maximum* for its level.
static func gold_range(archetype: String, n: int) -> Array[int]:
	var level := maxi(n, 1)
	var stock_max := (3.0 * level * level - 5.0 * level + 6.0) / 2.0
	if archetype == BOSS:
		return [
			floori(_balance("boss_gold_min_mult", 2.5) * stock_max),
			floori(_balance("boss_gold_max_mult", 5.0) * stock_max),
		]
	return [maxi(0, 2 * (level - 2)), floori(stock_max)]


## XP awarded to each living party member: round(base_xp * 1.8^(N-1)), scaled by
## the expedition's endless tier.
static func xp_reward(archetype: String, n: int, tier := 0) -> int:
	var steps := maxi(n, 1) - 1
	var base := _balance("enemy_%s_xp_base" % archetype, 1.0)
	return endless_xp(roundi(base * pow(_balance("enemy_xp_growth", 1.8), steps)), tier)


## A minion (the Lich's raised skeletons) drops no gold and pays half XP,
## floored — and only for its first summon per expedition, which the battle
## loop tracks. The penalty lands on the tier-scaled XP rather than the base,
## which is the order BalanceNumbers "Endless mode" specifies.
static func minion_xp_reward(archetype: String, n: int, tier := 0) -> int:
	return floori(xp_reward(archetype, n, tier) * _balance("minion_xp_penalty", 0.5))


## Endless tier scaling (BalanceNumbers "Endless mode"). Endless adds no new
## dungeon levels — there are only ever 4 — so a tier re-runs the same level with
## tougher enemies and richer drops. The scaling is additive rather than
## compounded, which keeps endless enemies on the same broadly linear curve as
## uncapped adventurer levels.
##
## Every one of these is a no-op at tier 0, so the whole campaign before the win
## runs the unscaled numbers the balance anchors were tuned against.

## Fold tier [param tier] into a spawned enemy's stats, in place. HP and power
## only: evasion and accuracy are untouched by endless tiers, which is why the
## hero panel's display rule needs no endless special case.
static func apply_endless_tier(stats: Dictionary, tier: int) -> void:
	if tier <= 0 or stats.is_empty():
		return
	stats["hp"] = float(roundi(
		stats["hp"] * (1.0 + _balance("endless_hp_per_tier", 0.25) * tier)))
	stats["power"] = stats["power"] + _balance("endless_power_per_tier", 1.0) * tier


## [param base_xp] at tier [param tier].
static func endless_xp(base_xp: int, tier: int) -> int:
	if tier <= 0:
		return base_xp
	return maxi(1, roundi(base_xp * (1.0 + _balance("endless_xp_per_tier", 0.2) * tier)))


## One ROLLED gold drop at tier [param tier]. The roll is scaled first and a gold
## trait's multiplier is applied to the result (BalanceNumbers "Endless mode"),
## so the caller multiplies after calling this, never before.
static func endless_gold(gold_roll: int, tier: int) -> int:
	if tier <= 0:
		return gold_roll
	return roundi(gold_roll * (1.0 + _balance("endless_gold_per_tier", 0.2) * tier))


static func _entry(variant_id: String) -> Dictionary:
	_ensure_loaded()
	return _bestiary.get(variant_id, {})


static func _ensure_loaded() -> void:
	if _bestiary.is_empty():
		_load_csv()


## BalanceData.get_value for static context — Godot 4.7 cannot resolve autoload
## identifiers inside static functions, so it is fetched through the tree
## (same shim as ClassStats._balance).
static func _balance(id: String, default_value: float) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return default_value
	var balance := tree.root.get_node_or_null("BalanceData")
	if balance == null:
		return default_value
	return balance.get_value(id, default_value)


static func _load_csv() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("EnemyStats: could not open %s" % CSV_PATH)
		return
	file.get_csv_line() # skip header row
	while file.get_position() < file.get_length():
		var row := file.get_csv_line()
		if row.size() < 9 or row[0].is_empty():
			continue
		_bestiary[row[0]] = {
			"display_name": row[1],
			"dungeon": row[2].to_int(),
			"archetype": row[3],
			"stock_grunt": row[4].to_int() == 1,
			"hp_delta": row[5].to_float(),
			"power_delta": row[6].to_float(),
			"speed_delta": row[7].to_float(),
			"signature": row[8],
		}
	file.close()
