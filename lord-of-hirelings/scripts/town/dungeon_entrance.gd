extends Area2D
## The mine mouth at the east map edge, beside the dungeon bell (GDD): once the
## bell has rung and the parties are formed, the lord walks to the entrance and
## interacts to send the expedition down. The GDD's "move to the dungeon and hit
## enter" is the normal Interact action, not an Enter binding.
##
## The prompt only shows during the call to arms and only with at least one
## non-empty party — at night or during recruitment the mine is just scenery.
## Until the dive scene exists, entering resolves the whole expedition in one
## call (Expedition.resolve) and applies its summary, then returns the world to
## night; the scene will replay the fights the summary already contains.

const PROMPT_ENTER := "[E] Enter the dungeon"

## Placeholder mine mouth until the portal art lands (art asset list).
const FRAME_COLOR := Color("5a4632")
const FRAME_DARK := Color("3d2f22")
const MOUTH_COLOR := Color("120d0a")
const ROCK_COLOR := Color("4a4640")

@onready var _prompt: Label = $PromptLabel
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _player_near := false


func _ready() -> void:
	position = Vector2(
		BalanceData.get_value("dungeon_entrance_town_pos_x", 1872.0),
		BalanceData.get_value("dungeon_entrance_town_pos_y", 592.0))
	(_shape.shape as CircleShape2D).radius = BalanceData.get_value(
		"dungeon_entrance_interact_radius", 48.0)
	InteractPrompt.style(_prompt)
	InteractPrompt.set_text(_prompt, PROMPT_ENTER)
	_prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.phase_changed.connect(_on_phase_changed)


func _process(_delta: float) -> void:
	# Only the nearest in-range interactable shows its prompt, and only while
	# the expedition is actually ready to march.
	_prompt.visible = _player_near and _can_enter() and InteractPrompt.is_nearest(self)


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and _prompt.visible and _can_enter() and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		enter()


func _can_enter() -> bool:
	if GameState.phase != GameState.Phase.CALL_TO_ARMS:
		return false
	for party in Roster.parties:
		if not party.is_empty():
			return true
	return false


## Sends the formed parties down the mine. Public so tests/harnesses can
## trigger it. Returns the expedition summary (the summary panel's data, once it
## exists), or an empty dictionary if the expedition could not march.
func enter() -> Dictionary:
	if not _can_enter():
		return {}
	_prompt.visible = false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var summary := Expedition.resolve(
		Roster.parties, GameState.day, GameState.unlocked_dungeon_level, rng)
	_apply(summary)
	# Nightfall dissolves the parties (Roster clears them off the phase change),
	# so everything the summary owes the town is paid before this.
	GameState.return_to_night()
	# The panel is the payoff screen, not the bookkeeping: the roster has already
	# been paid above, and this animates what landed over the settled town.
	var panel := get_tree().get_first_node_in_group("expedition_summary")
	if panel != null:
		panel.open(summary)
	return summary


## The summary is the source of truth for what the dive changed: the player's
## tax-copy, each survivor's level/XP/purse (Expedition has already spent their
## XP on level-ups and their gold is a total, not a delta), the dead, and the
## dungeon level a boss clear opened.
func _apply(summary: Dictionary) -> void:
	GameState.add_gold(summary["tax_copy"])
	GameState.unlock_dungeon_level(summary["unlocked_level"])
	var dead: Array[String] = []
	for dive in summary["dives"]:
		for row in dive["members"]:
			if not row["alive"]:
				dead.append(row["name"])
				continue
			var member := _member_named(row["name"])
			if member.is_empty():
				continue
			member["level"] = row["level"]
			member["xp"] = row["xp"]
			member["gold"] = row["gold"]
	# Burials come last: kill_member fires member_died and roster_changed, and a
	# listener that reads the roster back would otherwise see the survivors of
	# later parties still unpaid.
	for display_name in dead:
		Roster.kill_member(display_name)


## The roster entry behind a summary row, or {} if it is already gone. Matched by
## display name, which the roster's uniqueness rule guarantees is a key.
func _member_named(display_name: String) -> Dictionary:
	for member in Roster.members:
		if member["name"] == display_name:
			return member
	return {}


func _on_phase_changed(_new_phase: GameState.Phase) -> void:
	_prompt.visible = _player_near and _can_enter() and InteractPrompt.is_nearest(self)


func _draw() -> void:
	# Placeholder mine mouth cut into the rock face, bottom-center pivot
	# (~32x36px): a dark opening under a timbered frame.
	draw_rect(Rect2(-18, -38, 36, 38), ROCK_COLOR)
	draw_rect(Rect2(-12, -30, 24, 30), MOUTH_COLOR)
	draw_rect(Rect2(-15, -33, 3, 33), FRAME_COLOR)
	draw_rect(Rect2(12, -33, 3, 33), FRAME_COLOR)
	draw_rect(Rect2(-16, -36, 32, 3), FRAME_COLOR)
	draw_rect(Rect2(-16, -33, 32, 1), FRAME_DARK)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	InteractPrompt.register(self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	InteractPrompt.unregister(self)
	_prompt.visible = false
