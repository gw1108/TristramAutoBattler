extends StaticBody2D
## The Weapon shop (smithy). Starts ruined per the GDD — every building but
## the Inn begins as a ruin; the rebuild interaction comes in a later slice.
## A static prop with a base-footprint collider, like the Inn.

const RUINED_TEXTURE := preload("res://sprites/town/weapon_shop_ruined.png")
const NORMAL_TEXTURE := preload("res://sprites/town/weapon_shop_normal.png")

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	position = Vector2(
		BalanceData.get_value("weapon_shop_town_pos_x", 1072.0),
		BalanceData.get_value("weapon_shop_town_pos_y", 712.0))
	set_ruined(true)


func set_ruined(ruined: bool) -> void:
	_sprite.texture = RUINED_TEXTURE if ruined else NORMAL_TEXTURE
