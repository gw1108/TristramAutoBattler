extends StaticBody2D
## The graveyard plot — a non-building town interactable per the art asset
## list: small fenced plot with 12 grave positions, headstone variants mixed
## per grave, and a fresh-dirt mound for a new grave. Names render as Label
## text, not art. This slice is the empty plot prop placed in the town;
## graves fill in when adventurers die (a later slice composites headstone
## sprites from HEADSTONE_SHEET at GRAVE_OFFSETS and overwrites the oldest
## of the 12 per the GDD).

const PLOT_TEXTURE := preload("res://sprites/town/graveyard_plot.png")
## graveyard_headstones.png cells (16x24 each, bottom-center pivot per cell):
## 0 stone cross, 1 slab, 2 rounded stone, 3 cracked leaning slab,
## 4 fresh-dirt mound (new grave, no stone yet).
const HEADSTONE_SHEET := preload("res://sprites/town/graveyard_headstones.png")
const HEADSTONE_CELL := Vector2i(16, 24)

## Sprite is 96px tall with a bottom-center pivot, like the other town props.
const SPRITE_HEIGHT_PX := 96

## Node-local bottom-center points of the 12 grave positions (4 columns x
## 3 rows), matching the worn-earth patches baked into the plot sprite —
## keep in sync with SourceArt/tools/generate_graveyard.py GRAVE_XS/GRAVE_YS.
const GRAVE_OFFSETS: Array[Vector2] = [
	Vector2(-48, -44), Vector2(-16, -44), Vector2(16, -44), Vector2(48, -44),
	Vector2(-48, -28), Vector2(-16, -28), Vector2(16, -28), Vector2(48, -28),
	Vector2(-48, -12), Vector2(-16, -12), Vector2(16, -12), Vector2(48, -12),
]


func _ready() -> void:
	position = Vector2(
		BalanceData.get_value("graveyard_town_pos_x", 608.0),
		BalanceData.get_value("graveyard_town_pos_y", 712.0))
	$Sprite.texture = PLOT_TEXTURE
