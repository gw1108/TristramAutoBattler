extends Node2D
## Root of the main gameplay (town) scene. Town systems (player movement,
## interactables, day cycle) land here in later slices.

## 16px grid geometry of sprites/town/town_ground_tiles.png (structural,
## not a tunable). Columns 0-3 grass, 4-6 dirt path, 7 gold wildflowers.
const TILE_PX := 16
const GRASS_PLAIN := Vector2i(0, 0)
const GRASS_VARIANTS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const GRASS_FLOWERS := Vector2i(7, 0)
const PATH_VARIANTS: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)]

@onready var _town_ground: TileMapLayer = $TownGround


func _ready() -> void:
	_fill_town_ground()


func _fill_town_ground() -> void:
	# balance.csv is the source of truth for the town bounds.
	var cols := ceili(BalanceData.get_value("town_map_width", 1920.0) / TILE_PX)
	var rows := ceili(BalanceData.get_value("town_map_height", 1080.0) / TILE_PX)
	var path_w := int(BalanceData.get_value("town_path_width_tiles", 3.0))
	var half_lo := path_w / 2
	var half_hi := path_w - half_lo
	var cx := cols / 2
	var cy := rows / 2
	for y in rows:
		var on_row_path := y - cy >= -half_lo and y - cy < half_hi
		for x in cols:
			var on_path := on_row_path or (x - cx >= -half_lo and x - cx < half_hi)
			_town_ground.set_cell(Vector2i(x, y), 0, _pick_tile(x, y, on_path))


func _pick_tile(x: int, y: int, on_path: bool) -> Vector2i:
	# Deterministic per-cell hash so the ground is stable across runs.
	var h := absi((x * 73856093) ^ (y * 19349663)) % 100
	if on_path:
		return PATH_VARIANTS[h % PATH_VARIANTS.size()]
	if h >= 97:
		return GRASS_FLOWERS
	if h >= 55:
		return GRASS_VARIANTS[h % GRASS_VARIANTS.size()]
	return GRASS_PLAIN
