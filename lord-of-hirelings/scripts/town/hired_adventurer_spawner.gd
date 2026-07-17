extends Node2D
## Keeps one wandering hired-adventurer NPC in the town per Roster entry
## (GDD town phase: hired adventurers wander the town). New hires step out
## near the inn — where they were just standing as recruits — and then
## drift on their own. Party formation pulls from the Roster in a later
## slice; this node only mirrors it visually.

const HiredAdventurerScript := preload("res://scripts/town/hired_adventurer.gd")

## Spawned NPCs keyed by roster display name (names are unique per Roster).
var _spawned := {}


func _ready() -> void:
	Roster.roster_changed.connect(_sync_to_roster)
	_sync_to_roster()


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
		# Step out just south of the inn's recruit row, with jitter so
		# same-day hires never stack on one pixel.
		npc.position = Vector2(
			BalanceData.get_value("recruit_spawn_center_x", 860.0),
			BalanceData.get_value("recruit_spawn_center_y", 560.0))
		npc.position += Vector2(randf_range(-24.0, 24.0), randf_range(12.0, 36.0))
		add_child(npc)
		_spawned[member_name] = npc
	# Despawn wanderers whose roster entry is gone (deaths remove members).
	for member_name in _spawned.keys():
		if not live.has(member_name):
			_spawned[member_name].queue_free()
			_spawned.erase(member_name)
