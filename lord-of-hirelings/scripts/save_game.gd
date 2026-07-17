extends Node
## The campaign autosave (GDD "Title screen and campaign save", "Saving").
##
## There is exactly ONE save file and no slots — every autosave replaces it.
## There are exactly TWO moments that write it: the parties entering the mine
## before any combat has happened, and the expedition finishing, immediately
## before the summary panel opens. Nothing else saves, and nothing saves
## mid-combat.
##
## That narrowness is the design, not a shortcut waiting to be widened: because
## a dive is only ever saved BEFORE it is fought, no combat state has to be
## serialized at all. The file holds town state plus a marker for which dive is
## about to run, so quitting mid-dive resumes at the mouth of the mine and the
## expedition is simply re-rolled. Do not add granularity here — the GDD says so
## in as many words.
##
## Registered last in project.godot: restoring reads and writes GameState and
## Roster, so both are already up when this node is.

## Settings live per install and are deliberately NOT in here (GDD), so this is
## the campaign and nothing else.
const SAVE_PATH := "user://campaign.save"
## Bumped when the layout below changes shape. An older file is discarded rather
## than migrated: the game has one autosave and losing it costs a day, not a
## campaign's worth of slots.
const SAVE_VERSION := 2

## The two autosave moments (GDD "Saving"), stored so a resume knows which of
## the two it is picking up and Manage Save can name it.
const POINT_DIVE := "dive"
const POINT_SUMMARY := "summary"

## Autosave 2 exists only so the expedition summary can be re-shown from the top
## (GDD), so the file keeps exactly the readout the panel renders and nothing
## else. The per-fight logs a dive carries are the initiative orders, spawns,
## rolled traits and boss flags that must never be serialized, and the HP and
## morale a member row ends on are combat state the panel never draws — so the
## save is built from these keys rather than by stripping the ones to omit.
const SUMMARY_KEYS := ["day", "gold_earned", "tax_copy"]
const DIVE_KEYS := ["dungeon_level", "completed"]
const MEMBER_KEYS := [
	"name", "class", "alive", "fled", "killed_by", "xp_earned", "gold_kept",
	"start_level", "level", "levels_gained", "xp",
]

## The graveyard's restored plot, parked here until the town scene instantiates
## it: it is a node rather than an autoload, so it does not exist to be written
## to at the moment a save is loaded and collects this from its own _ready.
var pending_graveyard: Dictionary = {}

## The marker load_game() restored, waiting for the gameplay scene to act on it.
## Taken exactly once — main.gd consumes it through take_resume() — so a later
## return to the town can never replay a dive the player has already finished.
var _resume: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## What Manage Save reports (GDD): { "day", "dungeon_level", "point" }, or {}
## when there is no readable save.
func read_header() -> Dictionary:
	var data := _read()
	if data.is_empty():
		return {}
	var town: Dictionary = data.get("town", {})
	return {
		"day": int(town.get("day", 0)),
		"dungeon_level": int(town.get("unlocked_dungeon_level", 1)),
		"point": String((data.get("pending", {}) as Dictionary).get("point", "")),
	}


## The GDD's "most recent autosave point", in the words Manage Save shows.
static func point_label(point: String) -> String:
	match point:
		POINT_DIVE:
			return "Entering the dungeon"
		POINT_SUMMARY:
			return "Expedition summary"
	return "Unknown"


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_resume = {}


## Autosave 1 (GDD): the parties are marching and no combat has happened yet.
## Only the seats they march in are recorded — the dive itself does not exist
## yet, and on a resume it is rolled fresh.
func save_dive_entry() -> void:
	_write({"point": POINT_DIVE, "parties": _party_seats()})


## Autosave 2 (GDD): the expedition is resolved and every coin, level and burial
## it owed the town has been paid, so this is the settled town plus the readout
## still owed to the player. [param won] rides along because the win fires
## exactly once and GameState.game_won is already true by now — without it, a
## player who quits while the winning summary is on screen would never get the
## announcement it queues behind.
func save_expedition_summary(summary: Dictionary, won: bool) -> void:
	_write({
		"point": POINT_SUMMARY,
		"won": won,
		"summary": _summary_for_save(summary),
	})


## Restores the autosave onto the town autoloads and returns the resume marker
## (or {} when there is no readable save). The marker is what the gameplay scene
## acts on; everything else is already applied by the time this returns, so the
## town scene can build itself from the autoloads exactly as it does on a fresh
## campaign.
func load_game() -> Dictionary:
	var data := _read()
	if data.is_empty():
		return {}
	_load_town(data.get("town", {}))
	_resume = data.get("pending", {})
	# The seats are part of the marker rather than the town: they only mean
	# anything to the dive about to be re-rolled, and they can only be turned
	# back into roster references once the roster above is restored.
	_restore_parties(_resume.get("parties", []))
	return _resume


## The resume marker, handed over exactly once.
func take_resume() -> Dictionary:
	var resume := _resume
	_resume = {}
	return resume


func _town_state() -> Dictionary:
	var graveyard := get_tree().get_first_node_in_group("graveyard")
	return {
		"day": GameState.day,
		"gold": GameState.gold,
		"phase": int(GameState.phase),
		"unlocked_dungeon_level": GameState.unlocked_dungeon_level,
		"game_won": GameState.game_won,
		"endless_tier": GameState.endless_tier,
		"building_levels": GameState.building_levels.duplicate(),
		"members": _members_for_save(),
		"party_actions_used": Roster.party_actions_used,
		"graveyard": graveyard.save_state() if graveyard != null else {},
	}


