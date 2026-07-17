extends Node
## Autoload roster of hired adventurers (GDD town phase). Hiring a recruit
## appends an entry here; the hero panel and party formation read from it in
## later slices. Also owns the GDD name generator: display names are
## "<first name> <epithet>", unique across everything the player can currently
## see referenced — hired adventurers, recruits standing at the inn, and the
## names carved on the graveyard's headstones.

signal roster_changed
## A hired adventurer died and left the roster; the graveyard listens to this
## to raise a grave.
signal member_died(display_name: String)

## The six adventurer classes (BalanceNumbers "Base stats per class").
## Recruit class is rolled uniformly from these, independently per recruit.
const CLASSES := [
	"Knight", "Captain", "Berserker", "Mage", "Rogue", "Cleric",
]

## Name-generation tables from BalanceNumbers (40 x 40 = 1,600 combinations).
const FIRST_NAMES := [
	"Aldric", "Bram", "Cassia", "Corvin", "Dain", "Ede", "Elowen", "Faron",
	"Greta", "Grom", "Hale", "Hestia", "Ilsa", "Jorund", "Kesta", "Lorne",
	"Mabel", "Marrow", "Morwen", "Nix", "Orrin", "Oswin", "Perrin", "Piety",
	"Quill", "Rook", "Roswald", "Rulf", "Sable", "Sela", "Tamsin", "Torvald",
	"Ulric", "Umbra", "Vanya", "Vex", "Wren", "Wystan", "Yorick", "Zeta",
]
const EPITHETS := [
	"the Unyielding", "the Ashen", "the Wailing", "the Grey", "the Kind",
	"the Bitter", "the Bright", "the Cracked", "the Dour", "the Eager",
	"the Fond", "the Gilded", "the Hollow", "the Ill-Starred", "the Jaded",
	"the Keen", "the Lost", "the Meek", "the Nameless", "the Owed",
	"the Patient", "the Quiet", "the Ruined", "the Sour", "the Thrice-Buried",
	"the Unfinished", "the Vain", "the Weary", "the Younger", "the Zealous",
	"the Rope-Necked", "the Half-Drowned", "the Second-Best", "the Unpaid",
	"the Coin-Bitten", "the Late", "the Sleepless", "the Stubborn",
	"the Fortunate", "the Overdue",
]

## Hired adventurers, in hire order. Each entry:
## { "name": String, "class": String, "level": int, "gold": int }
var members: Array[Dictionary] = []

## Display names currently reserved by unhired recruits standing at the inn,
## so two visible recruits can never share a name (GDD uniqueness rule).
var _reserved_names := {}

## Display names currently carved on graveyard headstones; the graveyard
## records/releases these as graves are added and overwritten.
var _grave_names := {}


func max_size() -> int:
	return int(BalanceData.get_value("roster_max_size", 100.0))


## GDD economy: hiring is disabled while the roster sits at the hard cap.
func is_full() -> bool:
	return members.size() >= max_size()


func roll_class() -> String:
	return CLASSES[randi() % CLASSES.size()]


## Rolls "<first name> <epithet>" uniformly and independently, rerolling on
## collision with any name the player can currently see referenced.
func generate_unique_name() -> String:
	var candidate := ""
	# 1,600 combinations vs ~100 taken at worst: the reroll almost never
	# fires more than once. The bound only guards against a pathological
	# table shrink ever turning this into an infinite loop.
	for _attempt in 1000:
		candidate = "%s %s" % [FIRST_NAMES.pick_random(), EPITHETS.pick_random()]
		if not _is_name_taken(candidate):
			break
	return candidate


## Marks a name as visible at the inn so later rolls avoid it.
func reserve_name(display_name: String) -> void:
	_reserved_names[display_name] = true


## Frees a reservation when its recruit leaves unhired (hired names stay
## taken through the members array instead).
func release_name(display_name: String) -> void:
	_reserved_names.erase(display_name)


## Appends a hired adventurer. Returns false (and records nothing) at the cap.
## `gold` is starting personal gold — the pre-discount base cost when the hire
## was sponsored (GDD two-purse economy), 0 for a plain hire.
func add_member(display_name: String, adventurer_class: String, level: int = 1, gold: int = 0) -> bool:
	if is_full():
		return false
	members.append({
		"name": display_name,
		"class": adventurer_class,
		"level": level,
		"gold": gold,
	})
	roster_changed.emit()
	return true


## Removes a hired adventurer from the roster (death). Returns whether the
## name was found. Emits member_died before roster_changed so the graveyard
## records the grave name ahead of any reroll a roster listener might cause.
func kill_member(display_name: String) -> bool:
	for i in members.size():
		if members[i]["name"] == display_name:
			members.remove_at(i)
			member_died.emit(display_name)
			roster_changed.emit()
			return true
	return false


## Marks a name as carved on a headstone so later rolls avoid it (GDD rule).
func record_grave_name(display_name: String) -> void:
	_grave_names[display_name] = true


## Frees a headstone name when its grave is overwritten by a newer one.
func release_grave_name(display_name: String) -> void:
	_grave_names.erase(display_name)


func _is_name_taken(display_name: String) -> bool:
	if _reserved_names.has(display_name) or _grave_names.has(display_name):
		return true
	for member in members:
		if member["name"] == display_name:
			return true
	return false
