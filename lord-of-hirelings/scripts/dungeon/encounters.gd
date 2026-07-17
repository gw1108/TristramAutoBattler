class_name Encounters
extends Object
## Static builder for one party's copy of a dungeon level — the spawn side of
## the dive, per BalanceNumbers "Encounters", "Enemy gold traits" and "Dungeon
## level selection (party AI)".
##
##     var fights := Encounters.build_level(1, day, rng, endless_tier)
##     fights[0]["index"]        # 1-based; fights[-1]["is_boss"] is true
##     fights[0]["enemies"][0]   # {variant, archetype, trait, gold_mult, stats}
##
## Every call rolls fresh: each party traverses an *independent* copy of its
## level — separate spawns, separate trait rolls, separate boss — so the caller
## builds one list per party and never shares one between rows.
##
## `stats` comes out of EnemyStats with the enemy's trait already folded in, so
## the battle loop can spawn a spec without knowing what a trait is; `gold_mult`
## is what the rewards layer multiplies its rolled gold by. Nothing here touches
## the scene tree, and `day` is passed in rather than read off GameState, so a
## dive is reproducible from (level, day, rng seed) alone.

const TRAIT_NONE := ""
const TRAIT_GILDED := "gilded"
const TRAIT_HOARDER := "hoarder"

## The tutorial grunt that fills every grunt slot of dungeon level 1's first
## fight and spawns nowhere else — not even in level 1's boss escort
## (BalanceNumbers "Bestiary").
const TUTORIAL_GRUNT := "slime"

## The doc's Encounters block runs at most 5 regular fights before the boss;
## fight 5 only exists from encounter_fifth_fight_min_dungeon on.
const MAX_REGULAR_FIGHTS := 5


## The whole level as an ordered fight list: the regular fights, then the boss.
## Each fight is {index (1-based), is_boss, enemies}. [param tier] is the
## expedition's endless tier, which toughens every enemy it spawns; it is 0 for
## the whole campaign up to and including the winning dive.
static func build_level(
		n: int,
		day: int,
		rng: RandomNumberGenerator,
		tier := 0) -> Array[Dictionary]:
	var level := maxi(n, 1)
	var fights: Array[Dictionary] = []
	var regular := regular_fight_count(level)
	for index in range(1, regular + 1):
		fights.append(_regular_fight(index, level, day, rng, tier))
	fights.append(_boss_fight(regular + 1, level, day, rng, tier))
	return fights


## Battles deep a dungeon level runs: 5 at levels 1-2, 6 from level 3 on.
static func fight_count(n: int) -> int:
	return regular_fight_count(n) + 1


## Regular (non-boss) fights: 4 at dungeon levels 1-2, 5 from level 3 on.
static func regular_fight_count(n: int) -> int:
	var fifth_from := int(_balance("encounter_fifth_fight_min_dungeon", 3.0))
	return MAX_REGULAR_FIGHTS if maxi(n, 1) >= fifth_from else MAX_REGULAR_FIGHTS - 1


## Grunts in regular fight [param index] at dungeon level [param n] — the doc's
## (1 + N) / (2 + N), so regular fights gain a grunt per dungeon level.
static func grunt_count(index: int, n: int) -> int:
	var base := _balance("encounter_fight%d_grunt_base" % index, 1.0)
	return maxi(0, roundi(base + _balance("encounter_grunts_per_dungeon_level", 1.0) * maxi(n, 1)))


## Casters in regular fight [param index]. Fixed at every dungeon level.
static func caster_count(index: int) -> int:
	return maxi(0, roundi(_balance("encounter_fight%d_casters" % index, 0.0)))


## Traits are suppressed on day 1 — the first expedition, where every party
## necessarily runs dungeon level 1 — so the opening dive is always trait-free
## and lands on the balance anchors (GDD). From day 2 on, every dungeon level
## rolls normally.
static func traits_suppressed(day: int) -> bool:
	return day <= 1


## What the rewards layer multiplies an enemy's rolled gold by. Traits only ever
## touch gold and the tanking needed to earn it.
static func trait_gold_multiplier(trait_id: String) -> int:
	match trait_id:
		TRAIT_GILDED:
			return roundi(_balance("enemy_trait_gilded_gold_mult", 2.0))
		TRAIT_HOARDER:
			return roundi(_balance("enemy_trait_hoarder_gold_mult", 3.0))
	return 1


## Minimum average party level dungeon level [param n] demands: 2N - 1, so
## level 1 always fits.
static func min_average_level(n: int) -> int:
	return roundi(_balance("dungeon_gate_level_per_dungeon", 2.0) * maxi(n, 1) \
			+ _balance("dungeon_gate_level_offset", -1.0))


