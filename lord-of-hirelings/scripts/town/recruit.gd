extends Node2D
## A hireable adventurer placeholder (GDD town phase): recruits show up near
## the inn when the rooster crows. Pure visual for now — the hiring UI and
## the name/class generator come in later slices.

## Placeholder palette until the recruit sprites land (art asset list).
## One tunic color per spawn slot so a day's batch reads as distinct people.
const TUNIC_COLORS: Array[Color] = [
	Color("5b7a3b"), Color("3b5b7a"), Color("7a5b3b"), Color("6b3b7a"),
]
const SKIN_COLOR := Color("d8a878")
const BOOT_COLOR := Color("4a3527")

var tunic_index := 0


func _draw() -> void:
	# Placeholder adventurer silhouette, bottom-center pivot (~12x22px).
	var tunic := TUNIC_COLORS[tunic_index % TUNIC_COLORS.size()]
	draw_rect(Rect2(-4, -4, 3, 4), BOOT_COLOR)
	draw_rect(Rect2(1, -4, 3, 4), BOOT_COLOR)
	draw_rect(Rect2(-5, -16, 10, 12), tunic)
	draw_circle(Vector2(0, -19), 4.0, SKIN_COLOR)
