extends StaticBody2D
## The graveyard plot — a non-building town interactable per the art asset
## list: small fenced plot with 12 grave positions, headstone variants mixed
## per grave, and a fresh-dirt mound for a new grave. When a hired adventurer
## dies (Roster.member_died), a grave fills the next offset: a fresh mound on
## the day of death that becomes the adventurer's headstone at the next dawn.
## At capacity the oldest grave is overwritten (GDD: holds 12). Names render
## as Label text, revealed one at a time — the grave nearest the Lord — so
## twelve name plates never pile into an unreadable heap.

const PLOT_TEXTURE := preload("res://sprites/town/graveyard_plot.png")
## graveyard_headstones.png cells (16x24 each, bottom-center pivot per cell):
## 0 stone cross, 1 slab, 2 rounded stone, 3 cracked leaning slab,
## 4 fresh-dirt mound (new grave, no stone yet).
const HEADSTONE_SHEET := preload("res://sprites/town/graveyard_headstones.png")
const HEADSTONE_CELL := Vector2i(16, 24)
const HEADSTONE_FRAMES := 5
const HEADSTONE_VARIANTS := 4
const FRESH_MOUND_FRAME := 4

## Sprite is 96px tall with a bottom-center pivot, like the other town props.
const SPRITE_HEIGHT_PX := 96

const GRAVE_CAPACITY := 12

## Node-local bottom-center points of the 12 grave positions (4 columns x
## 3 rows), matching the worn-earth patches baked into the plot sprite —
## keep in sync with SourceArt/tools/generate_graveyard.py GRAVE_XS/GRAVE_YS.
const GRAVE_OFFSETS: Array[Vector2] = [
	Vector2(-48, -44), Vector2(-16, -44), Vector2(16, -44), Vector2(48, -44),
	Vector2(-48, -28), Vector2(-16, -28), Vector2(16, -28), Vector2(48, -28),
	Vector2(-48, -12), Vector2(-16, -12), Vector2(16, -12), Vector2(48, -12),
]

## slot index -> { "name": String, "node": Node2D, "sprite": Sprite2D,
## "label": Label }. Slots fill in GRAVE_OFFSETS order and wrap at capacity.
var _graves := {}
## Total burials ever; the next slot is _burial_count % GRAVE_CAPACITY, so at
## capacity the oldest grave is the one overwritten.
var _burial_count := 0

var _name_reveal_radius := 0.0


func _ready() -> void:
	add_to_group("graveyard")
	position = Vector2(
		BalanceData.get_value("graveyard_town_pos_x", 608.0),
		BalanceData.get_value("graveyard_town_pos_y", 712.0))
	$Sprite.texture = PLOT_TEXTURE
	_name_reveal_radius = BalanceData.get_value("graveyard_name_reveal_radius", 96.0)
	Roster.member_died.connect(add_grave)
	GameState.day_advanced.connect(_on_day_advanced)
	# The plot is town state that outlives a session, but this node does not
	# exist when SaveGame restores the campaign, so it collects its own graves
	# on the way up.
	restore_state(SaveGame.pending_graveyard)
	SaveGame.pending_graveyard = {}


func _process(_delta: float) -> void:
	if _graves.is_empty():
		return
	# Reveal only the name of the grave nearest the Lord while they stand by
	# the plot; everything else stays a bare headstone.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var nearest: Dictionary = {}
	var nearest_dist := INF
	for slot in _graves:
		var grave: Dictionary = _graves[slot]
		var dist: float = INF
		if player != null:
			dist = player.global_position.distance_to(
				(grave["node"] as Node2D).global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = grave
		(grave["label"] as Label).visible = false
	if not nearest.is_empty() and nearest_dist <= _name_reveal_radius:
		(nearest["label"] as Label).visible = true


## Buries [param display_name] at the next slot: fresh-dirt mound today, the
## adventurer's headstone variant from the next dawn. Overwrites the oldest
## grave once all 12 slots are taken.
func add_grave(display_name: String) -> void:
	var slot := _burial_count % GRAVE_CAPACITY
	if _graves.has(slot):
		Roster.release_grave_name(_graves[slot]["name"])
		(_graves[slot]["node"] as Node2D).queue_free()
	_burial_count += 1
	Roster.record_grave_name(display_name)
	_raise_grave(slot, display_name)


## The plot as save data (SaveGame): who lies in which slot, whether their mound
## is still fresh, and the burial count — which outlives the 12 slots it wraps
## through, because it is what decides the grave the next death overwrites.
func save_state() -> Dictionary:
	var records: Array = []
	for slot in _graves:
		var grave: Dictionary = _graves[slot]
		records.append({
			"slot": slot,
			"name": grave["name"],
			"fresh": (grave["sprite"] as Sprite2D).frame == FRESH_MOUND_FRAME,
		})
	return {"graves": records, "burial_count": _burial_count}


## Rebuilds the plot from save_state data. Only ever called on the way up, into
## an empty plot; an empty or absent dictionary leaves it empty, which is what a
## campaign that has buried nobody looks like.
func restore_state(state: Dictionary) -> void:
	for record in state.get("graves", []):
		var slot := int(record.get("slot", -1))
		var display_name := String(record.get("name", ""))
		if slot < 0 or slot >= GRAVE_CAPACITY or display_name.is_empty():
			continue
		Roster.record_grave_name(display_name)
		_raise_grave(slot, display_name)
		# Yesterday's dead are already under their stones; only somebody buried
		# by the expedition this save was written for is still a fresh mound.
		if not bool(record.get("fresh", false)):
			(_graves[slot]["sprite"] as Sprite2D).frame = _headstone_frame(display_name)
	_burial_count = maxi(int(state.get("burial_count", 0)), 0)


## Puts [param display_name]'s grave in [param slot] as a fresh mound. Assumes
## the slot is free — add_grave clears the old occupant first, and a restore
## builds into an empty plot.
func _raise_grave(slot: int, display_name: String) -> void:
	var grave_node := Node2D.new()
	grave_node.position = GRAVE_OFFSETS[slot]

	var sprite := Sprite2D.new()
	sprite.texture = HEADSTONE_SHEET
	sprite.hframes = HEADSTONE_FRAMES
	sprite.frame = FRESH_MOUND_FRAME
	# Bottom-center pivot: cell base sits on the grave point.
	sprite.offset = Vector2(0, -HEADSTONE_CELL.y / 2.0)
	grave_node.add_child(sprite)

	var label := Label.new()
	InteractPrompt.style(label)
	InteractPrompt.set_text(label, display_name)
	label.position.y = -HEADSTONE_CELL.y - 14.0
	label.visible = false
	grave_node.add_child(label)

	add_child(grave_node)
	_graves[slot] = {
		"name": display_name, "node": grave_node,
		"sprite": sprite, "label": label,
	}


## Picks this adventurer's headstone from the 4 stone variants, stable across
## sessions so a grave never changes stone.
func _headstone_frame(display_name: String) -> int:
	return posmod(display_name.hash(), HEADSTONE_VARIANTS)


## At dawn, yesterday's fresh mounds get their headstones.
func _on_day_advanced(_new_day: int) -> void:
	for slot in _graves:
		var grave: Dictionary = _graves[slot]
		var sprite := grave["sprite"] as Sprite2D
		if sprite.frame == FRESH_MOUND_FRAME:
			sprite.frame = _headstone_frame(grave["name"])


## Dev hook: dungeon deaths don't exist yet, so K (debug builds only) kills a
## random hired adventurer to exercise the grave flow end to end.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode != KEY_K or Roster.members.is_empty():
		return
	Roster.kill_member(Roster.members.pick_random()["name"])
