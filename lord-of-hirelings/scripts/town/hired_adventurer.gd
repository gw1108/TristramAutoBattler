extends CharacterBody2D
## A hired adventurer wandering the town (GDD town phase: hired adventurers
## wander the town during the day). One exists per Roster entry, spawned by
## hired_adventurer_spawner.gd. Wander is a simple idle/walk drift: pause,
## pick a nearby point inside the town's built-up bounds, walk there, repeat.
## Collides with buildings (mask) but sits on no layer itself, so it never
## blocks the player. Left-clicking the sprite opens the hero panel (mouse
## only — no keyboard interact required).

const ContactShadowScript := preload("res://scripts/town/contact_shadow.gd")

## Same 1x6 class-variant sheet the inn recruits use (48px cells,
## bottom-center pivot), so a hire keeps the exact look they had at the inn.
const VARIANT_SHEET := preload("res://sprites/recruits/recruit_variants.png")
const VARIANT_COUNT := 6
const SHEET_CELL_PX := 48

## Sheet column per class (must match recruit.gd).
const CLASS_VARIANTS := {
	"Knight": 0, "Berserker": 1, "Mage": 2,
	"Rogue": 3, "Captain": 4, "Cleric": 5,
}

## Matches the Lord's collider so both characters hug buildings identically.
const COLLIDER_RADIUS := 7.0

## Layer the click-pick Area2D sits on. Physics picking ignores objects with
## no layer, so it needs one — this bit is masked by nothing, so the area
## never collides with anything.
const CLICK_PICK_LAYER := 1 << 7

## Progress below this fraction of full speed counts as stuck against a wall.
const STUCK_PROGRESS_FRACTION := 0.25
const STUCK_GIVE_UP_SEC := 0.6

var display_name := ""
var adventurer_class := ""

var _sprite: Sprite2D
var _move_speed := 0.0
var _idle_min := 0.0
var _idle_max := 0.0
var _step_px := 0.0
var _wander_bounds := Rect2()

var _target := Vector2.ZERO
var _idle_time_left := 0.0
var _stuck_time := 0.0


func _ready() -> void:
	_move_speed = BalanceData.get_value("hired_move_speed", 60.0)
	_idle_min = BalanceData.get_value("hired_idle_min_sec", 1.0)
	_idle_max = BalanceData.get_value("hired_idle_max_sec", 4.0)
	_step_px = BalanceData.get_value("hired_wander_step_px", 160.0)
	var town_size := Vector2(
		BalanceData.get_value("town_map_width", 1920.0),
		BalanceData.get_value("town_map_height", 1080.0))
	var margin := Vector2(
		BalanceData.get_value("hired_wander_margin_x", 480.0),
		BalanceData.get_value("hired_wander_margin_y", 320.0))
	_wander_bounds = Rect2(margin, town_size - margin * 2.0)
	# Wanderers collide with the world (buildings) but occupy no layer, so
	# they never block the Lord or each other.
	collision_layer = 0
	collision_mask = 1
	# First child so the shadow renders beneath the sprite (style guide §4).
	add_child(ContactShadowScript.new())
	_sprite = Sprite2D.new()
	_sprite.texture = VARIANT_SHEET
	_sprite.hframes = VARIANT_COUNT
	_sprite.frame = CLASS_VARIANTS.get(adventurer_class, 0)
	# Bottom edge on the pivot: feet on the ground like every character.
	_sprite.offset = Vector2(0, -SHEET_CELL_PX / 2.0)
	var sprite_scale := BalanceData.get_value("recruit_sprite_scale", 1.0)
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLLIDER_RADIUS
	shape.shape = circle
	shape.position = Vector2(0, -COLLIDER_RADIUS)
	add_child(shape)
	# Left-click-to-inspect: a pickable Area2D sized to the whole sprite gives
	# a far bigger click target than the feet collider.
	var click_area := Area2D.new()
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
	_start_idle()


func _physics_process(delta: float) -> void:
	if _idle_time_left > 0.0:
		_idle_time_left -= delta
		if _idle_time_left <= 0.0:
			_pick_target()
		return
	var to_target := _target - position
	if to_target.length() <= _move_speed * delta:
		position = _target
		_start_idle()
		return
	velocity = to_target.normalized() * _move_speed
	var before := position
	move_and_slide()
	_sprite.flip_h = velocity.x < 0.0
	# Sliding along a building can stall progress forever; give up on the
	# target after a short stuck window and idle instead.
	if position.distance_to(before) < _move_speed * delta * STUCK_PROGRESS_FRACTION:
		_stuck_time += delta
		if _stuck_time >= STUCK_GIVE_UP_SEC:
			_start_idle()
	else:
		_stuck_time = 0.0


func _on_click_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var panel := get_tree().get_first_node_in_group("hero_panel")
		if panel != null:
			panel.open(display_name)


func _start_idle() -> void:
	velocity = Vector2.ZERO
	_stuck_time = 0.0
	_idle_time_left = randf_range(_idle_min, maxf(_idle_min, _idle_max))


## Picks the next wander point: a short random leg from here, clamped inside
## the built-up town bounds so wanderers never drift to the empty map edges.
func _pick_target() -> void:
	var leg := Vector2.from_angle(randf() * TAU) * randf_range(_step_px * 0.25, _step_px)
	_target = (position + leg).clamp(
		_wander_bounds.position, _wander_bounds.end)
