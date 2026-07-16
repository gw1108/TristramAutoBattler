extends Node
## EXAMPLE per-game adapter for AgentBridge — copy and adapt, don't use as-is.
##
## This is the ~15-line piece you write for each game. Its whole job is to map your
## game's internal state onto the generic AgentState contract and (optionally) handle
## game-specific commands. Everything else lives in the generic agent_bridge.gd.
##
## HOW TO WIRE IT UP
##   1. Make this a child node of your main scene (or instance it from your main
##      controller's _ready), so it can reach your game state.
##   2. In _ready, register the provider (and a command handler if you need seeding /
##      a custom restart / tick-stepping).
##   3. Add AgentBridge.emit_event(...) calls at gameplay moments (see bottom).
##
## CONTRACT REMINDERS
##   - phase MUST be one of: menu | playing | paused | game_over | loading
##   - Convert every Vector2/Vector2i to [x, y]; JSON.stringify chokes on engine types.
##   - available_actions lists the InputMap actions legal in the CURRENT phase.
##   - world.coordinate_space is "grid" (pos is cells) or "pixels" (pos is pixels).

# Reference to wherever your live game state lives. Adjust to your project.
@onready var game = get_parent()


func _ready() -> void:
	AgentBridge.register_provider(_provide)
	# Optional — only if the default input synthesis / scene-reload isn't enough:
	AgentBridge.register_command_handler(_on_command)


# func() -> Dictionary : called every frame while the bridge is active.
func _provide() -> Dictionary:
	var phase := _phase_name()             # map your enum -> generic lifecycle
	return {
		"phase": phase,
		"player": {
			"pos": [game.player.position.x, game.player.position.y],
			"velocity": [game.player.velocity.x, game.player.velocity.y],
			"facing": [game.player.facing.x, game.player.facing.y],
			"health": game.player.health,
			"alive": game.player.alive,
			"extra": {},                   # game-specific scalars (ammo, charge, length…)
		},
		"score": game.score,
		"best": game.best_score,
		"entities": _entities(),           # everything else worth reasoning about
		"world": {
			"coordinate_space": "pixels",
			"bounds": {"min": [0, 0], "max": [game.world_w, game.world_h]},
			"camera": {"pos": [game.camera.position.x, game.camera.position.y], "zoom": 1.0},
		},
		"available_actions": _actions_for(phase),
	}


func _phase_name() -> String:
	# EXAMPLE: map your own enum here.
	match game.phase:
		# game.State.MENU:      return "menu"
		# game.State.RUNNING:   return "playing"
		# game.State.PAUSED:    return "paused"
		# game.State.DEAD:      return "game_over"
		_:
			return "playing"


func _actions_for(phase: String) -> Array:
	match phase:
		"menu", "game_over":
			return ["ui_accept"]
		"paused":
			return ["pause", "ui_accept"]
		_:
			return ["move_left", "move_right", "jump", "pause"]


func _entities() -> Array:
	var out: Array = []
	for e in game.get_entities():          # adapt to your project's entity access
		out.append({
			"id": str(e.get_instance_id()),
			"type": e.kind,                # "enemy" | "pickup" | "projectile" | …
			"pos": [e.position.x, e.position.y],
			"state": e.state_name,
		})
	return out


# func(cmd: Dictionary) -> void : optional. Only commands NOT handled by the bridge
# itself (press/release/tap/set_time_scale/ack_events/restart) reach here.
func _on_command(cmd: Dictionary) -> void:
	match str(cmd.get("type", "")):
		"set_seed":
			game.reseed(int(cmd.get("value", 0)))   # make runs reproducible
		"step":
			game.advance_ticks(int(cmd.get("n", 1)))  # only if you expose manual stepping
		_:
			pass


# EMITTING EVENTS — call these from your gameplay code so the juiciness/audio/bug
# personalities have signal. They are no-ops when the bridge is inactive.
#
#   AgentBridge.emit_event("score_changed", {"to": score})
#   AgentBridge.emit_event("damage", {"amount": 1, "to": health})
#   AgentBridge.emit_event("death", {})
#   AgentBridge.emit_event("spawn", {"type": "enemy", "pos": [x, y]})
#   AgentBridge.emit_event("sfx_played", {"name": "jump"})
#   AgentBridge.emit_event("music_changed", {"track": "boss"})
#   AgentBridge.emit_event("screen_shake", {"strength": 4.0})
#   AgentBridge.emit_event("particle_burst", {"kind": "explosion", "pos": [x, y]})
