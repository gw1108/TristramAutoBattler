extends StaticBody2D
## The Inn (level 1): the only building that starts built (GDD). A static
## prop with a base-footprint collider for now — hiring and the shop UI
## come in later slices.


func _ready() -> void:
	position = Vector2(
		BalanceData.get_value("inn_town_pos_x", 848.0),
		BalanceData.get_value("inn_town_pos_y", 512.0))
