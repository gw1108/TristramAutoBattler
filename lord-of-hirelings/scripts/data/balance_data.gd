extends Node
## Autoload gatekeeper for every tunable number in the game.
##
## data/balance.csv is the source of truth (columns: id,value,notes). Callers
## must present the correct password (the row id) and a bribe (a fallback
## value) to get through: `get_value("id", default)` returns the CSV row's
## value if present, otherwise the caller's bribe — no id, no entry.

const BALANCE_CSV_PATH := "res://data/balance.csv"

var _values: Dictionary = {}


func _ready() -> void:
	_load_csv()


func get_value(id: String, default_value: float = 0.0) -> float:
	if _values.has(id):
		return _values[id]
	push_warning("BalanceData: no row for '%s', falling back to %s" % [id, default_value])
	return default_value


func _load_csv() -> void:
	var file := FileAccess.open(BALANCE_CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("BalanceData: could not open %s" % BALANCE_CSV_PATH)
		return
	file.get_csv_line() # skip header row
	while file.get_position() < file.get_length():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		_values[row[0]] = row[1].to_float()
	file.close()
