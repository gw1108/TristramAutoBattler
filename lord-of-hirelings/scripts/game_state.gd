extends Node
## Autoload ledger for the two numbers every system haggles over:
## the day counter and the player's treasury gold.
##
## Registered after BalanceData in project.godot so the starting gold row
## is already loaded when this node seeds the treasury.

signal day_advanced(new_day: int)
signal gold_changed(new_gold: int)

var day: int = 1
var gold: int = 0


func _ready() -> void:
	gold = int(BalanceData.get_value("player_starting_gold", 19.0))


func advance_day() -> void:
	day += 1
	day_advanced.emit(day)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


## Deducts [param amount] if the treasury can cover it. Returns whether it did.
func spend_gold(amount: int) -> bool:
	if amount <= 0 or amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func can_afford(amount: int) -> bool:
	return amount <= gold
