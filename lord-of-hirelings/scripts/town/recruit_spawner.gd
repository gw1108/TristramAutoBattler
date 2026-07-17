extends Node2D
## Spawns hireable recruit NPCs near the inn when a new day starts (GDD town
## phase: the rooster crow brings adventurers looking for work). Yesterday's
## unhired recruits are cleared first so repeat crows never pile bodies up
## in the same spot. Unhired recruits do not persist: they leave at nightfall
## (GDD balance notes), so the spawner also clears on the NIGHT phase change.
## Counts and placement come from balance.csv.

const RecruitScript := preload("res://scripts/town/recruit.gd")

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(new_phase: GameState.Phase) -> void:
	if new_phase == GameState.Phase.NIGHT:
		for child in get_children():
			child.queue_free()


func _on_day_advanced(_new_day: int) -> void:
	for child in get_children():
		child.queue_free()
	var min_count := int(BalanceData.get_value("recruits_per_day_min", 1.0))
	var max_count := int(BalanceData.get_value("recruits_per_day_max", 3.0))
	var count := _rng.randi_range(min_count, maxi(min_count, max_count))
	var center := Vector2(
		BalanceData.get_value("recruit_spawn_center_x", 860.0),
		BalanceData.get_value("recruit_spawn_center_y", 560.0))
	var spacing := BalanceData.get_value("recruit_spawn_spacing_px", 52.0)
	var jitter_y := BalanceData.get_value("recruit_spawn_jitter_y_px", 8.0)
	for i in count:
		var recruit := RecruitScript.new() as Node2D
		# Fixed spacing along a row (not random offsets) so recruits can
		# never spawn interpenetrating each other or stack on one pixel.
		recruit.position = center + Vector2(
			(i - (count - 1) / 2.0) * spacing,
			_rng.randf_range(-jitter_y, jitter_y))
		recruit.variant_index = i
		add_child(recruit)
