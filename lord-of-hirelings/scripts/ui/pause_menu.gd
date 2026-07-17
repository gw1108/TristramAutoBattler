extends Control
## The Esc pause menu and its settings screen (GDD "Settings").
##
## "Pressing Esc opens a pause menu with a settings screen. Opening it pauses
## everything, including mid-dive combat." Pausing is done with the tree's own
## pause rather than a flag every system has to remember to honour, so it covers
## the town, the summary panel's animations, and whatever the dive scene turns
## out to be, without any of them knowing this node exists. This node is the one
## thing that keeps running (PROCESS_MODE_ALWAYS in main.tscn) — otherwise it
## would pause itself along with everything else and never take the key that
## closes it.
##
## The settings themselves live in the Settings autoload, which owns the file and
## applies every change immediately; this is only their screen. Audio's rows are
## absent rather than stubbed — out of scope for this phase.
##
## Quit to Title is the way back to the title screen, which is otherwise a
## one-way door: the campaign autosave is only worth having if the player can
## reach Continue without killing the process.

const TITLE_FONT := preload("res://fonts/pixel-operator/PixelOperator-Bold.ttf")
const BODY_FONT := preload("res://fonts/pixel-operator/PixelOperator8.ttf")

## Style-guide UI palette (same family as WinPanel / ExpeditionSummary).
const COLOR_BG := Color("26262e")
const COLOR_BORDER := Color("6b6b7a")
const COLOR_TEXT := Color(0.93, 0.89, 0.75)
const COLOR_MUTED := Color(0.65, 0.67, 0.73)
const COLOR_GOLD := Color(0.98, 0.82, 0.35)
const COLOR_BAD := Color("dd6666")
const COLOR_SCRIM := Color(0.04, 0.04, 0.06, 0.72)

const TITLE_SCENE := "res://scenes/ui/main_menu.tscn"

## Which of the three pages is up. They are pages rather than stacked panels so
## Esc always has exactly one meaning: go back one step, and close from the root.
enum Page { ROOT, SETTINGS, CONFIRM_QUIT }

var _panel: PanelContainer
var _pages := {}
var _page: Page = Page.ROOT

var _resume_button: Button
var _confirm_label: Label
var _cancel_button: Button

## Buttons whose text is a live setting value, keyed by what they show, so a
## reset-to-defaults can redraw the whole screen without rebuilding it.
var _value_buttons := {}

## The action currently waiting for a key press, or "" when not rebinding.
var _listening := ""


