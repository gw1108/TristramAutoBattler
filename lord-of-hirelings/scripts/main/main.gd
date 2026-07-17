extends Node2D
## Root of the main gameplay (town) scene. Town systems (player movement,
## interactables, day cycle) land here in later slices.

## 16px grid geometry of sprites/town/town_ground_tiles.png (structural,
## not a tunable). Row 0: columns 0-3 grass, 4-6 dirt path, 7 gold
## wildflowers. Row 1: grass-to-dirt transitions — columns 0-3 grass lip on
## the N/E/S/W edge, columns 4-7 grass corner nub at NE/SE/SW/NW.
const TILE_PX := 16
const GRASS_PLAIN := Vector2i(0, 0)
const GRASS_VARIANTS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const GRASS_FLOWERS := Vector2i(7, 0)
const PATH_VARIANTS: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)]
const PATH_LIPS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
const PATH_NUBS: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]

@onready var _town_ground: TileMapLayer = $TownGround

# Town ground/path geometry, set by _fill_town_ground for _is_path_cell.
var _ground_cols := 0
var _ground_rows := 0
var _path_half_lo := 0
var _path_half_hi := 0
var _path_cx := 0
var _path_cy := 0


func _ready() -> void:
	_fill_town_ground()
	# Deferred so every town node has had its _ready: the dive is re-run by the
	# mine entrance and the readout is drawn by the summary panel, and neither
	# exists yet while this node is coming up.
	_resume_autosave.call_deferred()


## Picks up where the campaign autosave left off (GDD "Saving"). SaveGame has
## already restored the town onto the autoloads before this scene was even
## loaded — so the town below built itself from the save exactly as it builds
## itself from a fresh campaign — and what is left is the marker for which of
## the two autosave moments this is.
func _resume_autosave() -> void:
	var resume := SaveGame.take_resume()
	var entrance := $DungeonEntrance
	match String(resume.get("point", "")):
		SaveGame.POINT_DIVE:
			# Nothing about the dive was saved, so there is nothing to restore:
			# the parties simply march again and it is re-rolled from the top.
			entrance.enter()
		SaveGame.POINT_SUMMARY:
			entrance.replay_summary(
				resume.get("summary", {}), bool(resume.get("won", false)))


func _fill_town_ground() -> void:
	# balance.csv is the source of truth for the town bounds.
	_ground_cols = ceili(BalanceData.get_value("town_map_width", 1920.0) / TILE_PX)
	_ground_rows = ceili(BalanceData.get_value("town_map_height", 1080.0) / TILE_PX)
	var path_w := int(BalanceData.get_value("town_path_width_tiles", 3.0))
	_path_half_lo = path_w / 2
	_path_half_hi = path_w - _path_half_lo
	_path_cx = _ground_cols / 2
	_path_cy = _ground_rows / 2
	for y in _ground_rows:
		for x in _ground_cols:
			_town_ground.set_cell(Vector2i(x, y), 0, _pick_tile(x, y))


func _is_path_cell(x: int, y: int) -> bool:
	# Off-map counts as path so the arms run cleanly off the map edge.
	if x < 0 or y < 0 or x >= _ground_cols or y >= _ground_rows:
		return true
	return (y - _path_cy >= -_path_half_lo and y - _path_cy < _path_half_hi) \
			or (x - _path_cx >= -_path_half_lo and x - _path_cx < _path_half_hi)


func _pick_tile(x: int, y: int) -> Vector2i:
	# Deterministic per-cell hash so the ground is stable across runs.
	var h := absi((x * 73856093) ^ (y * 19349663)) % 100
	if _is_path_cell(x, y):
		# Border cells get grass-lip transitions (N/E/S/W), and the path
		# junction's concave corners (grass diagonal-only) get corner nubs.
		var grass_at := [not _is_path_cell(x, y - 1), not _is_path_cell(x + 1, y),
				not _is_path_cell(x, y + 1), not _is_path_cell(x - 1, y)]
		var lip := grass_at.find(true)
		if lip != -1:
			return PATH_LIPS[lip]
		var diag_at := [not _is_path_cell(x + 1, y - 1), not _is_path_cell(x + 1, y + 1),
				not _is_path_cell(x - 1, y + 1), not _is_path_cell(x - 1, y - 1)]
		var nub := diag_at.find(true)
		if nub != -1:
			return PATH_NUBS[nub]
		return PATH_VARIANTS[h % PATH_VARIANTS.size()]
	if h >= 97:
		return GRASS_FLOWERS
	if h >= 55:
		return GRASS_VARIANTS[h % GRASS_VARIANTS.size()]
	return GRASS_PLAIN
