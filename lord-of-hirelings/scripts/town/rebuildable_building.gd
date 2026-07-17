extends StaticBody2D
## Shared script for the rebuildable town buildings (weapon shop, armor shop,
## jewelry shop, training grounds). Every building but the Inn starts ruined
## per the GDD. Walk up and press interact to spend the next level's cost from
## the treasury (GameState.spend_gold): the first press rebuilds the ruin into
## a level 1 building, and each one after buys the next level of the ladder.
## A static prop with a base-footprint collider, like the Inn.
##
## The level is what the building's own systems read — a shop stocks gear tiers
## by it (Items.stocked_max_tier via Shops.shop_level) — so this node owns the
## purchase and GameState owns the number.
##
## Parameterized by building_id: textures load from
## res://sprites/town/<id>_{ruined,normal}.png and position/radius/ladder top
## come from the <id>_town_pos_x/_town_pos_y/_interact_radius/_max_offered_level
## rows in balance.csv.

## Balance-row prefix and sprite filename stem, e.g. "weapon_shop".
@export var building_id := ""

## Sprite height in px (bottom-center pivot); the prompt floats just above
## the roofline so it never covers the building art.
@export var sprite_height_px := 128

## Missing-row fallbacks only — balance.csv is the source of truth; keep
## these in sync with the building's rows there.
@export var fallback_town_pos := Vector2(1072, 712)
@export var fallback_interact_radius := 72.0
@export var fallback_max_offered_level := 3

@onready var _sprite: Sprite2D = $Sprite

var _level := 0
## The top of this building's ladder as it stands today. Levels run to
## GameState.MAX_BUILDING_LEVEL, but a level the player cannot yet feel is a
## level that must not be for sale: a shop stops at 3, which is the level that
## stocks every gear tier, because 4 and 5 buy its two shop-wide gear lines
## (BalanceNumbers "Shop-wide gear lines") and those are a later slice. The
## training grounds stops at 1 for the same reason.
var _max_offered_level := 3
var _ruined_texture: Texture2D
var _normal_texture: Texture2D
var _prompt: Label
var _player_near := false


func _ready() -> void:
	_ruined_texture = load("res://sprites/town/%s_ruined.png" % building_id)
	_normal_texture = load("res://sprites/town/%s_normal.png" % building_id)
	position = Vector2(
		BalanceData.get_value(building_id + "_town_pos_x", fallback_town_pos.x),
		BalanceData.get_value(building_id + "_town_pos_y", fallback_town_pos.y))
	_max_offered_level = int(BalanceData.get_value(
		building_id + "_max_offered_level", float(fallback_max_offered_level)))
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
	# GameState is the source of truth rather than this node, so a rebuild the
	# player paid for in an earlier session is still standing when the campaign
	# autosave restores it. A fresh campaign has no level recorded here, and
	# building_level answers 0 for that — the ruin the GDD starts every
	# building but the Inn as.
	set_level(GameState.building_level(building_id))


func _exit_tree() -> void:
	InteractPrompt.unregister(self)


func _process(_delta: float) -> void:
	# Only the nearest in-range interactable shows its prompt (runs only
	# while the player is in range).
	_prompt.visible = _has_offer() and InteractPrompt.is_nearest(self)


func _unhandled_input(event: InputEvent) -> void:
	# Gate on the visible prompt so overlapping interactables never answer
	# the same [E] press.
	if _player_near and _prompt.visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		buy_next_level()


## Whether the building still has a level to sell the player.
func _has_offer() -> bool:
	return _level < _max_offered_level


## What the next level costs (BalanceNumbers "Building upgrade costs"): the flat
## rebuild price out of the ruin, then the 40/100/250/625 ladder. The rows in
## balance.csv are the source of truth; the fallback is the doc's own
## 40 * 2.5^(L-1), so a missing row costs what the table says it should.
func next_level_cost() -> int:
	if _level <= 0:
		return int(BalanceData.get_value("building_rebuild_cost", 10.0))
	return int(BalanceData.get_value(
		"building_upgrade_l%d_to_l%d_cost" % [_level, _level + 1],
		40.0 * pow(2.5, _level - 1)))


## Buys the next level: the rebuild out of the ruin, then a rung of the upgrade
## ladder. Public so tests/harnesses can trigger it. The call to arms locks all
## town changes for the expedition (GDD), so building waits for the next night.
func buy_next_level() -> void:
	if GameState.phase == GameState.Phase.CALL_TO_ARMS:
		return
	if _has_offer() and GameState.spend_gold(next_level_cost()):
		set_level(_level + 1)


## Applies [param level] to the node and records it on GameState, which is what
## the shop reads. The GDD gives levels 3-4 and 5 their own art (upgraded, max
## upgraded); until those sprites exist every standing level wears the normal
## one, and only the ruin looks different.
func set_level(level: int) -> void:
	_level = clampi(level, 0, GameState.MAX_BUILDING_LEVEL)
	GameState.set_building_level(building_id, _level)
	_sprite.texture = _ruined_texture if _level <= 0 else _normal_texture
	_refresh_prompt()
	_sync_registration()


func _refresh_prompt() -> void:
	if not _has_offer():
		_prompt.visible = false
		return
	var cost := next_level_cost()
	var action := "Rebuild" if _level <= 0 else "Upgrade to level %d" % (_level + 1)
	if GameState.can_afford(cost):
		InteractPrompt.set_text(_prompt, "[E] %s — %dg" % [action, cost])
	else:
		InteractPrompt.set_text(_prompt, "%s — %dg (not enough gold)" % [action, cost])


## A building with nothing left to sell shows no prompt, so it must not compete
## for the nearest-prompt slot either.
func _sync_registration() -> void:
	if _player_near and _has_offer():
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
	_prompt.visible = _has_offer() and InteractPrompt.is_nearest(self)
	set_process(true)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_sync_registration()
	_prompt.visible = false
	set_process(false)