func _load_town(town: Dictionary) -> void:
	GameState.day = int(town.get("day", 0))
	GameState.gold = int(town.get("gold", 0))
	# Assigned rather than pushed through advance_day/call_to_arms: restoring is
	# not a transition, and the town scene reads the phase as it builds rather
	# than waiting on the signal.
	GameState.phase = int(town.get("phase", GameState.Phase.NIGHT)) as GameState.Phase
	GameState.unlocked_dungeon_level = clampi(
		int(town.get("unlocked_dungeon_level", 1)), 1, Expedition.MAX_DUNGEON_LEVEL)
	GameState.game_won = bool(town.get("game_won", false))
	GameState.endless_tier = maxi(int(town.get("endless_tier", 0)), 0)
	GameState.building_levels = _loaded_building_levels(town.get("building_levels", {}))
	Roster.members = _loaded_members(town.get("members", []))
	Roster.party_actions_used = maxi(int(town.get("party_actions_used", 0)), 0)
	pending_graveyard = town.get("graveyard", {})


## Roster.members as save data. Written key by key rather than duplicated so the
## types survive the round trip: JSON has one number type, and every level, tier
## and purse in here is an int that the game reads back as one.
func _members_for_save() -> Array:
	var out: Array = []
	for member in Roster.members:
		var gear: Dictionary = member.get("gear", {})
		var saved_gear := {}
		for slot in Items.SLOTS:
			saved_gear[slot] = int(gear.get(slot, Items.MIN_TIER))
		out.append({
			"name": String(member.get("name", "")),
			"class": String(member.get("class", "")),
			"level": int(member.get("level", 1)),
			"gold": int(member.get("gold", 0)),
			"xp": int(member.get("xp", 0)),
			"gear": saved_gear,
		})
	return out


func _loaded_members(saved: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in saved:
		var row: Dictionary = entry
		var saved_gear: Dictionary = row.get("gear", {})
		var gear := {}
		for slot in Items.SLOTS:
			gear[slot] = clampi(int(saved_gear.get(slot, Items.MIN_TIER)),
					Items.MIN_TIER, Items.MAX_TIER)
		out.append({
			"name": String(row.get("name", "")),
			"class": String(row.get("class", "")),
			"level": maxi(int(row.get("level", 1)), 1),
			"gold": maxi(int(row.get("gold", 0)), 0),
			"xp": maxi(int(row.get("xp", 0)), 0),
			"gear": gear,
		})
	return out


func _loaded_building_levels(saved: Dictionary) -> Dictionary:
	var out := {}
	for building_id in saved:
		out[String(building_id)] = clampi(
			int(saved[building_id]), 0, GameState.MAX_BUILDING_LEVEL)
	return out


## The formed parties as seats: each party's members by their index into the
## roster saved alongside them. The parties are references INTO Roster.members,
## so they cannot be stored as members of their own without the resumed dive
## paying its gold to copies.
func _party_seats() -> Array:
	var out: Array = []
	for party in Roster.parties:
		var seats: Array = []
		for member in party:
			var index := _member_index(String(member.get("name", "")))
			if index != -1:
				seats.append(index)
		out.append(seats)
	return out


func _restore_parties(saved: Array) -> void:
	var parties: Array[Array] = []
	for seats in saved:
		var party: Array = []
		for seat in seats:
			var index := int(seat)
			if index >= 0 and index < Roster.members.size():
				party.append(Roster.members[index])
		parties.append(party)
	Roster.parties = parties


## The roster index of [param display_name], or -1. Matched by display name,
## which the roster's uniqueness rule guarantees is a key.
func _member_index(display_name: String) -> int:
	for i in Roster.members.size():
		if Roster.members[i]["name"] == display_name:
			return i
	return -1


func _summary_for_save(summary: Dictionary) -> Dictionary:
	var out := _picked(summary, SUMMARY_KEYS)
	var dives: Array = []
	for entry in summary.get("dives", []):
		var dive: Dictionary = entry
		var saved_dive := _picked(dive, DIVE_KEYS)
		var members: Array = []
		for row in dive.get("members", []):
			members.append(_picked(row, MEMBER_KEYS))
		saved_dive["members"] = members
		dives.append(saved_dive)
	out["dives"] = dives
	return out


func _picked(source: Dictionary, keys: Array) -> Dictionary:
	var out := {}
	for key in keys:
		if source.has(key):
			out[key] = source[key]
	return out


func _write(pending: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveGame: cannot write %s (%s)" % [
			SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	# One save, written whole every time: there is nothing to merge with, and a
	# torn file is simply a campaign that rolls back one autosave.
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"town": _town_state(),
		"pending": pending,
	}))


func _read() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveGame: cannot read %s (%s)" % [
			SAVE_PATH, error_string(FileAccess.get_open_error())])
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveGame: %s is not a save file" % SAVE_PATH)
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("SaveGame: ignoring save version %s (expected %d)" % [
			data.get("version", "?"), SAVE_VERSION])
		return {}
	return data