## The party AI's pick: the hardest *unlocked* dungeon level whose minimum
## average party level the party meets. There is no upper bound — an
## over-leveled party always takes the hardest thing it can reach. Averages are
## fractional and compared as such.
static func choose_dungeon_level(party: Array, unlocked_level: int) -> int:
	var average := average_level(party)
	for n in range(maxi(unlocked_level, 1), 1, -1):
		if average >= float(min_average_level(n)):
			return n
	return 1


static func average_level(party: Array) -> float:
	if party.is_empty():
		return 0.0
	var total := 0
	for member in party:
		total += maxi(int(member.get("level", 1)), 1)
	return float(total) / float(party.size())


static func _regular_fight(
		index: int,
		level: int,
		day: int,
		rng: RandomNumberGenerator,
		tier: int) -> Dictionary:
	var enemies: Array[Dictionary] = []
	for _i in grunt_count(index, level):
		enemies.append(_spawn(_roll_grunt(index, level, rng), day, rng, tier))
	var casters := caster_count(index)
	if casters > 0:
		var caster_id := EnemyStats.variant_of(EnemyStats.CASTER, level)
		for _i in casters:
			enemies.append(_spawn(caster_id, day, rng, tier))
	return {"index": index, "is_boss": false, "enemies": enemies}


## The boss battle: boss + 1 grunt escort, at every dungeon level (it does not
## scale). The boss never rolls a trait; the escort rolls like any other grunt.
static func _boss_fight(
		index: int,
		level: int,
		day: int,
		rng: RandomNumberGenerator,
		tier: int) -> Dictionary:
	var enemies: Array[Dictionary] = []
	enemies.append(_spawn(EnemyStats.variant_of(EnemyStats.BOSS, level), day, rng, tier, false))
	for _i in maxi(0, roundi(_balance("encounter_boss_escort_grunts", 1.0))):
		enemies.append(_spawn(_roll_grunt(index, level, rng), day, rng, tier))
	return {"index": index, "is_boss": true, "enemies": enemies}


## A grunt slot is a 50/50 roll between the dungeon level's two stock grunts —
## except dungeon level 1's first fight, which always spawns only Slimes.
static func _roll_grunt(index: int, level: int, rng: RandomNumberGenerator) -> String:
	if level == 1 and index == 1:
		return TUTORIAL_GRUNT
	var pool := EnemyStats.stock_grunts(level)
	if pool.is_empty():
		push_error("Encounters: no stock grunts for dungeon level %d" % level)
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _spawn(
		variant_id: String,
		day: int,
		rng: RandomNumberGenerator,
		tier: int,
		can_roll_trait := true) -> Dictionary:
	var trait_id := _roll_trait(day, rng) if can_roll_trait else TRAIT_NONE
	var stats := EnemyStats.stats_for(variant_id)
	if stats.is_empty():
		push_error("Encounters: unknown enemy variant '%s'" % variant_id)
		return {
			"variant": variant_id,
			"archetype": "",
			"trait": trait_id,
			"gold_mult": trait_gold_multiplier(trait_id),
			"stats": stats,
		}
	# The endless tier lands BEFORE the trait: a Hoarder's +50% is taken off its
	# already tier-scaled HP and rounded again (BalanceNumbers "Endless mode").
	EnemyStats.apply_endless_tier(stats, tier)
	if trait_id == TRAIT_HOARDER:
		# Fat and slow: the trait buys the party time to earn the ×3 purse.
		stats["hp"] = float(roundi(stats["hp"] * _balance("enemy_trait_hoarder_hp_mult", 1.5)))
		stats["speed"] = stats["speed"] + _balance("enemy_trait_hoarder_speed_delta", -2.0)
	return {
		"variant": variant_id,
		"archetype": EnemyStats.archetype_of(variant_id),
		"trait": trait_id,
		"gold_mult": trait_gold_multiplier(trait_id),
		"stats": stats,
	}


## At most one trait per enemy, so it is one roll down the table — never one
## roll per trait. Bosses never get here; nor do minions, which drop no gold
## and are spawned by the battle loop rather than seeded here.
static func _roll_trait(day: int, rng: RandomNumberGenerator) -> String:
	if traits_suppressed(day):
		return TRAIT_NONE
	var roll := rng.randf()
	var gilded := _balance("enemy_trait_gilded_chance", 0.12)
	if roll < gilded:
		return TRAIT_GILDED
	if roll < gilded + _balance("enemy_trait_hoarder_chance", 0.05):
		return TRAIT_HOARDER
	return TRAIT_NONE


## BalanceData.get_value for static context — Godot 4.7 cannot resolve autoload
## identifiers inside static functions, so it is fetched through the tree
## (same shim as EnemyStats._balance).
static func _balance(id: String, default_value: float) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return default_value
	var balance := tree.root.get_node_or_null("BalanceData")
	if balance == null:
		return default_value
	return balance.get_value(id, default_value)
