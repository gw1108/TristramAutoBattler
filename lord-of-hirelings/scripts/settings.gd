extends Node
## Per-install settings (GDD "Settings"). Display, controls and accessibility
## preferences, stored separately from the campaign and applied immediately.
##
## This is deliberately NOT part of SaveGame: the GDD says settings "are stored
## per install, separately from the save file", so a player who deletes their
## campaign keeps their keybinds and their resolution. The two files know
## nothing about each other and neither ever reads the other.
##
## Audio (the GDD's volume sliders and mute-when-unfocused toggle) is out of
## scope for this phase, so its rows are simply absent rather than stubbed —
## there is no audio system for them to drive yet.
##
## Registered after BalanceData in project.godot and before everything that
## plays: it rebinds the InputMap and sizes the window as it comes up, so the
## first frame anyone draws is already at the player's settings.

## Emitted after any change is applied and saved, so open UI can redraw itself
## and future consumers (screen shake, floating combat text) can react without
## polling.
signal changed

const SETTINGS_PATH := "user://settings.cfg"

## The GDD's three window modes, in the order it names them.
enum WindowMode { FULLSCREEN, BORDERLESS, WINDOWED }

## The rebindable actions (GDD: "rebindable keyboard keys for movement and
## interact"). Mouse buttons are fixed, so nothing else belongs here — these are
## exactly the five actions project.godot defines.
const ACTIONS: Array[String] = [
	"move_up", "move_down", "move_left", "move_right", "interact",
]

## Human labels for the rebind rows, in the order they are shown.
const ACTION_LABELS := {
	"move_up": "Move up",
	"move_down": "Move down",
	"move_left": "Move left",
	"move_right": "Move right",
	"interact": "Interact",
}

## Offered resolutions. Structural rather than tunable: the art is authored at
## 960x540 (ArtStyleGuide "Native art resolution") and every entry here is an
## integer multiple of it, so pixel art never lands on a fractional scale.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1920, 1080),
	Vector2i(2880, 1620),
	Vector2i(3840, 2160),
]

var window_mode: WindowMode = WindowMode.WINDOWED
var resolution := Vector2i(960, 540)
var vsync := true

## Accessibility toggles (GDD). Nothing reads these yet — the dive scene they
## belong to does not exist — so they are stored and exposed for the systems
## that will: a screen shake must ask `Settings.screen_shake` before shaking,
## and a damage number must ask `Settings.floating_combat_text` before popping.
var screen_shake := true
var floating_combat_text := true

## action name -> physical keycode currently bound to it.
var keys := {}

## The project.godot input map, captured before anything overrides it. This —
## not a table copied into this file — is what "reset to defaults" restores, so
## the defaults can never drift from the project's own bindings.
var _default_keys := {}
var _default_resolution := Vector2i(960, 540)


func _ready() -> void:
	_capture_defaults()
	_load()
	_apply_keys()
	_apply_display()


## Restores every setting to the project's own defaults (GDD's
## reset-to-defaults button) and applies them immediately.
func reset_to_defaults() -> void:
	window_mode = WindowMode.WINDOWED
	resolution = _default_resolution
	vsync = true
	screen_shake = true
	floating_combat_text = true
	keys = _default_keys.duplicate()
	_apply_keys()
	_apply_display()
	_commit()


## Binds [param action] to [param physical_keycode]. When another action already
## holds that key the two SWAP, which is the only resolution that cannot strand
## an action with no key at all — silently stealing the key would leave the
## player unable to walk in one direction with no indication why.
func rebind(action: String, physical_keycode: int) -> void:
	if not ACTIONS.has(action) or physical_keycode == KEY_NONE:
		return
	var previous: int = keys.get(action, KEY_NONE)
	for other in ACTIONS:
		if other != action and keys.get(other, KEY_NONE) == physical_keycode:
			keys[other] = previous
	keys[action] = physical_keycode
	_apply_keys()
	_commit()


## The key bound to [param action], as the player-facing name shown on a rebind
## row ("W", "Escape", ...).
func key_label(action: String) -> String:
	var code: int = keys.get(action, KEY_NONE)
	if code == KEY_NONE:
		return "Unbound"
	return OS.get_keycode_string(_label_keycode(code))


