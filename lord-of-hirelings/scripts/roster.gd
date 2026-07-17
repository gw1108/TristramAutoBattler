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
## Parties were (re)formed by the call to arms; the dungeon dive and the
## party-actions UI read the parties array when this fires.
signal parties_formed
## A Kick or Swap rearranged the formed parties (and spent an action); the
## hero panel's party row redraws on this.
signal parties_changed

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

## Formation geometry (GDD call to arms): up to 3 parties of 1-3 adventurers,
## so the shuffle-draft seats at most 9. Structural, not tunable — the dungeon
## dive's row split and the expedition summary's columns are built around 3.
const PARTY_COUNT := 3
const PARTY_MAX_SIZE := 3

## Hired adventurers, in hire order. Each entry:
## { "name": String, "class": String, "level": int, "gold": int, "xp": int }
## `xp` is progress toward the next level only — the expedition summary spends
## it on level-ups and writes back the remainder (BalanceNumbers growth).
var members: Array[Dictionary] = []

## The expedition parties formed at the call to arms: PARTY_COUNT arrays of
## 0-PARTY_MAX_SIZE references into members. Empty between expeditions. An
## empty party is treated as if it does not exist (GDD): no dive row, no
## summary column.
var parties: Array[Array] = []

## Party actions (Kick/Swap) spent today. The budget refills each dawn, not
## each call to arms, so it is the day that gates the player's meddling.
var party_actions_used: int = 0

## Display names currently reserved by unhired recruits standing at the inn,
## so two visible recruits can never share a name (GDD uniqueness rule).
var _reserved_names := {}

## Display names currently carved on graveyard headstones; the graveyard
## records/releases these as graves are added and overwritten.
var _grave_names := {}


func _ready() -> void:
	# Parties only exist for the expedition; nightfall dissolves them.
	GameState.phase_changed.connect(func(new_phase: GameState.Phase) -> void:
		if new_phase == GameState.Phase.NIGHT:
			clear_parties())
	GameState.day_advanced.connect(func(_day: int) -> void:
		party_actions_used = 0)


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
		"xp": 0,
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


## Forms the expedition parties (GDD call to arms). If the town has no hired
## adventurers, 1-2 free level 1 fallback adventurers are first added to the
## roster permanently — the player can never get permanently stuck. Then the
## shuffle-draft: shuffle the hired list, and the first 9 (or all, if fewer)
## each join a party picked uniformly at random among those still under 3
## members. Adventurers beyond the first 9 stay in town as reserves.
func form_parties() -> void:
	if members.is_empty():
		_add_fallback_adventurers()
	parties.clear()
	for _i in PARTY_COUNT:
		parties.append([])
	var pool := members.duplicate()
	pool.shuffle()
	for i in mini(pool.size(), PARTY_COUNT * PARTY_MAX_SIZE):
		var open: Array[Array] = []
		for party in parties:
			if party.size() < PARTY_MAX_SIZE:
				open.append(party)
		open.pick_random().append(pool[i])
	parties_formed.emit()


## Drops the formed parties; called when the expedition resolves and the
## world returns to night.
func clear_parties() -> void:
	parties.clear()


## Members drafted into no party this expedition — who Kick swaps in.
func reserves() -> Array[Dictionary]:
	var drafted := {}
	for party in parties:
		for member in party:
			drafted[member["name"]] = true
	var out: Array[Dictionary] = []
	for member in members:
		if not drafted.has(member["name"]):
			out.append(member)
	return out


## Party actions the player gets per day: 2 by default, raised to 3 once the
## inn's War Table upgrade exists (GDD; the upgrade tree is a later slice).
func party_actions_max() -> int:
	return int(BalanceData.get_value("party_actions_per_day", 2.0))


func party_actions_left() -> int:
	return maxi(party_actions_max() - party_actions_used, 0)


## The index into parties of the party holding [param display_name], or -1 if
## they are a reserve (or no parties are formed).
func party_index_of(display_name: String) -> int:
	return _slot_of(display_name).x


## Kick (GDD party formation): trades [param display_name] out of their party
## for a reserve rolled uniformly, spending one party action. Returns whether
## it happened; an action is only spent on a real swap.
func kick(display_name: String) -> bool:
	if party_actions_left() <= 0:
		return false
	var slot := _slot_of(display_name)
	if slot.x < 0:
		return false
	var pool := reserves()
	if pool.is_empty():
		return false
	parties[slot.x][slot.y] = pool.pick_random()
	party_actions_used += 1
	parties_changed.emit()
	return true


## Swap (GDD party formation): trades [param display_name] with a uniformly
## rolled member of a *different* party, spending one party action. With no
## valid target — only one non-empty party — this is a no-op that costs
## nothing, exactly as the GDD spells out.
func swap(display_name: String) -> bool:
	if party_actions_left() <= 0:
		return false
	var slot := _slot_of(display_name)
	if slot.x < 0:
		return false
	var targets: Array[Vector2i] = []
	for i in parties.size():
		if i == slot.x:
			continue
		for j in parties[i].size():
			targets.append(Vector2i(i, j))
	if targets.is_empty():
		return false
	var target: Vector2i = targets.pick_random()
	var moved: Dictionary = parties[slot.x][slot.y]
	parties[slot.x][slot.y] = parties[target.x][target.y]
	parties[target.x][target.y] = moved
	party_actions_used += 1
	parties_changed.emit()
	return true


## (party index, index within that party) for [param display_name], or (-1, -1)
## when they hold no party slot.
func _slot_of(display_name: String) -> Vector2i:
	for i in parties.size():
		for j in parties[i].size():
			if parties[i][j]["name"] == display_name:
				return Vector2i(i, j)
	return Vector2i(-1, -1)


## GDD free-fallback rule: a call to arms with an empty roster always summons
## 1 or 2 free level 1 adventurers (uniform roll), same class and name
## generators as recruits, tier 0 gear, 0 personal gold, hired permanently.
func _add_fallback_adventurers() -> void:
	var count := randi_range(
		int(BalanceData.get_value("fallback_adventurers_min", 1.0)),
		int(BalanceData.get_value("fallback_adventurers_max", 2.0)))
	for _i in count:
		add_member(generate_unique_name(), roll_class(), 1, 0)


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
