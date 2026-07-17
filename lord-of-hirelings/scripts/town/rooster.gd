extends Area2D
## The rooster: the town's day-start interactable (GDD day cycle). Walk up
## and press interact to make it crow, which starts a new day via
## GameState.advance_day(). Crowing is gated on GameState.is_night() (the GDD
## cycle: night -> crow -> day -> expedition -> night); a short cooldown from
## balance.csv additionally paces repeat crows while GameState.dev_force_night
## keeps the loop playtestable.

const PROMPT_READY := "[E] Wake the rooster"
const PROMPT_DOZING := "The rooster dozes..."
const PROMPT_DAY := "The rooster waits for nightfall..."

## Placeholder palette until the rooster sprites land (art asset list).
const BODY_COLOR := Color("7a3b2e")
const COMB_COLOR := Color("c23b22")
const BEAK_COLOR := Color("e8a33d")

@onready var _prompt: Label = $PromptLabel
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _crow_cooldown_sec: float
var _cooldown := 0.0
var _player_near := false


func _ready() -> void:
	position = Vector2(
		BalanceData.get_value("rooster_town_pos_x", 1056.0),
		BalanceData.get_value("rooster_town_pos_y", 444.0))
	(_shape.shape as CircleShape2D).radius = BalanceData.get_value(
		"rooster_interact_radius", 40.0)
	_crow_cooldown_sec = BalanceData.get_value("rooster_crow_cooldown_sec", 5.0)
	InteractPrompt.style(_prompt)
	_prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.phase_changed.connect(_on_phase_changed)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_refresh_prompt()
	if _player_near:
		# Only the nearest in-range interactable shows its prompt.
		_prompt.visible = InteractPrompt.is_nearest(self)


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and _prompt.visible and _can_crow() and event.is_action_pressed("interact"):
		crow()


func _can_crow() -> bool:
	return _cooldown <= 0.0 and GameState.is_night()


## Crows and starts the new day. Public so tests/harnesses can trigger it.
func crow() -> void:
	if not GameState.is_night():
		return
	GameState.advance_day()
	_cooldown = _crow_cooldown_sec
	_refresh_prompt()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.25), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)


func _refresh_prompt() -> void:
	if not GameState.is_night():
		InteractPrompt.set_text(_prompt, PROMPT_DAY)
	elif _cooldown > 0.0:
		InteractPrompt.set_text(_prompt, PROMPT_DOZING)
	else:
		InteractPrompt.set_text(_prompt, PROMPT_READY)


func _on_phase_changed(_new_phase: GameState.Phase) -> void:
	_refresh_prompt()


func _draw() -> void:
	# Placeholder rooster silhouette, bottom-center pivot (~16x24px).
	draw_circle(Vector2(0, -8), 8.0, BODY_COLOR)
	draw_circle(Vector2(2, -18), 4.0, BODY_COLOR)
	draw_rect(Rect2(0, -25, 3, 5), COMB_COLOR)
	draw_rect(Rect2(6, -19, 4, 2), BEAK_COLOR)


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
