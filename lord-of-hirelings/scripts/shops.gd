extends Node
## Autoload for the player's three equipment shops: what they stock, what the
## adventurers buy, and the sales commission the player skims off every sale
## (GDD "Economy", the second of the two taxes).
##
## The shops have no counter to stand at and no UI — adventurers buy on their
## own (BalanceNumbers "Purchasing AI"), so this node just watches the town for
## the moments a purchase could newly become possible and runs the pass.
##
## Registered after GameState and Roster in project.godot: it reads both, and
## connects to their signals as it comes up.

## An adventurer bought a gear tier. Carries everything a listener needs to
## narrate the sale without reading the roster back.
signal item_purchased(display_name: String, slot: String, tier: int, price: int, commission: int)


func _ready() -> void:
	# Every moment a purchase can newly become possible, and no others:
	# a shop opening (GDD: "a newly rebuilt or upgraded shop is immediately
	# available to adventurers who qualify to buy from it"), a hire arriving
	# with sponsored gold, a new day, and nightfall — which is when the
	# expedition has just paid the survivors their purses and the GDD has them
	# "head to the shops first" before bed.
	GameState.building_level_changed.connect(func(_id: String, _level: int) -> void:
		run_purchases())
	GameState.day_advanced.connect(func(_day: int) -> void: run_purchases())
	GameState.phase_changed.connect(func(new_phase: GameState.Phase) -> void:
		if new_phase == GameState.Phase.NIGHT:
			run_purchases())
	Roster.roster_changed.connect(run_purchases)


## The level of the shop selling [param slot]: 0 while it is a ruin, then
## whatever the player has paid the building up to. The rebuild buys level 1,
## which stocks tiers 1-2 with no further investment (GDD: "every rebuild
## immediately does something"), and each level bought at the building's own
## prompt opens more of the ladder — see Items.stocked_max_tier.
func shop_level(slot: String) -> int:
	var building_id: String = Items.SLOT_BUILDINGS.get(slot, "")
	if building_id.is_empty():
		return 0
	return GameState.building_level(building_id)


## The player's cut of one sale (GDD "Economy"): 10% of the vendor's revenue,
## rounded UP, minimum 1 gold. A cut, not a surcharge — the adventurer still
## pays the listed price, so this is never added to what they hand over.
##
## Note this rounds the opposite way to the tax-copy, which accumulates the
## whole expedition and floors once (Expedition.tax_copy). Ceiling per sale is
## right here for the same reason flooring per drop is wrong there: a tier 1
## item at 8 gold is 0.8, and flooring it would pay the player nothing at all
## on the purchase the whole early economy is waiting on.
func commission(price: int) -> int:
	if price <= 0:
		return 0
	return maxi(
		ceili(price * BalanceData.get_value("sales_commission_pct", 0.1)),
		int(BalanceData.get_value("sales_commission_min_gold", 1.0)))


## Runs the purchasing AI over the whole roster (BalanceNumbers "Purchasing
## AI"). Public so tests/harnesses can trigger it. Returns the number of items
## sold.
##
## The call to arms locks all town changes for the expedition (GDD), so the
## shops shut with everything else until the world returns to night — which
## also keeps this off the roster_changed that each battlefield death emits
## while the expedition is still resolving.
func run_purchases() -> int:
	if GameState.phase == GameState.Phase.CALL_TO_ARMS:
		return 0
	var sold := 0
	for member in Roster.members:
		sold += _shop_for(member)
	return sold


## Buys everything [param member] can currently afford and qualify for, in the
## AI's order. Loops because they re-evaluate after each purchase: a level 3
## adventurer at a level 1 weapon shop buys tier 1 and then upgrades straight
## into tier 2 in the same visit (BalanceNumbers "Day 1-3 sanity check").
func _shop_for(member: Dictionary) -> int:
	var gear: Dictionary = member.get("gear", {})
	if gear.is_empty():
		return 0
	var sold := 0
	# Every purchase raises a slot's tier by at least 1 and tiers cap at
	# MAX_TIER, so this cannot run past three full kits' worth of buys. The
	# bound is a structural backstop, not a rule.
	for _step in Items.SLOTS.size() * Items.MAX_TIER:
		var slot := _next_purchase(member, gear)
		if slot.is_empty():
			break
		_buy(member, gear, slot)
		sold += 1
	return sold


## The slot [param member] buys next, or "" when nothing is buyable. They
## upgrade whichever buyable slot sits at the lowest tier, ties going
## weapon -> armor -> jewelry — which is Items.SLOTS' order, so a strict
## improvement test while scanning it in order breaks the tie for free.
func _next_purchase(member: Dictionary, gear: Dictionary) -> String:
	var best := ""
	var best_tier := Items.MAX_TIER + 1
	for slot in Items.SLOTS:
		var tier: int = gear.get(slot, Items.MIN_TIER)
		if tier < best_tier and _can_buy(member, slot, tier + 1):
			best = slot
			best_tier = tier
	return best


## The GDD's triple gate on the next tier: the adventurer's level meets the
## tier's 2N-1 hero gate, that slot's shop has been rebuilt and its building
## level stocks the tier, and the adventurer can pay for it out of their own
## purse. They never save up for a tier they cannot currently afford — but a
## tier no shop stocks is not something they are saving for, it is money they
## bank until a shop opens or levels up.
func _can_buy(member: Dictionary, slot: String, tier: int) -> bool:
	if tier > Items.MAX_TIER:
		return false
	if int(member.get("level", 1)) < Items.hero_level_gate(tier):
		return false
	if tier > Items.stocked_max_tier(shop_level(slot)):
		return false
	return int(member.get("gold", 0)) >= Items.tier_cost(tier)


## Settles one sale: the adventurer pays the listed price out of their own
## purse and wears the new tier, and the player mints their commission on top.
func _buy(member: Dictionary, gear: Dictionary, slot: String) -> void:
	var tier: int = int(gear.get(slot, Items.MIN_TIER)) + 1
	var price := Items.tier_cost(tier)
	var cut := commission(price)
	member["gold"] = int(member["gold"]) - price
	gear[slot] = tier
	GameState.add_gold(cut)
	item_purchased.emit(member["name"], slot, tier, price, cut)
