extends CanvasLayer
## Minimal town HUD: live day counter, night/day phase, and treasury gold
## readout, driven by the GameState autoload's signals so every gold/day/phase
## change is visible in playtests without a debugger.

const PHASE_COLOR_NIGHT := Color(0.55, 0.62, 0.85)
const PHASE_COLOR_DAY := Color(0.98, 0.86, 0.5)

@onready var _day_label: Label = $DayLabel
@onready var _phase_label: Label = $PhaseLabel
@onready var _gold_label: Label = $GoldLabel


func _ready() -> void:
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	_on_day_advanced(GameState.day)
	_on_gold_changed(GameState.gold)
	_on_phase_changed(GameState.phase)


func _on_day_advanced(new_day: int) -> void:
	_day_label.text = "Day %d" % new_day


func _on_phase_changed(new_phase: GameState.Phase) -> void:
	var is_day := new_phase == GameState.Phase.DAY
	_phase_label.text = "Day" if is_day else "Night"
	_phase_label.add_theme_color_override(
		"font_color", PHASE_COLOR_DAY if is_day else PHASE_COLOR_NIGHT
	)


func _on_gold_changed(new_gold: int) -> void:
	_gold_label.text = "Gold: %d" % new_gold