func _ready() -> void:
	add_to_group("pause_menu")
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = COLOR_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	# Same shape as WinPanel: the pages size their own height from their content,
	# so only the width is pinned to the window and it stays centered on resize.
	var fraction := clampf(
		BalanceData.get_value("pause_menu_screen_fraction", 0.5), 0.1, 1.0)
	var margin := (1.0 - fraction) * 0.5
	_panel = PanelContainer.new()
	_panel.anchor_left = margin
	_panel.anchor_right = 1.0 - margin
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_BG, 0.98)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(12.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_pages[Page.ROOT] = _build_root()
	_pages[Page.SETTINGS] = _build_settings()
	_pages[Page.CONFIRM_QUIT] = _build_confirm()
	for page in _pages:
		_panel.add_child(_pages[page])
	Settings.changed.connect(_refresh_values)


## Opens the pause menu, pausing everything (GDD). Public so a harness — and any
## future in-game pause button — can open it without synthesizing a key press.
func open() -> void:
	if visible:
		return
	get_tree().paused = true
	show()
	_show_page(Page.ROOT)


## Closes and resumes. Named for what it does to the world, not to this node:
## the unpause is the point, and forgetting it would leave the town frozen.
func close() -> void:
	_listening = ""
	hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _listening != "":
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not visible:
		open()
		return
	# Esc backs out one page at a time, so it can never destroy a campaign's
	# progress or answer the quit confirmation by being pressed twice.
	match _page:
		Page.ROOT:
			close()
		_:
			_show_page(Page.ROOT)


## Rebind capture. This runs ahead of _unhandled_input on purpose: while a row is
## listening, every key belongs to it — including the ones bound to town
## interactions, which would otherwise fire behind the menu.
func _input(event: InputEvent) -> void:
	if _listening == "" or not visible:
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	var action := _listening
	_listening = ""
	# Escape cancels rather than binding: it is the key that opens this menu, so
	# binding it to a movement action would take the pause menu away from the
	# player from inside the pause menu.
	if key.physical_keycode != KEY_ESCAPE:
		Settings.rebind(action, key.physical_keycode)
	_refresh_values()


func _show_page(page: Page) -> void:
	_listening = ""
	_page = page
	for key in _pages:
		(_pages[key] as Control).visible = key == page
	_refresh_values()
	match page:
		Page.ROOT:
			_resume_button.grab_focus()
		Page.CONFIRM_QUIT:
			# Cancel takes the focus, not Confirm — the same rule the title
			# screen's confirmations follow: a stray Enter must never be the
			# answer that throws away the town play since the last autosave.
			_cancel_button.grab_focus()


func _build_root() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_child(_title("Paused"))
	root.add_child(_separator())
	_resume_button = _button("Resume")
	_resume_button.pressed.connect(close)
	root.add_child(_resume_button)
	var settings_button := _button("Settings")
	settings_button.pressed.connect(_show_page.bind(Page.SETTINGS))
	root.add_child(settings_button)
	var quit_button := _button("Quit to Title")
	quit_button.pressed.connect(_show_page.bind(Page.CONFIRM_QUIT))
	root.add_child(quit_button)
	return root


func _build_settings() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.add_child(_title("Settings"))
	root.add_child(_separator())

	# Every row shares ONE grid, section headings included. A grid per section
	# sizes its label column to its own longest label, which leaves the value
	# buttons stepping in and out down the page instead of forming a column.
	var grid := _grid()
	root.add_child(grid)

	_add_section(grid, "Display")
	_add_row(grid, "Window mode", "window_mode", _on_window_mode_pressed)
	_add_row(grid, "Resolution", "resolution", _on_resolution_pressed)
	_add_row(grid, "VSync", "vsync", _on_vsync_pressed)

	_add_section(grid, "Controls")
	for action in Settings.ACTIONS:
		_add_row(grid, String(Settings.ACTION_LABELS[action]), action,
			_on_rebind_pressed.bind(action))

	_add_section(grid, "Gameplay")
	_add_row(grid, "Screen shake", "screen_shake", _on_screen_shake_pressed)
	_add_row(grid, "Floating combat text", "floating_combat_text",
		_on_floating_text_pressed)

	root.add_child(_separator())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	var reset := _button("Reset to Defaults")
	reset.pressed.connect(Settings.reset_to_defaults)
	buttons.add_child(reset)
	var back := _button("Back")
	back.pressed.connect(_show_page.bind(Page.ROOT))
	buttons.add_child(back)
	return root


func _build_confirm() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_child(_title("Quit to Title"))
	root.add_child(_separator())
	_confirm_label = _label("", COLOR_TEXT)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.custom_minimum_size = Vector2(240, 0)
	root.add_child(_confirm_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	var confirm := _button("Quit to Title", COLOR_BAD)
	confirm.pressed.connect(_quit_to_title)
	buttons.add_child(confirm)
	_cancel_button = _button("Cancel")
	_cancel_button.pressed.connect(_show_page.bind(Page.ROOT))
	buttons.add_child(_cancel_button)
	return root


## What quitting now actually costs, in the save's own terms. The GDD is explicit
## that "there is no autosave between the crow and the dungeon-entry save, so a
## player who hires and upgrades and then quits before entering the dungeon rolls
## back to the previous autosave" — so this says so plainly rather than letting
## the player find out by pressing Continue and losing their morning.
func _confirm_text() -> String:
	if not SaveGame.has_save():
		return "This campaign has not reached an autosave yet — the town is saved when the parties enter the dungeon.\n\nEverything so far will be lost."
	var header := SaveGame.read_header()
	return "Your campaign is saved at day %d, %s.\n\nThe town is only saved when the parties enter the dungeon, so anything done since then — hires, rebuilds, gold spent — is lost." % [
		int(header.get("day", 0)),
		SaveGame.point_label(String(header.get("point", ""))).to_lower(),
	]


func _quit_to_title() -> void:
	# The unpause has to happen here, not in the title screen: the tree's pause
	# survives a scene change, so leaving it set would hand the player a frozen
	# menu with no way to unfreeze it.
	get_tree().paused = false
	hide()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _on_window_mode_pressed() -> void:
	Settings.set_window_mode(
		((Settings.window_mode + 1) % Settings.WindowMode.size()) as Settings.WindowMode)


func _on_resolution_pressed() -> void:
	var index := Settings.RESOLUTIONS.find(Settings.resolution)
	Settings.set_resolution(
		Settings.RESOLUTIONS[(index + 1) % Settings.RESOLUTIONS.size()])


func _on_vsync_pressed() -> void:
	Settings.set_vsync(not Settings.vsync)


func _on_screen_shake_pressed() -> void:
	Settings.set_screen_shake(not Settings.screen_shake)


func _on_floating_text_pressed() -> void:
	Settings.set_floating_combat_text(not Settings.floating_combat_text)


func _on_rebind_pressed(action: String) -> void:
	_listening = action
	_refresh_values()


## Redraws every value button from the Settings autoload. Everything on the
## settings page reads through here rather than being written when it is pressed,
## so Reset to Defaults — which changes all of them at once behind this node's
## back — needs no special case.
func _refresh_values() -> void:
	if _confirm_label != null and _page == Page.CONFIRM_QUIT:
		_confirm_label.text = _confirm_text()
	for key in _value_buttons:
		var button: Button = _value_buttons[key]
		if Settings.ACTIONS.has(key):
			button.text = "Press a key..." if _listening == key else Settings.key_label(key)
			continue
		match key:
			"window_mode":
				button.text = ["Fullscreen", "Borderless", "Windowed"][Settings.window_mode]
			"resolution":
				button.text = "%d x %d" % [Settings.resolution.x, Settings.resolution.y]
			"vsync":
				button.text = _on_off(Settings.vsync)
			"screen_shake":
				button.text = _on_off(Settings.screen_shake)
			"floating_combat_text":
				button.text = _on_off(Settings.floating_combat_text)


func _on_off(enabled: bool) -> String:
	return "On" if enabled else "Off"


func _add_row(grid: GridContainer, text: String, key: String, action: Callable) -> void:
	grid.add_child(_label(text, COLOR_TEXT))
	var button := _button("")
	button.custom_minimum_size = Vector2(128, 0)
	button.pressed.connect(action)
	_value_buttons[key] = button
	grid.add_child(button)


## A section heading as a grid row, so the headings live in the same grid as the
## rows they head and the value column stays a column.
func _add_section(grid: GridContainer, text: String) -> void:
	grid.add_child(_section(text))
	grid.add_child(Control.new())


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	return grid


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", COLOR_GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	return label


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _separator() -> ColorRect:
	var line := ColorRect.new()
	line.color = COLOR_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _button(text: String, color: Color = COLOR_GOLD) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
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
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = COLOR_GOLD
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	return button
