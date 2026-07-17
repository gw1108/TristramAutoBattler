class_name InteractPrompt
extends Object
## Static helper for the floating "[E] ..." interact prompts (recruits,
## rooster, rebuildable buildings). Gives every prompt the style-guide UI
## panel treatment (semi-transparent #26262e fill, #6b6b7a border) so the
## cream text stays readable over any backdrop, and arbitrates overlapping
## interact radii so only the interactable nearest the player shows its
## prompt — and, via each owner gating on its prompt's visibility, answers
## the [E] press.

const FONT := preload("res://fonts/pixel-operator/PixelOperator8.ttf")

## Interactables the player is currently in range of; each registers on
## body_entered and unregisters on body_exited / _exit_tree.
static var _candidates: Array[Node2D] = []


## Applies the shared prompt look: 8px Pixel Operator in cream with a 1px
## drop shadow, on a semi-transparent dark panel (style guide UI palette)
## so the text survives cream building facades.
static func style(label: Label) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.75))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(Color("26262e"), 0.8)
	panel.border_color = Color(Color("6b6b7a"), 0.8)
	panel.set_border_width_all(1)
	panel.content_margin_left = 4.0
	panel.content_margin_right = 4.0
	panel.content_margin_top = 2.0
	panel.content_margin_bottom = 2.0
	label.add_theme_stylebox_override("normal", panel)


## Sets the text and shrinks the panel to hug it, re-centered over the
## owner (the label's parent origin) — a fixed-width label would draw a
## huge empty bar behind short prompts.
static func set_text(label: Label, text: String) -> void:
	label.text = text
	label.reset_size()
	label.position.x = -label.size.x / 2.0


static func register(node: Node2D) -> void:
	if not _candidates.has(node):
		_candidates.append(node)


static func unregister(node: Node2D) -> void:
	_candidates.erase(node)


## True when no other registered interactable is closer to the player.
static func is_nearest(node: Node2D) -> bool:
	var player := node.get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return true
	var my_dist := node.global_position.distance_squared_to(player.global_position)
	for other in _candidates:
		if other == node or not is_instance_valid(other):
			continue
		if other.global_position.distance_squared_to(player.global_position) < my_dist:
			return false
	return true
