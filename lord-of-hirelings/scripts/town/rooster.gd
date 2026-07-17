extends Area2D
## The rooster: the town's day-start interactable (GDD day cycle). Walk up
## and press interact to make it crow, which starts a new day via
## GameState.advance_day(). The GDD gates crowing on night returning after
## an expedition; until the expedition/night cycle exists, a cooldown from
## balance.csv stands in for that rule so the day counter is exercisable.

const PROMPT_READY := "[E] Wake the rooster"
const PROMPT_DOZING := "The rooster dozes..."

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
	_prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_prompt.text = PROMPT_READY


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and _cooldown <= 0.0 and event.is_action_pressed("interact"):
		crow()


## Crows and starts the new day. Public so tests/harnesses can trigger it.
func crow() -> void:
	GameState.advance_day()
	_cooldown = _crow_cooldown_sec
	_prompt.text = PROMPT_DOZING
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.25), 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)


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
	_prompt.text = PROMPT_READY if _cooldown <= 0.0 else PROMPT_DOZING
	_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_prompt.visible = false
