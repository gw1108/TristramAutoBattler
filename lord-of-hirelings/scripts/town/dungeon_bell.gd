extends Area2D
## The bell next to the dungeon entrance (GDD): ringing it starts the call to
## arms, which ends the day's recruitment (unhired recruits walk off and
## hiring is impossible until the next crow), locks all town changes for the
## expedition, and forms the parties via Roster.form_parties(). The bell only
## works during the day, after the rooster has crowed — there is no calling
## to arms at night. Position/radius come from balance.csv; the bell sits by
## the east map edge where the mine portal will stand.

const PROMPT_READY := "[E] Ring the bell — call to arms!"
const PROMPT_NIGHT := "The bell waits for daybreak..."

## Placeholder palette until the bell art lands (art asset list).
const POST_COLOR := Color("5a4632")
const BELL_COLOR := Color("b08d3f")
const BELL_DARK := Color("7a5f28")

@onready var _prompt: Label = $PromptLabel
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _player_near := false


func _ready() -> void:
	position = Vector2(
		BalanceData.get_value("dungeon_bell_town_pos_x", 1808.0),
		BalanceData.get_value("dungeon_bell_town_pos_y", 528.0))
	(_shape.shape as CircleShape2D).radius = BalanceData.get_value(
		"dungeon_bell_interact_radius", 48.0)
	InteractPrompt.style(_prompt)
	_prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.phase_changed.connect(_on_phase_changed)


func _process(_delta: float) -> void:
	if _player_near:
		# Only the nearest in-range interactable shows its prompt.
		_prompt.visible = InteractPrompt.is_nearest(self)


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and _prompt.visible and _can_ring() and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		ring()


func _can_ring() -> bool:
	return GameState.phase == GameState.Phase.DAY


## Rings the bell: starts the call to arms and forms the expedition parties.
## Public so tests/harnesses can trigger it.
func ring() -> void:
	if not GameState.call_to_arms():
		return
	Roster.form_parties()
	_refresh_prompt()
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees", 12.0, 0.08)
	tween.tween_property(self, "rotation_degrees", -8.0, 0.12)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.15)


func _party_summary() -> String:
	var formed := 0
	for party in Roster.parties:
		if not party.is_empty():
			formed += 1
	if formed == 1:
		return "1 party formed — to the dungeon!"
	return "%d parties formed — to the dungeon!" % formed


func _refresh_prompt() -> void:
	match GameState.phase:
		GameState.Phase.DAY:
			InteractPrompt.set_text(_prompt, PROMPT_READY)
		GameState.Phase.CALL_TO_ARMS:
			InteractPrompt.set_text(_prompt, _party_summary())
		_:
			InteractPrompt.set_text(_prompt, PROMPT_NIGHT)


func _on_phase_changed(_new_phase: GameState.Phase) -> void:
	_refresh_prompt()


func _draw() -> void:
	# Placeholder bell on a wooden frame, bottom-center pivot (~20x30px).
	draw_rect(Rect2(-10, -30, 3, 30), POST_COLOR)
	draw_rect(Rect2(7, -30, 3, 30), POST_COLOR)
	draw_rect(Rect2(-12, -32, 24, 3), POST_COLOR)
	draw_rect(Rect2(-5, -28, 10, 8), BELL_COLOR)
	draw_rect(Rect2(-7, -21, 14, 3), BELL_DARK)
	draw_circle(Vector2(0, -16), 2.0, BELL_DARK)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = true
	_refresh_prompt()
	InteractPrompt.register(self)
	_prompt.visible = InteractPrompt.is_nearest(self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	InteractPrompt.unregister(self)
	_prompt.visible = false
