extends CharacterBody2D
## The player-controlled Lord. Top-down WASD movement inside the bounded
## town map; the camera follows him and stops at the town-map edges.

@onready var _camera: Camera2D = $Camera2D
@onready var _sprite: AnimatedSprite2D = $Sprite

var _move_speed: float
var _town_size: Vector2
var _facing := "down"


func _ready() -> void:
	_move_speed = BalanceData.get_value("player_move_speed", 150.0)
	var sprite_scale := BalanceData.get_value("player_sprite_scale", 1.0)
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	var walk_fps := BalanceData.get_value("player_walk_anim_fps", 8.0)
	for anim in ["walk_down", "walk_up", "walk_side"]:
		_sprite.sprite_frames.set_animation_speed(anim, walk_fps)
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
	_update_animation(direction)


func _update_animation(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			_facing = "side"
			_sprite.flip_h = direction.x < 0.0
		else:
			_facing = "up" if direction.y < 0.0 else "down"
		_sprite.play("walk_" + _facing)
	else:
		_sprite.play("idle_" + _facing)