## [param physical_keycode] as the key the player sees printed on their own
## keyboard. Bindings are physical so the WASD block stays a block on any layout,
## but a label must be the layout's own: an AZERTY player rebinding to physical W
## has to read "Z", or the settings screen is naming a key they do not have.
##
## Headless has no keyboard to ask and answers with an unsupported-feature error,
## so it falls back to the physical code — a harness only needs the label to be
## stable, and asking anyway floods the log with backtraces.
func _label_keycode(physical_keycode: int) -> int:
	if DisplayServer.get_name() == "headless":
		return physical_keycode
	return DisplayServer.keyboard_get_keycode_from_physical(physical_keycode)


func set_window_mode(mode: WindowMode) -> void:
	window_mode = mode
	_apply_display()
	_commit()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	_apply_display()
	_commit()


func set_vsync(enabled: bool) -> void:
	vsync = enabled
	_apply_display()
	_commit()


func set_screen_shake(enabled: bool) -> void:
	screen_shake = enabled
	_commit()


func set_floating_combat_text(enabled: bool) -> void:
	floating_combat_text = enabled
	_commit()


## The project's own bindings and window size, before this node touches either.
func _capture_defaults() -> void:
	for action in ACTIONS:
		var code := KEY_NONE
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				if event is InputEventKey:
					code = (event as InputEventKey).physical_keycode
					break
		_default_keys[action] = code
	keys = _default_keys.duplicate()
	_default_resolution = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 540)))
	resolution = _default_resolution


func _load() -> void:
	var config := ConfigFile.new()
	# No file is the normal first-run case, not an error: the defaults captured
	# above are already the right answer.
	if config.load(SETTINGS_PATH) != OK:
		return
	window_mode = clampi(int(config.get_value("display", "window_mode", window_mode)),
			WindowMode.FULLSCREEN, WindowMode.WINDOWED) as WindowMode
	var saved_resolution: Vector2i = config.get_value("display", "resolution", resolution)
	# A resolution dropped from RESOLUTIONS between installs must not strand the
	# window at a size the settings screen can no longer name.
	resolution = saved_resolution if RESOLUTIONS.has(saved_resolution) else _default_resolution
	vsync = bool(config.get_value("display", "vsync", vsync))
	screen_shake = bool(config.get_value("gameplay", "screen_shake", screen_shake))
	floating_combat_text = bool(
		config.get_value("gameplay", "floating_combat_text", floating_combat_text))
	for action in ACTIONS:
		var code := int(config.get_value("controls", action, _default_keys[action]))
		if code != KEY_NONE:
			keys[action] = code


func _commit() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "window_mode", int(window_mode))
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "vsync", vsync)
	config.set_value("gameplay", "screen_shake", screen_shake)
	config.set_value("gameplay", "floating_combat_text", floating_combat_text)
	for action in ACTIONS:
		config.set_value("controls", action, int(keys.get(action, KEY_NONE)))
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Settings: cannot write %s (%s)" % [SETTINGS_PATH, error_string(error)])
	changed.emit()


## Rewrites the InputMap so every action carries exactly the key bound here.
## The events are replaced rather than added to: an action that kept its old
## event would answer to both keys, and the second one would be invisible.
func _apply_keys() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var code: int = keys.get(action, KEY_NONE)
		if code == KEY_NONE:
			continue
		var event := InputEventKey.new()
		event.physical_keycode = code
		InputMap.action_add_event(action, event)


func _apply_display() -> void:
	match window_mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		WindowMode.BORDERLESS:
			# Godot's WINDOW_MODE_FULLSCREEN is itself a borderless window sized
			# to the screen, which is exactly what the GDD's "borderless" means.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Only windowed has a size to set — the other two take the screen's.
			DisplayServer.window_set_size(resolution)
			var screen := DisplayServer.screen_get_size()
			if screen.x > 0 and screen.y > 0:
				DisplayServer.window_set_position((screen - resolution) / 2)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
