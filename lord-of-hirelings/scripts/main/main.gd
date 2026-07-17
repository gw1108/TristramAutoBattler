extends Node2D
## Root of the main gameplay (town) scene. Town systems (player movement,
## interactables, day cycle) land here in later slices.

@onready var _town_ground: ColorRect = $TownGround


func _ready() -> void:
	# balance.csv is the source of truth for the town bounds; the editor-set
	# rect size is only a preview.
	_town_ground.size = Vector2(
		BalanceData.get_value("town_map_width", 1920.0),
		BalanceData.get_value("town_map_height", 1080.0))
