extends CharacterBody2D
## The player-controlled Lord. Top-down WASD movement inside the bounded
## town map; the camera follows him and stops at the town-map edges.

@onready var _camera: Camera2D = $Camera2D

var _move_speed: float
var _town_size: Vector2


func _ready() -> void:
	_move_speed = BalanceData.get_value("player_move_speed", 150.0)
	_town_size = Vector2(
		BalanceData.get_value("town_map_width", 1920.0),
		BalanceData.get_value("town_map_height", 1080.0))
	position = _town_size * 0.5
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(_town_size.x)
	_camera.limit_bottom = int(_town_size.y)


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * _move_speed
	move_and_slide()
	position = position.clamp(Vector2.ZERO, _town_size)
