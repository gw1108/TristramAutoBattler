extends CanvasLayer
## Minimal town HUD: live day counter and treasury gold readout, driven by
## the GameState autoload's signals so every gold/day change is visible in
## playtests without a debugger.

@onready var _day_label: Label = $DayLabel
@onready var _gold_label: Label = $GoldLabel


func _ready() -> void:
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.gold_changed.connect(_on_gold_changed)
	_on_day_advanced(GameState.day)
	_on_gold_changed(GameState.gold)


func _on_day_advanced(new_day: int) -> void:
	_day_label.text = "Day %d" % new_day


func _on_gold_changed(new_gold: int) -> void:
	_gold_label.text = "Gold: %d" % new_gold
