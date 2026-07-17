extends Node
## Autoload ledger for the two numbers every system haggles over:
## the day counter and the player's treasury gold.
##
## Registered after BalanceData in project.godot so the starting gold row
## is already loaded when this node seeds the treasury.

signal day_advanced(new_day: int)
signal gold_changed(new_gold: int)
signal phase_changed(new_phase: Phase)

## The town's time-of-day cycle (GDD): the world starts at night, the rooster
## crow brings the day, and finishing an expedition returns it to night.
enum Phase { NIGHT, DAY }

var day: int = 1
var gold: int = 0
var phase: Phase = Phase.NIGHT

## Dev toggle: while expeditions don't exist yet nothing can return the world
## to night, so this keeps the rooster usable every pass through the loop.
var dev_force_night: bool = true


func _ready() -> void:
	gold = int(BalanceData.get_value("player_starting_gold", 19.0))
	dev_force_night = BalanceData.get_value("dev_force_night", 1.0) != 0.0


func is_night() -> bool:
	return dev_force_night or phase == Phase.NIGHT


## Starts a new day (rooster crow). Only valid at night.
func advance_day() -> void:
	if not is_night():
		return
	day += 1
	phase = Phase.DAY
	day_advanced.emit(day)
	phase_changed.emit(phase)


## Returns the world to night. Called when an expedition concludes (GDD);
## until expeditions exist, only dev tooling has a reason to call this.
func return_to_night() -> void:
	if phase == Phase.NIGHT:
		return
	phase = Phase.NIGHT
	phase_changed.emit(phase)


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
