extends Area2D
## A hireable adventurer at the inn (GDD town phase): recruits show up near
## the inn when the rooster crows. Name (GDD generator), class (uniform over
## the six classes), and base cost (GDD: randint(7, 9) at level 1) are all
## rolled once at generation. Press interact to hire: gold is spent via
## GameState.spend_gold and the adventurer joins the Roster autoload —
## hiring is disabled while the roster sits at its hard cap. The hero panel
## comes in a later slice.

const PROMPT_FONT := preload("res://fonts/pixel-operator/PixelOperator8.ttf")
const ContactShadowScript := preload("res://scripts/town/contact_shadow.gd")

## 4 class-flavored adventurer variants (knight, berserker, mage, rogue) in a
## 1x4 sheet of 48px cells, bottom-center pivot. One variant per spawn slot so
## a day's batch reads as distinct people. Source: generate_recruit_sprites.py.
const VARIANT_SHEET := preload("res://sprites/recruits/recruit_variants.png")
const VARIANT_COUNT := 4
const SHEET_CELL_PX := 48

## Sheet column per class, so the sprite reads as the rolled class. Captain
## and Cleric have no dedicated variant yet and borrow the closest silhouette
## (armored knight / robed mage) until the sheet grows to six.
const CLASS_VARIANTS := {
	"Knight": 0, "Captain": 0, "Berserker": 1,
	"Mage": 2, "Cleric": 2, "Rogue": 3,
}

var variant_index := 0
var hire_cost := 0
var display_name := ""
var adventurer_class := ""

var _prompt: Label
var _player_near := false


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
	_prompt = Label.new()
	# Just above the 48px sprite so the text never covers the face. Wide
	# enough for "[E] Hire <name> (<class>) — NNg" at the 8px font.
	_prompt.position = Vector2(-140, -SHEET_CELL_PX - 12)
	_prompt.size = Vector2(280, 12)
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
	Roster.roster_changed.connect(_on_roster_changed)


func _exit_tree() -> void:
	# Leaving unhired frees the name for future rolls; a hired name stays
	# taken through the roster itself.
	Roster.release_name(display_name)


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and event.is_action_pressed("interact"):
		# Interact radii of adjacent recruits overlap; claim the press so a
		# single [E] can never hire the whole row at once.
		get_viewport().set_input_as_handled()
		hire()


## Attempts the hire: refuses at the roster cap, spends gold, then records
## the adventurer on the Roster. Public so tests/harnesses can trigger it.
func hire() -> void:
	if Roster.is_full():
		return
	if GameState.spend_gold(hire_cost):
		Roster.add_member(display_name, adventurer_class)
		queue_free()


func _refresh_prompt() -> void:
	if Roster.is_full():
		_prompt.text = "Roster full (%d)" % Roster.max_size()
	elif GameState.can_afford(hire_cost):
		_prompt.text = "[E] Hire %s (%s) — %dg" % [display_name, adventurer_class, hire_cost]
	else:
		_prompt.text = "%s (%s) — %dg (not enough gold)" % [display_name, adventurer_class, hire_cost]


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
	_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_prompt.visible = false
