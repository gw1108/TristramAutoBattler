class_name ClassStats
extends Object
## Static reader for data/class_stats.csv — the BalanceNumbers "Adventurer
## base stats (level 1)" table — plus the growth-per-level rules and the
## displayed-evasion/accuracy percentage formulas from the same doc. The hero
## panel reads from here now; party formation and the combat sim reuse it
## later. The per-level growth increments and hit-formula constants live in
## balance.csv; the class table itself is structural data in its own CSV.

const CSV_PATH := "res://data/class_stats.csv"

## Column order in the CSV after the leading class column.
const STAT_KEYS := [
	"hp", "hp_regen", "power", "speed", "armor", "guard_pct",
	"evasion", "accuracy", "crit_pct", "crit_dmg_pct", "max_morale",
	"morale_regen",
]

static var _base: Dictionary = {}


## Level-1 base stats for a class, as {stat_key: float}. Empty on unknown class.
static func base_stats(adventurer_class: String) -> Dictionary:
	if _base.is_empty():
		_load_csv()
	var stats: Dictionary = _base.get(adventurer_class, {})
	return stats.duplicate()


## BalanceNumbers "Adventurer growth per level" applied to the level-1 base:
## +2 HP per level (Knight +3), +1 power on even levels, +12 evasion and
## accuracy per level, +1 max morale on odd levels after 1.
static func stats_at_level(adventurer_class: String, level: int) -> Dictionary:
	var stats := base_stats(adventurer_class)
	if stats.is_empty():
		return stats
	var levels_gained := maxi(level - 1, 0)
	var hp_per_level := _balance("growth_hp_per_level_knight", 3.0) \
			if adventurer_class == "Knight" \
			else _balance("growth_hp_per_level", 2.0)
	stats["hp"] += hp_per_level * levels_gained
	# Integer divisions step the bonus exactly on the levels the doc names.
	stats["power"] += _balance("growth_power_per_2_levels", 1.0) \
			* (maxi(level, 1) / 2)
	var rating_growth := _balance("growth_evasion_accuracy_per_level", 12.0)
	stats["evasion"] += rating_growth * levels_gained
	stats["accuracy"] += rating_growth * levels_gained
	stats["max_morale"] += _balance("growth_morale_per_2_levels", 1.0) \
			* (levels_gained / 2)
	return stats


## The dungeon level whose reference grunt the displayed percentages are
## computed against — the inverse of the 2N-1 party gate, clamped so endless
## readouts stay meaningful (BalanceNumbers "Displaying evasion and accuracy").
static func reference_dungeon_level(level: int) -> int:
	return clampi((level + 1) / 2, 1, 4)


## displayed_accuracy% = clamp(A * 1.25 * 100 / (A + ref_evasion * 0.3), 5, 100)
static func displayed_accuracy_pct(accuracy: float, level: int) -> int:
	var r := reference_dungeon_level(level)
	var ref_evasion := _balance("ref_grunt_evasion_per_level", 40.0) * r \
			+ _balance("ref_grunt_evasion_base", 20.0)
	var mult := _balance("hit_formula_accuracy_mult", 1.25)
	var weight := _balance("hit_formula_evasion_weight", 0.3)
	return roundi(clampf(
		accuracy * mult * 100.0 / (accuracy + ref_evasion * weight), 5.0, 100.0))


## displayed_evasion% = 100 - clamp(ref_acc * 1.25 * 100 / (ref_acc + E * 0.3), 5, 100)
static func displayed_evasion_pct(evasion: float, level: int) -> int:
	var r := reference_dungeon_level(level)
	var ref_accuracy := _balance("ref_grunt_accuracy_per_level", 40.0) * r \
			+ _balance("ref_grunt_accuracy_base", 60.0)
	var mult := _balance("hit_formula_accuracy_mult", 1.25)
	var weight := _balance("hit_formula_evasion_weight", 0.3)
	return roundi(100.0 - clampf(
		ref_accuracy * mult * 100.0 / (ref_accuracy + evasion * weight), 5.0, 100.0))


## BalanceData.get_value for static context. Godot 4.7 cannot resolve
## autoload identifiers inside static functions ("Identifier not found"),
## so the autoload is fetched through the scene tree instead.
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
		push_error("ClassStats: could not open %s" % CSV_PATH)
		return
	file.get_csv_line() # skip header row
	while file.get_position() < file.get_length():
		var row := file.get_csv_line()
		if row.size() < STAT_KEYS.size() + 1 or row[0].is_empty():
			continue
		var stats := {}
		for i in STAT_KEYS.size():
			stats[STAT_KEYS[i]] = row[i + 1].to_float()
		_base[row[0]] = stats
	file.close()
