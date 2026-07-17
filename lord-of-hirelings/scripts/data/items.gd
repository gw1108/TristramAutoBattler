class_name Items
extends Object
## Static reader for data/items.csv — the BalanceNumbers "Item names" table
## (6 classes x 3 slots x 6 tiers) — plus the tier cost/gate rules and the
## shop-level stocking rule from the same doc. The hero panel reads names from
## here; Shops reads the rules to run the purchasing AI. The name table itself
## is structural data in its own CSV; the costs and gate live in balance.csv.

const CSV_PATH := "res://data/items.csv"

## The three gear slots, in the purchasing AI's tie-break order (BalanceNumbers
## "Purchasing AI": ties go weapon -> armor -> jewelry). These are also the
## CSV's column order after the leading class and tier columns, and the row
## order of the hero panel's inventory list.
const SLOTS := ["weapon", "armor", "jewelry"]

## Everyone arrives wearing tier 0 in all three slots; tier 5 is the maximum.
const MIN_TIER := 0
const MAX_TIER := 5

## Which building sells which slot (GDD "The three equipment shops": one shop
## per slot, and no shop ever competes for another's slot).
const SLOT_BUILDINGS := {
	"weapon": "weapon_shop",
	"armor": "armor_shop",
	"jewelry": "jewelry_shop",
}

## class -> tier -> {slot: name}
static var _names: Dictionary = {}


## The item name a [param adventurer_class] wears in [param slot] at
## [param tier], or "" if the class/slot/tier is unknown. Tier 0 has names of
## its own because the inventory list always shows all three slots (GDD).
static func item_name(adventurer_class: String, slot: String, tier: int) -> String:
	if _names.is_empty():
		_load_csv()
	var tiers: Dictionary = _names.get(adventurer_class, {})
	var row: Dictionary = tiers.get(clampi(tier, MIN_TIER, MAX_TIER), {})
	return row.get(slot, "")


## Gold price of [param tier], for every class and every slot alike
## (BalanceNumbers "Equipment": 8/16/32/64/128). Tier 0 is free — it is what
## everyone already wears, not something a shop sells.
static func tier_cost(tier: int) -> int:
	if tier <= MIN_TIER or tier > MAX_TIER:
		return 0
	return maxi(0, roundi(_balance("item_tier_%d_cost" % tier, pow(2.0, 2.0 + tier))))


## Minimum adventurer level tier [param tier] demands: 2N - 1, deliberately
## mirroring Encounters.min_average_level so gear and depth advance together.
static func hero_level_gate(tier: int) -> int:
	return maxi(1, roundi(_balance("item_gate_level_per_tier", 2.0) * maxi(tier, 1) \
			+ _balance("item_gate_level_offset", -1.0)))


## The highest tier a shop at [param shop_level] stocks (BalanceNumbers
## "Equipment"): a ruined shop (level 0) sells nothing, level 1 stocks tiers
## 1-2, level 2 adds 3-4, level 3 adds tier 5. Levels 4 and 5 unlock that
## shop's two shop-wide lines rather than more tiers, so they stock no more
## than level 3 does. Building levels are a later slice — Shops.shop_level
## currently reports every rebuilt shop as level 1.
static func stocked_max_tier(shop_level: int) -> int:
	if shop_level <= 0:
		return MIN_TIER
	return mini(shop_level * 2, MAX_TIER)


## BalanceData.get_value for static context. Godot 4.7 cannot resolve
## autoload identifiers inside static functions ("Identifier not found"),
## so the autoload is fetched through the scene tree instead.
static func _balance(id: String, default_value: float) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return default_value
	var balance := tree.root.get_node_or_null("BalanceData")
	if balance == null:
		return default_value
	return balance.get_value(id, default_value)


static func _load_csv() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("Items: could not open %s" % CSV_PATH)
		return
	file.get_csv_line() # skip header row
	while file.get_position() < file.get_length():
		var row := file.get_csv_line()
		if row.size() < SLOTS.size() + 2 or row[0].is_empty():
			continue
		var slots := {}
		for i in SLOTS.size():
			slots[SLOTS[i]] = row[i + 2]
		if not _names.has(row[0]):
			_names[row[0]] = {}
		_names[row[0]][row[1].to_int()] = slots
	file.close()
