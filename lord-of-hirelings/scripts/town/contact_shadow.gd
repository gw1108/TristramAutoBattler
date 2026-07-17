extends Node2D
## Reusable soft contact-shadow ellipse, drawn in code at a character's
## bottom-center pivot (art style guide section 4: this is what grounds
## sprites so they don't read as floating). Add as the first child of any
## character so it renders beneath the sprite, positioned at the pivot.

## Deepest-shadow palette color from the art style guide (#101014).
const SHADOW_COLOR := Color(0.063, 0.063, 0.078)
## Concentric layers that fade outward to soften the edge.
const LAYERS := 3

var _radius := Vector2.ZERO
var _opacity := 0.0


func _ready() -> void:
	_radius = Vector2(
		BalanceData.get_value("contact_shadow_radius_x", 12.0),
		BalanceData.get_value("contact_shadow_radius_y", 4.0))
	_opacity = BalanceData.get_value("contact_shadow_opacity", 0.35)
	queue_redraw()


func _draw() -> void:
	var layer_color := Color(SHADOW_COLOR, _opacity / LAYERS)
	for i in LAYERS:
		var shrink := 1.0 - float(i) / float(LAYERS)
		draw_set_transform(Vector2.ZERO, 0.0, _radius * shrink)
		draw_circle(Vector2.ZERO, 1.0, layer_color)
