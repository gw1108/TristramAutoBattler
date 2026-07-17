extends Node
## Autoload ledger for the two numbers every system haggles over:
## the day counter and the player's treasury gold.
##
## Registered after BalanceData in project.godot so the starting gold row
## is already loaded when this node seeds the treasury.

signal day_advanced(new_day: int)
signal gold_changed(new_gold: int)
signal phase_changed(new_phase: Phase)
signal building_level_changed(building_id: String, level: int)

## The town's time-of-day cycle (GDD): the world starts at night, the rooster
## crow brings the day, ringing the dungeon bell starts the call to arms
## (locking all town changes for the expedition), and finishing an expedition
## returns it to night.
enum Phase { NIGHT, DAY, CALL_TO_ARMS }

## Every building maxes at level 5 (BalanceNumbers "Building upgrade costs").
## What a level buys is the building's own business — for a shop it is the gear
## tiers it stocks (Items.stocked_max_tier) and then its two shop-wide lines.
const MAX_BUILDING_LEVEL := 5

## The day is a count of expeditions made, so the first expedition is day 1
## (GDD). The world starts at night with no expedition behind it, so the
## counter starts at 0 and the first rooster crow brings day 1.
var day: int = 0
var gold: int = 0
var phase: Phase = Phase.NIGHT

## The deepest dungeon level the parties may pick, 1..Expedition.MAX_DUNGEON_LEVEL.
## The party AI aims at this ceiling (Encounters.choose_dungeon_level); killing a
## level's boss opens the next one for every future expedition, so this outlives
## the expedition that earned it.
var unlocked_dungeon_level: int = 1

## The campaign has been won: a party has cleared dungeon level 4's boss (GDD).
## Winning changes no rule except that it opens endless mode — the player keeps
## playing the same town and the same four levels.
var game_won: bool = false

## Endless mode's difficulty (GDD, BalanceNumbers "Endless mode"). Every
## expedition is fought and paid at exactly one tier, and clearing level 4 raises
## it by 1, making the same level's enemies tougher and their drops richer. It is
## 0 for the whole campaign INCLUDING the winning dive, so nothing before the win
## is scaled at all.
var endless_tier: int = 0

## building_id (e.g. "weapon_shop") -> building level, 0..MAX_BUILDING_LEVEL.
## Level 0 is the ruin every building but the Inn starts as (GDD) and the
## rebuild buys level 1, so an absent building — one nothing has been spent on
## yet — reads as 0. Buildings register themselves here from set_level, so
## systems that don't own the node (shop stock, commissions) can query and
## react without reaching into the town scene.
var building_levels: Dictionary = {}

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


## Records the level an expedition's boss clear opened (the dungeon entrance
## feeds it the expedition summary's unlocked_level). Never regresses, and never
## reaches past the four levels the bestiary actually has.
func unlock_dungeon_level(level: int) -> void:
	unlocked_dungeon_level = clampi(
		maxi(level, unlocked_dungeon_level), 1, Expedition.MAX_DUNGEON_LEVEL)


## Records an expedition in which at least one party fully cleared dungeon level
## 4 (the summary's `cleared_final`). Returns whether this one WON the campaign,
## which is true exactly once — the caller announces the win off that.
##
## Call this only after the expedition's rewards have been resolved: the clear is
## fought and paid at the tier it started on, and only then does the tier rise
## (BalanceNumbers "Endless mode"). The rise is per expedition and not per
## clearing party, matching the rule that one party beating the boss is enough to
## complete the level — so three parties clearing on the same day is still +1.
func record_final_clear() -> bool:
	var won_now := not game_won
	game_won = true
	endless_tier += 1
	return won_now


## Returns the world to night. Called when an expedition concludes (GDD).
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


## Records [param building_id]'s level, clamped to the ladder's ends and
## emitting building_level_changed only on an actual change.
func set_building_level(building_id: String, level: int) -> void:
	var clamped := clampi(level, 0, MAX_BUILDING_LEVEL)
	if building_levels.get(building_id) == clamped:
		return
	building_levels[building_id] = clamped
	building_level_changed.emit(building_id, clamped)


## [param building_id]'s level; 0 (a ruin) for any building never built.
func building_level(building_id: String) -> int:
	return int(building_levels.get(building_id, 0))
