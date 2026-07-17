extends StaticBody2D
## Shared script for the rebuildable town buildings (weapon shop, armor shop,
## jewelry shop, training grounds). Every building but the Inn starts ruined
## per the GDD. Walk up and press interact to spend the rebuild cost from the
## treasury (GameState.spend_gold) and restore the building. Shop
## inventory/UI come in later slices.
## A static prop with a base-footprint collider, like the Inn.
##
## Parameterized by building_id: textures load from
## res://sprites/town/<id>_{ruined,normal}.png and position/radius come from
## the <id>_town_pos_x/_town_pos_y/_interact_radius rows in balance.csv.

## Balance-row prefix and sprite filename stem, e.g. "weapon_shop".
@export var building_id := ""

## Sprite height in px (bottom-center pivot); the prompt floats just above
## the roofline so it never covers the building art.
@export var sprite_height_px := 128

## Missing-row fallbacks only — balance.csv is the source of truth; keep
## these in sync with the building's rows there.
@export var fallback_town_pos := Vector2(1072, 712)
@export var fallback_interact_radius := 72.0

@onready var _sprite: Sprite2D = $Sprite

var rebuild_cost := 0
var _ruined_texture: Texture2D
var _normal_texture: Texture2D
var _ruined := true
var _prompt: Label
var _player_near := false


func _ready() -> void:
	_ruined_texture = load("res://sprites/town/%s_ruined.png" % building_id)
	_normal_texture = load("res://sprites/town/%s_normal.png" % building_id)
	position = Vector2(
		BalanceData.get_value(building_id + "_town_pos_x", fallback_town_pos.x),
		BalanceData.get_value(building_id + "_town_pos_y", fallback_town_pos.y))
	rebuild_cost = int(BalanceData.get_value("building_rebuild_cost", 10.0))
	_prompt = Label.new()
	_prompt.position = Vector2(0, -sprite_height_px - 16)
	InteractPrompt.style(_prompt)
	_prompt.visible = false
	add_child(_prompt)
	set_process(false)
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BalanceData.get_value(
		building_id + "_interact_radius", fallback_interact_radius)
	shape.shape = circle
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)
	GameState.gold_changed.connect(_on_gold_changed)
	set_ruined(true)


func _exit_tree() -> void:
	InteractPrompt.unregister(self)


func _process(_delta: float) -> void:
	# Only the nearest in-range interactable shows its prompt (runs only
	# while the player is in range).
	_prompt.visible = _ruined and InteractPrompt.is_nearest(self)


func _unhandled_input(event: InputEvent) -> void:
	# Gate on the visible prompt so overlapping interactables never answer
	# the same [E] press.
	if _player_near and _ruined and _prompt.visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		rebuild()


## Attempts the rebuild; on success the ruin becomes the standing building.
## Public so tests/harnesses can trigger it.
func rebuild() -> void:
	if _ruined and GameState.spend_gold(rebuild_cost):
		set_ruined(false)


func set_ruined(ruined: bool) -> void:
	_ruined = ruined
	GameState.set_building_state(
		building_id,
		GameState.BuildingState.RUINED if ruined else GameState.BuildingState.BUILT)
	_sprite.texture = _ruined_texture if ruined else _normal_texture
	_refresh_prompt()
	_sync_registration()


func _refresh_prompt() -> void:
	if not _ruined:
		_prompt.visible = false
		return
	if GameState.can_afford(rebuild_cost):
		InteractPrompt.set_text(_prompt, "[E] Rebuild — %dg" % rebuild_cost)
	else:
		InteractPrompt.set_text(_prompt, "Rebuild — %dg (not enough gold)" % rebuild_cost)


## A built (non-ruined) building shows no prompt, so it must not compete
## for the nearest-prompt slot either.
func _sync_registration() -> void:
	if _player_near and _ruined:
		InteractPrompt.register(self)
	else:
		InteractPrompt.unregister(self)


func _on_gold_changed(_new_gold: int) -> void:
	if _player_near:
		_refresh_prompt()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	_refresh_prompt()
	_sync_registration()
	_prompt.visible = _ruined and InteractPrompt.is_nearest(self)
	set_process(true)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_sync_registration()
	_prompt.visible = false
	set_process(false)
