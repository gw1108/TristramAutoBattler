extends StaticBody2D
## The Training grounds — the fifth building, an open yard (fence, sparring
## dummies, archery butt, weapon rack, small shed). Starts ruined per the GDD.
## Walk up and press interact to spend the rebuild cost from the treasury
## (GameState.spend_gold) and restore the yard. Training upgrades come later.
## A static prop with a base-footprint collider, like the shops.

const BUILDING_ID := "training_grounds"
const RUINED_TEXTURE := preload("res://sprites/town/training_grounds_ruined.png")
const NORMAL_TEXTURE := preload("res://sprites/town/training_grounds_normal.png")
const PROMPT_FONT := preload("res://fonts/pixel-operator/PixelOperator8.ttf")

## Sprite is 96px tall with a bottom-center pivot (an open yard, lower than
## the 128px shops); the prompt floats just above the fence line.
const SPRITE_HEIGHT_PX := 96

@onready var _sprite: Sprite2D = $Sprite

var rebuild_cost := 0
var _ruined := true
var _prompt: Label
var _player_near := false


func _ready() -> void:
	position = Vector2(
		BalanceData.get_value("training_grounds_town_pos_x", 624.0),
		BalanceData.get_value("training_grounds_town_pos_y", 512.0))
	rebuild_cost = int(BalanceData.get_value("building_rebuild_cost", 10.0))
	_prompt = Label.new()
	_prompt.position = Vector2(-100, -SPRITE_HEIGHT_PX - 12)
	_prompt.size = Vector2(200, 12)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", Color(0.93, 0.89, 0.75))
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_prompt.add_theme_constant_override("shadow_offset_x", 1)
	_prompt.add_theme_constant_override("shadow_offset_y", 1)
	_prompt.add_theme_font_override("font", PROMPT_FONT)
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.visible = false
	add_child(_prompt)
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BalanceData.get_value("training_grounds_interact_radius", 80.0)
	shape.shape = circle
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)
	GameState.gold_changed.connect(_on_gold_changed)
	set_ruined(true)


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and _ruined and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		rebuild()


## Attempts the rebuild; on success the ruin becomes the working yard.
## Public so tests/harnesses can trigger it.
func rebuild() -> void:
	if _ruined and GameState.spend_gold(rebuild_cost):
		set_ruined(false)


func set_ruined(ruined: bool) -> void:
	_ruined = ruined
	GameState.set_building_state(
		BUILDING_ID,
		GameState.BuildingState.RUINED if ruined else GameState.BuildingState.BUILT)
	_sprite.texture = RUINED_TEXTURE if ruined else NORMAL_TEXTURE
	_refresh_prompt()


func _refresh_prompt() -> void:
	if not _ruined:
		_prompt.visible = false
		return
	if GameState.can_afford(rebuild_cost):
		_prompt.text = "[E] Rebuild — %dg" % rebuild_cost
	else:
		_prompt.text = "Rebuild — %dg (not enough gold)" % rebuild_cost


func _on_gold_changed(_new_gold: int) -> void:
	if _player_near:
		_refresh_prompt()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	_refresh_prompt()
	_prompt.visible = _ruined


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_prompt.visible = false
