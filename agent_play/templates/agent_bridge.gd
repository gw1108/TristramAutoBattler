extends Node
## AgentBridge — generic, drop-in autoload that exposes a 2D Godot 4 game to an
## external Playwright/Claude harness over Godot's JavaScriptBridge.
##
## It is ACTIVE only when BOTH are true:
##   1. running as an HTML5/Web export  (OS.has_feature("web")), and
##   2. the agent gate is on  (custom "agent" export feature OR ?agent=1 in the URL).
## In the editor, on desktop, and in ungated public web builds it is fully inert.
##
## A game wires itself up with a few lines (see agent_adapter.example.gd):
##   AgentBridge.register_provider(_provide)          # func() -> Dictionary (the contract)
##   AgentBridge.register_command_handler(_on_cmd)    # optional; defaults synthesize input
##   AgentBridge.emit_event("score_changed", {...})   # push gameplay events
##
## Channels published to the page each frame:
##   window.__agentStateJson   : String  (JSON of the AgentState contract)
##   window.__agentEventsJson  : String  (JSON array of buffered, seq-numbered events)
##   window.__agentReady       : bool    (true once the first state has been published)
##   window.__agentProtocol    : int     (PROTOCOL_VERSION)
## Command channel (page -> game):
##   window.__agentControl.send(jsonString)

const PROTOCOL_VERSION := 1
const EVENT_BUFFER_CAP := 256

var state_provider: Callable = Callable()    ## func() -> Dictionary
var command_handler: Callable = Callable()   ## func(cmd: Dictionary) -> void  (optional)

var _active := false
var _ready_sent := false
var _command_cb: JavaScriptObject            ## MUST stay referenced (create_callback GC pitfall)
var _window: JavaScriptObject
var _events: Array = []
var _event_seq := 0
var _frame := 0


func _ready() -> void:
	# Gate 1: JavaScriptBridge only exists on web exports. Guard everything.
	if not OS.has_feature("web"):
		set_process(false)
		return
	# Gate 2: release safety — only wire up when explicitly enabled.
	if not _agent_enabled():
		set_process(false)
		return
	_window = JavaScriptBridge.get_interface("window")
	if _window == null:
		set_process(false)
		return
	# Wire the command channel. create_callback returns a JS function wrapper whose
	# reference we MUST keep, or the GC frees it and JS calls become silent no-ops.
	# The callback receives exactly ONE Array argument (args[0] is the JSON string).
	_command_cb = JavaScriptBridge.create_callback(_on_js_command)
	_window.__agentCommandCallback = _command_cb
	# One-time eval to install the control facade. Per-frame state uses property
	# assignment (below), NOT eval, to avoid re-parse cost and injection.
	JavaScriptBridge.eval(
		"window.__agentControl = { send: function(s){ return window.__agentCommandCallback(s); } };",
		true)
	_window.__agentProtocol = PROTOCOL_VERSION
	_window.__agentReady = false
	_active = true


func _agent_enabled() -> bool:
	if OS.has_feature("agent"):
		return true
	var search := str(JavaScriptBridge.eval("window.location.search", true))
	return search.findn("agent=1") != -1


func _process(delta: float) -> void:
	if not _active:
		return
	_frame += 1
	# 1) Publish state via property assignment (cheap, injection-safe — no eval).
	if state_provider.is_valid():
		var state: Dictionary = state_provider.call()
		state["meta"] = _build_meta(delta, state.get("meta", {}))
		_window.__agentStateJson = JSON.stringify(state)
		if not _ready_sent:
			_window.__agentReady = true
			_ready_sent = true
	# 2) Publish the bounded event buffer; harness dedupes by seq and acks to trim.
	_window.__agentEventsJson = JSON.stringify(_events)


func _build_meta(delta: float, existing: Dictionary) -> Dictionary:
	var m: Dictionary = existing.duplicate()
	m["protocol"] = PROTOCOL_VERSION
	m["frame"] = _frame
	m["dt"] = delta
	m["time"] = Time.get_ticks_msec() / 1000.0
	m["ready"] = true
	if not m.has("game_id"):
		m["game_id"] = ProjectSettings.get_setting("application/config/name", "unknown")
	if not m.has("version"):
		m["version"] = ProjectSettings.get_setting("application/config/version", "0")
	return m


# ---- Public API used by the per-game adapter --------------------------------

func register_provider(provider: Callable) -> void:
	state_provider = provider


func register_command_handler(handler: Callable) -> void:
	command_handler = handler


func emit_event(type: String, data: Dictionary = {}) -> void:
	# Always safe to call (no-op when inactive). The game pushes gameplay events here.
	if not _active:
		return
	_event_seq += 1
	_events.append({
		"seq": _event_seq,
		"type": type,
		"frame": _frame,
		"t": Time.get_ticks_msec() / 1000.0,
		"data": data,
	})
	if _events.size() > EVENT_BUFFER_CAP:
		_events = _events.slice(_events.size() - EVENT_BUFFER_CAP)


# ---- Command channel --------------------------------------------------------

func _on_js_command(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var cmd: Dictionary = parsed
	var type := str(cmd.get("type", ""))
	# Control commands handled by the bridge itself (game-agnostic).
	if type == "ack_events":
		_drop_events_through(int(cmd.get("seq", 0)))
		return
	if type == "set_time_scale":
		Engine.time_scale = float(cmd.get("value", 1.0))
		return
	if type == "restart":
		if command_handler.is_valid():
			command_handler.call(cmd)
		else:
			get_tree().reload_current_scene()
		return
	# Game-specific commands (set_seed, step, custom) -> registered handler if present.
	if command_handler.is_valid():
		command_handler.call(cmd)
		return
	# Default: synthesize input actions so existing _unhandled_input works unchanged.
	_default_command(cmd)


func _drop_events_through(seq: int) -> void:
	var kept: Array = []
	for ev in _events:
		if int(ev["seq"]) > seq:
			kept.append(ev)
	_events = kept


func _default_command(cmd: Dictionary) -> void:
	var action := str(cmd.get("action", ""))
	if action == "":
		return
	match str(cmd.get("type", "")):
		"press":
			_send_action(action, true)
		"release":
			_send_action(action, false)
		"tap":
			_send_action(action, true)
			_send_action(action, false)


func _send_action(action: String, pressed: bool, strength: float = 1.0) -> void:
	if not InputMap.has_action(action):
		push_warning("AgentBridge: unknown action '%s'" % action)
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength if pressed else 0.0
	# Routes through the normal input pipeline: _unhandled_input AND Input.is_action_pressed.
	Input.parse_input_event(ev)
