extends Area2D
## A hireable adventurer at the inn (GDD town phase): recruits show up near
## the inn when the rooster crows. Name (GDD generator), class (uniform over
## the six classes), and base cost (GDD: randint(7, 9) at level 1) are all
## rolled once at generation. Press interact to hire: gold is spent via
## GameState.spend_gold and the adventurer joins the Roster autoload —
## hiring is disabled while the roster sits at its hard cap. Left-clicking
## the sprite opens the hero panel in its Variant B hire mode (mockups/
## hero-panel.html), a mouse-only hire path alongside the [E] prompt.

const ContactShadowScript := preload("res://scripts/town/contact_shadow.gd")

## 4 class-flavored adventurer variants (knight, berserker, mage, rogue) in a
## 1x6 sheet of 48px cells, bottom-center pivot. One variant per spawn slot so
## a day's batch reads as distinct people. Source: generate_recruit_sprites.py.
const VARIANT_SHEET := preload("res://sprites/recruits/recruit_variants.png")
const VARIANT_COUNT := 6
const SHEET_CELL_PX := 48

## Sheet column per class, so the sprite reads as the rolled class.
const CLASS_VARIANTS := {
	"Knight": 0, "Berserker": 1, "Mage": 2,
	"Rogue": 3, "Captain": 4, "Cleric": 5,
}

## Layer the click-pick Area2D sits on (matches hired_adventurer.gd): physics
## picking ignores objects with no layer, and this bit is masked by nothing.
const CLICK_PICK_LAYER := 1 << 7

var variant_index := 0
var hire_cost := 0
var display_name := ""
var adventurer_class := ""

var _prompt: Label
var _player_near := false
var _click_area: Area2D
## Set once the call to arms sends this recruit walking off screen; a
## leaving recruit can no longer be hired or inspected (GDD).
var _leaving := false


func _ready() -> void:
	var cost_min := int(BalanceData.get_value("recruit_hire_cost_min", 7.0))
	var cost_max := int(BalanceData.get_value("recruit_hire_cost_max", 9.0))
	hire_cost = randi_range(cost_min, maxi(cost_min, cost_max))
	adventurer_class = Roster.roll_class()
	display_name = Roster.generate_unique_name()
	# Visible at the inn from now on, so later rolls must avoid this name.
	Roster.reserve_name(display_name)
	# First child so the shadow renders beneath the sprite (style guide §4).
	add_child(ContactShadowScript.new())
	var sprite := Sprite2D.new()
	sprite.texture = VARIANT_SHEET
	sprite.hframes = VARIANT_COUNT
	sprite.frame = CLASS_VARIANTS.get(adventurer_class, variant_index % VARIANT_COUNT)
	# Lift the centered cell so its bottom edge sits on the pivot (feet on
	# the ground at this node's position, like every character in the game).
	sprite.offset = Vector2(0, -SHEET_CELL_PX / 2.0)
	var sprite_scale := BalanceData.get_value("recruit_sprite_scale", 1.0)
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BalanceData.get_value("recruit_interact_radius", 40.0)
	shape.shape = circle
	add_child(shape)
	# Left-click-to-inspect: a pickable Area2D sized to the sprite (not the
	# whole interact radius) opens the hero panel's hire view.
	var click_area := Area2D.new()
	_click_area = click_area
	click_area.collision_layer = CLICK_PICK_LAYER
	click_area.collision_mask = 0
	click_area.input_pickable = true
	var click_shape := CollisionShape2D.new()
	var click_rect := RectangleShape2D.new()
	click_rect.size = Vector2(SHEET_CELL_PX, SHEET_CELL_PX) * sprite_scale
	click_shape.shape = click_rect
	click_shape.position = Vector2(0.0, -SHEET_CELL_PX * sprite_scale / 2.0)
	click_area.add_child(click_shape)
	click_area.input_event.connect(_on_click_area_input)
	add_child(click_area)
	_prompt = Label.new()
	# Just above the 48px sprite so the text never covers the face;
	# InteractPrompt.set_text re-centers it on every text change.
	_prompt.position = Vector2(0, -SHEET_CELL_PX - 16)
	InteractPrompt.style(_prompt)
	_prompt.visible = false
	add_child(_prompt)
	set_process(false)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.gold_changed.connect(_on_gold_changed)
	Roster.roster_changed.connect(_on_roster_changed)


func _exit_tree() -> void:
	# Leaving unhired frees the name for future rolls; a hired name stays
	# taken through the roster itself.
	Roster.release_name(display_name)
	InteractPrompt.unregister(self)


func _process(_delta: float) -> void:
	# Interact radii of adjacent recruits overlap; only the nearest one
	# shows its prompt (runs only while the player is in range).
	_prompt.visible = InteractPrompt.is_nearest(self)


func _unhandled_input(event: InputEvent) -> void:
	# Gate on the visible prompt so the [E] press always goes to the one
	# interactable whose prompt the player is reading, never the whole row.
	if _player_near and _prompt.visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		hire()


## Attempts the hire: refuses at the roster cap, spends gold, then records
## the adventurer on the Roster. A sponsored hire costs double and hands the
## adventurer their pre-discount base cost as personal gold (BalanceNumbers
## "Hire + Sponsor"). Returns whether the hire went through. Public so the
## hero panel and tests/harnesses can trigger it.
func hire(sponsored: bool = false) -> bool:
	# From the moment the call to arms begins, hiring is impossible until
	# the next day's crow (GDD) — a walking-away recruit can't be hired.
	if _leaving or Roster.is_full():
		return false
	var price := hire_cost * 2 if sponsored else hire_cost
	if not GameState.spend_gold(price):
		return false
	Roster.add_member(display_name, adventurer_class, 1, hire_cost if sponsored else 0)
	queue_free()
	return true


## Sends the recruit walking off toward the nearest horizontal map edge and
## frees them on arrival (GDD call to arms: every unhired recruit immediately
## walks off screen). All interaction is disabled the moment this is called.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	set_deferred("monitoring", false)
	_click_area.input_pickable = false
	_prompt.visible = false
	set_process(false)
	set_process_unhandled_input(false)
	InteractPrompt.unregister(self)
	var map_width := BalanceData.get_value("town_map_width", 1920.0)
	var edge_x: float = -SHEET_CELL_PX if position.x < map_width / 2.0 \
			else map_width + SHEET_CELL_PX
	var speed := BalanceData.get_value("hired_move_speed", 60.0)
	var tween := create_tween()
	tween.tween_property(self, "position:x", edge_x, absf(edge_x - position.x) / speed)
	tween.tween_callback(queue_free)


func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var panel := get_tree().get_first_node_in_group("hero_panel")
		if panel != null:
			panel.open_for_recruit(self)


func _refresh_prompt() -> void:
	if Roster.is_full():
		InteractPrompt.set_text(_prompt, "Roster full (%d)" % Roster.max_size())
	elif GameState.can_afford(hire_cost):
		InteractPrompt.set_text(_prompt, "[E] Hire %s (%s) — %dg" % [display_name, adventurer_class, hire_cost])
	else:
		InteractPrompt.set_text(_prompt, "%s (%s) — %dg (not enough gold)" % [display_name, adventurer_class, hire_cost])


func _on_gold_changed(_new_gold: int) -> void:
	if _player_near:
		_refresh_prompt()


func _on_roster_changed() -> void:
	if _player_near:
		_refresh_prompt()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	_refresh_prompt()
	InteractPrompt.register(self)
	_prompt.visible = InteractPrompt.is_nearest(self)
	set_process(true)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	InteractPrompt.unregister(self)
	_prompt.visible = false
	set_process(false)
