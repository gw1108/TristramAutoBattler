extends Node

# Throwaway sweep harness for the dungeon-4 morale attrition pass.
# Run as a SCENE (autoloads must exist): godot --headless --path lord-of-hirelings res://verify_morale.tscn

const RUNS := 120

const PARTIES := {
	"front": ["Knight", "Cleric", "Berserker"],
	"mixed": ["Captain", "Mage", "Rogue"],
	"tanky": ["Knight", "Captain", "Cleric"],
}

# Candidate dial settings. "base" must reproduce today's game exactly.
const CANDIDATES := [
	{"name": "base (today)", "dials": {}},
	{"name": "panic 0.4 (doc's named dial)", "dials": {"panic_morale_threshold": 0.4}},
	{"name": "panic 0.35", "dials": {"panic_morale_threshold": 0.35}},
	{"name": "moraledmg x0.5", "dials": {"enemy_morale_damage_per_level": 0.5}},
	{"name": "moraledmg x0.25", "dials": {"enemy_morale_damage_per_level": 0.25}},
	{"name": "cower 40%", "dials": {"cowering_morale_restore_pct": 0.4}},
	{"name": "morale growth 3/2lv", "dials": {"growth_morale_per_2_levels": 3.0}},
	{"name": "mdmg x0.5 + cower 35%", "dials": {
		"enemy_morale_damage_per_level": 0.5, "cowering_morale_restore_pct": 0.35}},
	{"name": "mdmg x0.5 + growth 2/2lv", "dials": {
		"enemy_morale_damage_per_level": 0.5, "growth_morale_per_2_levels": 2.0}},
	{"name": "mdmg x0.5 + cower 35% + growth 2", "dials": {
		"enemy_morale_damage_per_level": 0.5, "cowering_morale_restore_pct": 0.35,
		"growth_morale_per_2_levels": 2.0}},
]


func _ready() -> void:
	print("=== sanity: is the EARLY game even working? clear rate by dungeon level ===")
	_restore({})
	for n: int in [1, 2, 3, 4]:
		var gate: int = 2 * n - 1
		var line := "  dungeon %d (gate avg level %d): " % [n, gate]
		for level: int in [gate, gate + 2, gate + 5]:
			line += "L%-2d %3.0f%%  " % [level, 100.0 * _clear_rate("front", level, n)]
		print(line)

	print("\n=== candidate dials: dungeon 4 clear rate by party level (front party) ===")
	print("  %-32s %s" % ["dial", "L7    L9    L12   L16   L20   L30   L60"])
	for cand in CANDIDATES:
		_restore(cand["dials"])
		var line := "  %-32s " % cand["name"]
		for level in [7, 9, 12, 16, 20, 30, 60]:
			line += "%4.0f%% " % (100.0 * _clear_rate("front", level, 4))
		print(line)
	_restore({})

	print("\n=== candidate dials: does dungeon 1 stay honest? (level-1 party, dungeon 1) ===")
	for cand in CANDIDATES:
		_restore(cand["dials"])
		print("  %-32s L1 %3.0f%%  L2 %3.0f%%  L3 %3.0f%%" % [
			cand["name"], 100.0 * _clear_rate("front", 1, 1),
			100.0 * _clear_rate("front", 2, 1), 100.0 * _clear_rate("front", 3, 1)])
	_restore({})

	print("\n=== candidate dials: all three party comps at dungeon 4, level 12 & 20 ===")
	for cand in CANDIDATES:
		_restore(cand["dials"])
		var line := "  %-32s " % cand["name"]
		for pname in PARTIES:
			line += "%s L12 %3.0f%% L20 %3.0f%% | " % [
				pname, 100.0 * _clear_rate(pname, 12, 4), 100.0 * _clear_rate(pname, 20, 4)]
		print(line)
	_restore({})

	get_tree().quit()


func _restore(dials: Dictionary) -> void:
	BalanceData._load_csv()
	for id in dials:
		BalanceData._values[id] = dials[id]


func _clear_rate(party_name: String, level: int, dungeon: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d" % [party_name, level, dungeon])
	var cleared := 0
	for _i in RUNS:
		var party := []
		for cls in PARTIES[party_name]:
			party.append({"name": cls, "class": cls, "level": level, "xp": 0, "gold": 0})
		var dive := Expedition.run_dive(party, Encounters.build_level(dungeon, 5, rng), rng)
		if dive["outcome"] == "cleared":
			cleared += 1
	return float(cleared) / RUNS
