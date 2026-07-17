extends Node2D
## Keeps one wandering hired-adventurer NPC in the town per Roster entry
## (GDD town phase: hired adventurers wander the town DURING THE DAY). New
## hires step out near the inn — where they were just standing as recruits —
## and then drift on their own. At nightfall everyone retires into the inn
## (hidden and fully disabled, mirroring how recruit_spawner clears unhired
## recruits on NIGHT); the rooster crow brings them back out at the doorstep.
## Party formation pulls from the Roster in a later slice; this node only
## mirrors it visually.

const HiredAdventurerScript := preload("res://scripts/town/hired_adventurer.gd")

## Spawned NPCs keyed by roster display name (names are unique per Roster).
var _spawned := {}


func _ready() -> void:
	Roster.roster_changed.connect(_sync_to_roster)
	GameState.phase_changed.connect(_on_phase_changed)
	_sync_to_roster()


func _on_phase_changed(new_phase: GameState.Phase) -> void:
	var indoors := new_phase == GameState.Phase.NIGHT
	for npc in _spawned.values():
		if not indoors:
			# They slept at the inn, so morning re-emergence starts there —
			# not wherever they happened to be standing at nightfall.
			npc.position = _inn_doorstep()
		_set_indoors(npc, indoors)


func _sync_to_roster() -> void:
	var live := {}
	for member in Roster.members:
		var member_name: String = member["name"]
		live[member_name] = true
		if _spawned.has(member_name):
			continue
		var npc := HiredAdventurerScript.new() as Node2D
		npc.display_name = member_name
		npc.adventurer_class = member["class"]
		npc.position = _inn_doorstep()
		add_child(npc)
		# A hire can land while it is already night (e.g. dev tooling); tuck
		# them straight into the inn so nobody wanders an empty night town.
		_set_indoors(npc, GameState.phase == GameState.Phase.NIGHT)
		_spawned[member_name] = npc
	# Despawn wanderers whose roster entry is gone (deaths remove members).
	for member_name in _spawned.keys():
		if not live.has(member_name):
			_spawned[member_name].queue_free()
			_spawned.erase(member_name)


## Where wanderers appear when leaving the inn: just south of the recruit
## row, with jitter so nobody ever stacks on one pixel.
func _inn_doorstep() -> Vector2:
	return Vector2(
		BalanceData.get_value("recruit_spawn_center_x", 860.0),
		BalanceData.get_value("recruit_spawn_center_y", 560.0)) \
		+ Vector2(randf_range(-24.0, 24.0), randf_range(12.0, 36.0))


## Indoors = asleep at the inn: invisible AND process-disabled, so a hidden
## body cannot still be clicked (Area2D picking ignores visibility) or nudge
## anything via physics while "inside".
func _set_indoors(npc: Node2D, indoors: bool) -> void:
	npc.visible = not indoors
	npc.process_mode = \
		Node.PROCESS_MODE_DISABLED if indoors else Node.PROCESS_MODE_INHERIT
