extends Control
## "You Win!" — the campaign's ending (GDD). A party has cleared dungeon level
## 4's boss, which is the whole win condition: there is no level 5 to unlock, so
## the clear itself is the only thing that marks it.
##
## Deliberately a simple text panel, as the GDD specifies: a title, a short
## description of what the player can do now that the game is beaten, and a close
## button. It is timed to the moment the winning expedition's summary is CLOSED
## rather than opened (the dungeon entrance queues it behind that panel's
## `closed` signal), so the player reads their haul first and the win lands on a
## clear screen.
##
## It announces and nothing more. Night has already fallen by the time this is
## shown — the entrance returns the world to night before either panel opens — so
## closing this strands nothing mid-phase and the world is already where the GDD
## wants it: "When it closes, night falls as normal."

const TITLE_FONT := preload("res://fonts/pixel-operator/PixelOperator-Bold.ttf")
const BODY_FONT := preload("res://fonts/pixel-operator/PixelOperator8.ttf")

## Style-guide UI palette (same family as ExpeditionSummary / HeroPanel).
const COLOR_BG := Color("26262e")
const COLOR_BORDER := Color("6b6b7a")
const COLOR_TEXT := Color(0.93, 0.89, 0.75)
const COLOR_GOLD := Color(0.98, 0.82, 0.35)
const COLOR_SCRIM := Color(0.04, 0.04, 0.06, 0.72)

const TITLE := "You Win!"

## The GDD's brief: congratulate the player on conquering the dungeon, then
## explain what they can do now the game is beaten. Endless mode adds no new
## levels — the point of the second paragraph is that the player keeps the same
## town and the same dungeon, and the tier is what makes returning worth it.
const DESCRIPTION := """Your hirelings have cut their way through the fourth and final level of the dungeon and killed what waited at the bottom of it. The dungeon is conquered, my Lord. You have won.

Endless mode is now open. Keep hiring, keep upgrading, and keep sending parties down: there are no new levels to find, but every expedition from here in which at least one party fully clears level 4 raises the endless tier by one, making its enemies tougher and their drops richer."""

var _panel: PanelContainer


func _ready() -> void:
	add_to_group("win_panel")
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = COLOR_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	# A text panel sizes its own height from its text, so only the width is
	# pinned to the window; it stays centered through resizes.
	var fraction := clampf(
		BalanceData.get_value("win_panel_screen_fraction", 0.5), 0.1, 1.0)
	var margin := (1.0 - fraction) * 0.5
	_panel = PanelContainer.new()
	_panel.anchor_left = margin
	_panel.anchor_right = 1.0 - margin
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_BG, 0.98)
	style.border_color = COLOR_GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(12.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_build()


## Show the win. Public so the dungeon entrance — and a harness — can open it;
## takes no arguments because the win is the same every time it is earned.
func open() -> void:
	show()


func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)
	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var line := ColorRect.new()
	line.color = COLOR_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	root.add_child(line)
	var body := Label.new()
	body.text = DESCRIPTION
	body.add_theme_font_override("font", BODY_FONT)
	body.add_theme_font_size_override("font_size", 8)
	body.add_theme_color_override("font_color", COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(body)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(button_row)
	button_row.add_child(_close_button())


func _close_button() -> Button:
	var button := Button.new()
	button.text = "Close"
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", COLOR_GOLD)
	button.add_theme_color_override("font_hover_color", COLOR_GOLD)
	button.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("4a3a22")
	normal.border_color = Color("c9a15a")
	normal.set_border_width_all(1)
	normal.set_content_margin_all(4.0)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("5c4829")
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("2f2415")
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(hide)
	return button
