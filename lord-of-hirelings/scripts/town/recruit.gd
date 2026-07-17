extends Area2D
## A hireable adventurer at the inn (GDD town phase): recruits show up near
## the inn when the rooster crows. Walk up and press interact to hire one —
## the base cost (GDD: randint(7, 9) at level 1) is rolled once at spawn and
## paid from the treasury via GameState.spend_gold. Roster storage and the
## hero panel come in later slices; for now a hired recruit simply leaves.

const PROMPT_FONT := preload("res://fonts/pixel-operator/PixelOperator8.ttf")

## Placeholder palette until the recruit sprites land (art asset list).
## One tunic color per spawn slot so a day's batch reads as distinct people.
const TUNIC_COLORS: Array[Color] = [
	Color("5b7a3b"), Color("3b5b7a"), Color("7a5b3b"), Color("6b3b7a"),
]
const SKIN_COLOR := Color("d8a878")
const BOOT_COLOR := Color("4a3527")

var tunic_index := 0
var hire_cost := 0

var _prompt: Label
var _player_near := false


func _ready() -> void:
	var cost_min := int(BalanceData.get_value("recruit_hire_cost_min", 7.0))
	var cost_max := int(BalanceData.get_value("recruit_hire_cost_max", 9.0))
	hire_cost = randi_range(cost_min, maxi(cost_min, cost_max))
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BalanceData.get_value("recruit_interact_radius", 40.0)
	shape.shape = circle
	add_child(shape)
	_prompt = Label.new()
	_prompt.position = Vector2(-80, -40)
	_prompt.size = Vector2(160, 12)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", Color(0.93, 0.89, 0.75))
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_prompt.add_theme_constant_override("shadow_offset_x", 1)
	_prompt.add_theme_constant_override("shadow_offset_y", 1)
	_prompt.add_theme_font_override("font", PROMPT_FONT)
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.gold_changed.connect(_on_gold_changed)


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and event.is_action_pressed("interact"):
		# Interact radii of adjacent recruits overlap; claim the press so a
		# single [E] can never hire the whole row at once.
		get_viewport().set_input_as_handled()
		hire()


## Attempts the hire; on success the recruit leaves the inn (later slices add
## them to the roster instead). Public so tests/harnesses can trigger it.
func hire() -> void:
	if GameState.spend_gold(hire_cost):
		queue_free()


func _refresh_prompt() -> void:
	if GameState.can_afford(hire_cost):
		_prompt.text = "[E] Hire — %dg" % hire_cost
	else:
		_prompt.text = "Hire — %dg (not enough gold)" % hire_cost


func _on_gold_changed(_new_gold: int) -> void:
	if _player_near:
		_refresh_prompt()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	_refresh_prompt()
	_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_prompt.visible = false


func _draw() -> void:
	# Placeholder adventurer silhouette, bottom-center pivot (~12x22px).
	var tunic := TUNIC_COLORS[tunic_index % TUNIC_COLORS.size()]
	draw_rect(Rect2(-4, -4, 3, 4), BOOT_COLOR)
	draw_rect(Rect2(1, -4, 3, 4), BOOT_COLOR)
	draw_rect(Rect2(-5, -16, 10, 12), tunic)
	draw_circle(Vector2(0, -19), 4.0, SKIN_COLOR)
