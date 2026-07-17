extends Node
## Autoload ledger for the two numbers every system haggles over:
## the day counter and the player's treasury gold.
##
## Registered after BalanceData in project.godot so the starting gold row
## is already loaded when this node seeds the treasury.

signal day_advanced(new_day: int)
signal gold_changed(new_gold: int)
signal phase_changed(new_phase: Phase)
signal building_state_changed(building_id: String, state: BuildingState)

## The town's time-of-day cycle (GDD): the world starts at night, the rooster
## crow brings the day, ringing the dungeon bell starts the call to arms
## (locking all town changes for the expedition), and finishing an expedition
## returns it to night.
enum Phase { NIGHT, DAY, CALL_TO_ARMS }

## Rebuild status of a town building. Every building but the Inn starts as a
## ruin (GDD); building nodes write through set_building_state so systems that
## don't own the node (shop UI, commissions, upgrades) can query and react.
enum BuildingState { RUINED, BUILT }

## The day is a count of expeditions made, so the first expedition is day 1
## (GDD). The world starts at night with no expedition behind it, so the
## counter starts at 0 and the first rooster crow brings day 1.
var day: int = 0
var gold: int = 0
var phase: Phase = Phase.NIGHT

## building_id (e.g. "weapon_shop") -> BuildingState. Buildings register
## themselves here from set_ruined; absent means RUINED.
var building_states: Dictionary = {}

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


## Starts the call to arms (the dungeon bell). Only valid during the day —
## the bell only works after the rooster has crowed, never at night (GDD),
## and ringing twice does nothing. Returns whether the phase changed.
func call_to_arms() -> bool:
	if phase != Phase.DAY:
		return false
	phase = Phase.CALL_TO_ARMS
	phase_changed.emit(phase)
	return true


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


## Records [param building_id]'s state, emitting building_state_changed only
## on an actual change.
func set_building_state(building_id: String, state: BuildingState) -> void:
	if building_states.get(building_id) == state:
		return
	building_states[building_id] = state
	building_state_changed.emit(building_id, state)


func is_building_built(building_id: String) -> bool:
	return building_states.get(building_id, BuildingState.RUINED) == BuildingState.BUILT
