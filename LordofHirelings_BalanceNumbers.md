# Lord of Hirelings — Balance Numbers (First Draft)

These numbers are a first draft authored to satisfy the anchor points in the game design document. They are expected to change through playtesting. When a number here conflicts with the GDD, the GDD wins.

## Anchor points (from the GDD)

1. A level 1 Mage deals 1-3 AOE damage (med-low to med-high damage output).
2. A Captain survives 6-7 attacks (dodging some of them) from the very first level 1 enemy encounter.
3. The very first enemy killed awards 1 XP to each living party member.

## Core rules used by these numbers

- Damage roll: uniform integer in [power - 1, power + 1], minimum 1, rolled before armor. Armor subtracts flat damage from the roll (minimum 1 damage on a landed hit).
- Rounding: whenever a rule produces a fractional HP, morale, XP, gold, or stat value, round to the nearest integer with exact halves rounded up, unless that rule explicitly says to floor or ceil instead.
- Chance to hit: `AA * 1.25 * 100 / (AA + DE * 0.3)`, clamped to [5%, 100%] (per the GDD).
- Crit: all or nothing — the whole attack either crits or it does not, multiplying the damage roll by (1 + crit damage bonus) before armor. An AOE attack rolls damage and crit **once** and applies that single result against every target; each target still resolves accuracy, guard, the crit-downgrade evasion check, and armor individually. Only an attack that explicitly fires multiple projectiles rolls damage and crit per projectile — no current ability does; the rule exists for future content. A crit must also beat evasion twice: if the attack crits and the defender failed the first evasion check, a second evasion check is rolled at the same odds — success downgrades the hit to non-critical (it still lands, just without the crit bonus).
- Guard: a blocked attack deals 0 HP damage but full morale damage. Guard is checked before the crit roll, so a blocked attack never rolls a crit at all. All enemies have 0% guard and 0% crit, so blocking and critting are adventurer-side mechanics in practice.
- Resolution order for an attack: accuracy check → guard check → crit roll → (on crit) second evasion check, which on success downgrades the crit to a normal hit → armor subtraction.
- Adventurer attacks deal no morale damage; enemies are immune to morale, so player-side morale damage is not a hero stat. Enemy attacks use the morale-damage values in the enemy table.
- Morale damage: an enemy's listed morale damage is applied on every landed (non-evaded) hit, including blocked ones.
- When a party member dies, each surviving party member takes 2 morale damage.
- HP regen and morale regen apply at the end of each battle (not per turn).
- Adventurers heal to full HP and full morale whenever they are outside the dungeon, so every expedition begins with the whole roster fresh. Regen only matters between battles within a single dive.
- All equipment and all personal gold carried by an adventurer is destroyed when they die. Fleeing adventurers keep everything.
- Stats are frozen for the duration of a dive. XP accrues during the dungeon but every level-up is applied at the expedition summary, so a party's numbers never change mid-expedition.

## Turn pacing

Every character's turn takes a fixed **0.6 seconds** of animation, whatever they do with it — attack, heal, cower, or Rallying Horn. Walking takes 4 seconds when a party first enters the level and again between each fight, so a 5-battle dungeon level is 5 walks (one on entry, four between fights) = 20 seconds of walking.

Estimated battle lengths at 0.6s per turn. **These are derived from the stat tables, not measured — confirm them in playtest before treating them as targets:**

| Battle | Characters | Est. rounds | Est. length |
|--------|-----------|-------------|-------------|
| Dungeon 1, battle 1 (3 heroes vs 2 grunts, 16 enemy HP) | 5 | ~2-3 | ~6-9s |
| A genuinely even, low-DPS matchup (the GDD's anchor) | 6 | ~7 | ~25s |
| Dungeon 4 boss (3 level-7 heroes vs Demon Prince + escort, 135 enemy HP) | 5 | ~6-12 | ~18-36s |

The GDD's pacing intent — "about 15 seconds when the two sides are very evenly matched and low-DPS" — falls between the first two rows, so 0.6s brackets the anchor rather than hitting it exactly. Tune the constant once real battles can be measured.

A full dungeon level 1 clear is therefore roughly 45s of fighting plus 20s of walking ≈ **65 seconds**. All three rows run concurrently in real time, so a dive lasts as long as its slowest row, not the sum of the three.

The late game does not blow up the way the boss's 102 HP might suggest: only 5 characters are in that fight, and a level 7 party out-damages 135 combined enemy HP fast enough that the climax still runs comfortably under a minute. There is no speed control and at these lengths none is needed — the Horn of Retreat stays the player's only input during a dive. If playtesting says dives drag, turn duration is the single lever: dropping to 0.4s scales every number above by two-thirds.

## Initiative

Turn order is re-rolled at the start of every round: each character rolls `d20 + speed`, and the highest total acts first. Every character acts exactly once per round regardless of speed — speed biases the order, it does not grant extra turns. A Rogue (speed 7) beats a Knight (speed 3) on initiative 66% of the time outright, plus a 4% chance of an exact tie that the Rogue also wins under tiebreak rule 1 (higher speed stat) — 70% all told. So the 3-7 spread is a firm bias but not a guarantee.

Ties are broken in this order, stopping at the first rule that separates them:

1. Higher speed stat goes first.
2. Enemy goes before the player's character.
3. More buff/debuff abilities goes first.
4. More damage/power goes first.
5. Random.

## Ability cadence

**Every ability is per battle unless it explicitly says otherwise.** An ability that fires "every Nth turn" counts that character's own turns within the current battle, and the counter resets to 0 when a new battle starts. Practical consequences:

- The Captain always opens a battle with two normal attacks, then Rallying Horn on his third turn, then repeats — every battle, regardless of what he did in the previous one.
- The Demon Prince always opens with two normal attacks before his first Eruption.
- The Lich's Raise Dead ("the first time it drops below 50% HP") re-arms at the start of each battle. In practice it only ever appears in one battle, so this is a formality.
- The Knight's Shield Bash guard doubling lasts until his next turn and does not carry across battles.
- The Berserker's Frenzy is a continuous passive, evaluated at the moment of each attack, and has no counter at all.

## Status effects

Every buff and debuff has a duration measured in the affected character's turns. Decrement its duration by 1 at the end of that character's turn, including a cower turn; remove it when it reaches 0. Each effect also defines one of three stacking modes: separate instances stack; a single instance increases in magnitude; or reapplying the effect does not stack and only refreshes its duration.

## Combat event order

1. At the start of a round, roll initiative for every living combatant already in the battle.
2. Resolve those turns in initiative order. A combatant that dies or flees before its turn skips it; a summoned minion enters immediately but waits until the next round to act.
3. On a landed attack, apply HP damage, then resolve immediate effects. Lifesteal restores the actual HP damage dealt, capped at the attacker's max HP. The Lich's Raise Dead triggers immediately only if it crossed below half HP and remains alive after the damage. A death immediately deals 2 morale damage to each surviving party member; fleeing does not.
4. At the end of the round, resolve enemy end-of-round effects (such as Swamp Troll regeneration), then evaluate the party's zero-damage stalemate counter.

## Morale, panic, and cowering

Only the player's adventurers can panic. Enemies deal morale damage but are immune to it and never flee.

At the start of an adventurer's turn, if `m = current morale / max morale` is below 0.5, roll a panic check:

```
panic chance = clamp((0.5 - m) * 2, 0, 1)
```

If the panic check succeeds, roll a second check at the same odds. Success on the second roll means the adventurer **flees**; failure means they **cower**. Effective flee chance per turn is therefore `panic chance²`.

| Morale | m | Panic chance | Flee | Cower | Acts normally |
|--------|------|--------------|------|-------|---------------|
| 100%   | 1.00 | 0%           | 0%   | 0%    | 100%          |
| 50%    | 0.50 | 0%           | 0%   | 0%    | 100%          |
| 40%    | 0.40 | 20%          | 4%   | 16%   | 80%           |
| 25%    | 0.25 | 50%          | 25%  | 25%   | 50%           |
| 10%    | 0.10 | 80%          | 64%  | 16%   | 20%           |
| 0%     | 0.00 | 100%         | 100% | 0%    | 0%            |

This preserves the GDD's original "morale 0 = flee" rule as the limit case, while making cowering dominate the mid-low band and fleeing take over near the bottom.

**Cowering**: the adventurer skips their turn, then restores 20% of their **max** morale afterward. (20% of *current* morale would round to nothing exactly when it is needed, so it is keyed to max.) A cowering adventurer at 25% morale returns to 45% and is back to a 10% panic chance next turn — low morale is a spiral the party can pull out of, not an automatic loss.

Note that the check happens on the adventurer's turn, so an adventurer reduced to 0 morale can still be killed before they ever get to flee.

## Stalemate rule

Each party tracks a counter of consecutive rounds in which it dealt zero damage. At **3** consecutive zero-damage rounds the entire party flees regardless of morale. (Tunable 2-3; starting at 3.)

- The counter resets to 0 the moment any party member deals ≥1 damage.
- It measures damage *dealt*, not the enemy's net health change — if the party is landing hits but the enemy out-heals them, the counter resets and the rule does not fire.
- Misses and fully-guarded attacks count as zero damage.

This is what stops a lone Cleric or an all-Cleric party — which has no attack at all — from locking a battle forever.

## Adventurer base stats (level 1)

| Class     | HP | HP Regen | Power   | Speed | Armor | Guard % | Evasion | Accuracy | Crit % | Crit Dmg | Max Morale | Morale Regen |
|-----------|----|----------|---------|-------|-------|---------|---------|----------|--------|----------|------------|--------------|
| Knight    | 14 | 1        | 2       | 3     | 2     | 25%     | 120     | 100      | 5%     | 50%      | 12         | 1            |
| Captain   | 12 | 1        | 3       | 4     | 1     | 10%     | 150     | 100      | 5%     | 50%      | 12         | 2            |
| Berserker | 12 | 1        | 5       | 5     | 0     | 0%      | 100     | 100      | 15%    | 50%      | 10         | 1            |
| Mage      | 6  | 0        | 2 (AOE) | 4     | 0     | 0%      | 80      | 110      | 5%     | 50%      | 8          | 1            |
| Rogue     | 10 | 0        | 4       | 7     | 0     | 5%      | 180     | 110      | 20%    | 75%      | 9          | 1            |
| Cleric    | 10 | 1        | 2 (heal)| 6     | 1     | 10%     | 110     | 100      | 0%     | —        | 11         | 2            |

The Cleric's power is **2, not 0**. It has no attack, so its power never produces a damage roll; instead it sizes the Cleric's heal (see Class abilities). This is what makes a Cleric's weapon, Sharper Steel, and Sparring Dummies real purchases for it rather than dead gold, and it is what keeps the class from falling off a cliff by dungeon level 3.

## Anchor verification

- Captain: 12 HP, 1 armor, 150 evasion. Level 1 grunt: 100 accuracy, 3 power. Hit chance vs Captain = 12500 / (100 + 45) ≈ 86%. Average landed hit = 3 - 1 armor = 2 damage. Landed hits to kill = 12 / 2 = 6. Expected attacks = 6 / 0.86 ≈ 7. → survives 6-7 attacks, dodging some. ✔ (The Captain's 10% guard is ignored here; counting it pushes the expectation to ~7.7 attacks, slightly over the anchor. Drop Captain guard to 0% if the anchor needs to be exact.)
- Mage: power 2, damage roll 2 ± 1 = 1-3, hits all enemies in the battle. ✔
- Cleric: power 2 → heal 3, exactly matching the flat 3 this draft previously specified. ✔

## Class abilities (first draft)

- Knight — Shield Bash: single target attack; after attacking, his total guard chance (including gear and upgrades) is doubled and capped at 75% through the end of his next turn (his "defensively attack"). This effect does not stack; reapplication refreshes its duration.
- Captain — Attack normally; every 3rd turn uses Rallying Horn instead: restores 2 morale to every living party member and grants them +1 power on their next attack. The power buff lasts through the recipient's next turn if unconsumed; Horn power is one shared stacking instance, so repeated Horns increase its magnitude and refresh that duration.
- Berserker — Attack normally; passive Frenzy: +1 power while below 50% HP.
- Mage — AOE bolt: hits every enemy in the battle. Damage and crit are rolled once for the whole volley and applied against every enemy; each enemy still resolves its own evasion, crit-downgrade check, and armor (the standard AOE rule — the bolt is not a multi-projectile attack).
- Rogue — Attack normally; relies on high crit chance and crit damage.
- Cleric — Heal: restores **power + 1** HP to the lowest-HP living ally (the Cleric itself is a valid target), capped at that ally's max HP. The heal is deterministic — it does not roll ±1 like a damage roll, and it cannot crit (the Cleric's crit chance is 0%). If multiple allies tie for lowest HP, select uniformly among them. If all allies are at full HP, casts Blessing instead: +1 armor to a random ally for 3 of that ally's turns. Blessing does not stack; reapplying it refreshes its duration.

Targeting for single-target attacks (both sides): pick a random living enemy, uniformly. Buff/debuff-ability counts used for initiative tiebreak rule 3: Captain 1, Cleric 1, Knight 1, all others 0.

**Cleric heal scaling.** Heal = power + 1 means the Cleric rides the same curve everything else does:

| Cleric state | Power | Heal |
|--------------|-------|------|
| Level 1, tier 0 weapon | 2 | 3 |
| Level 5, tier 3 weapon | 4 + 3 = 7 | 8 |
| Level 9, tier 5 weapon | 6 + 6 = 12 | 13 |
| Level 9, tier 5 weapon, Sharper Steel maxed | 12 + 5 = 17 | 18 |
| Level 9, tier 5 weapon, Sharper Steel + Sparring Dummies maxed | 17 + 5 = 22 | 23 |

For reference, a dungeon level 4 grunt hits for 8-10 and the Demon Prince for 10-12. So a fully-invested Cleric heals roughly two enemy hits per turn against one target, while the party is typically absorbing five or six enemy hits per round. That is the intended shape — the Cleric extends a fight, it does not win one alone (the stalemate rule guarantees that). **Tuning note:** the top of this table is the number to watch. If a maxed Cleric is trivializing dungeon level 4, cut the heal to `power` rather than `power + 1` and give the Cleric base power 3 to hold the level 1 anchor.

## Adventurer growth per level

- +2 HP (Knight +3)
- +1 power every 2 levels (on even levels)
- +12 evasion, +12 accuracy
- +1 max morale every 2 levels (on odd levels after 1)
- XP required to reach the next level: `8 * current level` (level 1→2: 8 XP, 2→3: 16 XP, 3→4: 24 XP, ...)
- No level cap.

All of this is applied at the expedition summary, never mid-dive. An adventurer can gain several levels at once (a single dungeon level 1 clear is worth nearly two), so the summary's XP bar animation must loop rather than assuming a single level-up.

## Displaying evasion and accuracy as percentages

Evasion and accuracy are raw ratings. To show either as a percentage the UI needs the other side of the hit formula, so it substitutes a **reference grunt** — the most common enemy in the game — drawn from the dungeon level that adventurer would actually be sent to:

```
R = clamp(floor((L + 1) / 2), 1, 4)          # reference dungeon level for an adventurer of level L
ref_accuracy(R) = 40R + 60
ref_evasion(R)  = 40R + 20

displayed_accuracy% = clamp(A * 1.25 * 100 / (A + ref_evasion(R) * 0.3), 5, 100)
displayed_evasion%  = 100 - clamp(ref_accuracy(R) * 1.25 * 100 / (ref_accuracy(R) + E * 0.3), 5, 100)
```

where A and E are that adventurer's own total accuracy and evasion ratings.

R is the inverse of the 2N-1 party gate, so it always names the dungeon level that adventurer's party is actually eligible for: level 1 → dungeon 1, level 3 → dungeon 2, level 5 → dungeon 3, level 7+ → dungeon 4. The clamp at 4 is what keeps the readout meaningful for level 20 adventurers in endless mode, and endless tiers do not touch evasion or accuracy (only HP and power), so no endless adjustment is needed.

Level 1 values this produces, against ref_accuracy(1) = 100 and ref_evasion(1) = 60:

| Class | Evasion rating | Displayed Evasion | Accuracy rating | Displayed Accuracy |
|-------|----------------|-------------------|-----------------|--------------------|
| Knight    | 120 | 8%  | 100 | 100% |
| Captain   | 150 | 14% | 100 | 100% |
| Berserker | 100 | 4%  | 100 | 100% |
| Mage      | 80  | 0%  | 110 | 100% |
| Rogue     | 180 | 19% | 110 | 100% |
| Cleric    | 110 | 6%  | 100 | 100% |

The Captain's 14% is the same 86% hit chance the anchor verification derives, so the display and the sim agree.

**Two things to expect from this and not treat as bugs.** Displayed accuracy is pegged at 100% for the entire early game: the formula's 1.25 multiplier means accuracy only drops below 100% once the reference enemy's evasion exceeds roughly 0.83× the attacker's accuracy rating, and a level 1 grunt's evasion of 60 is nowhere near a hero's 100. And a level 1 Mage genuinely displays 0% evasion, because a grunt hits it every time. Both are truthful readouts of the existing hit formula rather than display errors. If a wall of 100%s feels bad, the fix is in the hit formula's constants, not in the display rule.

**Note for the mockups:** `mockups/hero-panel.html` and `mockups/party-formation.html` previously showed hand-invented percentages (43% / 24% / 21% / 96%) that did not come from this formula and were non-monotonic in the underlying rating. They have been corrected to match the table above. If a mockup ever disagrees with this table again, the table is right.

## Equipment

Every adventurer has **three** slots: **Weapon** (offense), **Armor** (defense), and **Jewelry** (class-dependent). Everyone arrives wearing tier 0 in all three, which is free and grants nothing. Each slot is sold by its own separate building — the weapon shop, the armor shop, and the jewelry shop — and bought with the adventurer's own personal gold.

**Tier gating is identical in all three shops, and the building level is the only thing that does it.** A level 1 shop stocks tiers 1-2, a level 2 shop adds tiers 3-4, a level 3 shop adds tier 5. Levels 4 and 5 unlock that shop's two shop-wide lines instead of tiers. The old "Unlock Equipment Tier" pip line is gone — it duplicated this job and left building levels doing nothing at all.

| Tier | Cost | Requires hero level | Requires that shop's level |
|------|------|---------------------|----------------------------|
| 0    | —    | 1                   | —                          |
| 1    | 8    | 1                   | 1                          |
| 2    | 16   | 3                   | 1                          |
| 3    | 32   | 5                   | 2                          |
| 4    | 64   | 7                   | 2                          |
| 5    | 128  | 9                   | 3                          |

The hero level gate is `2N - 1` for tier N, deliberately mirroring the dungeon level gate so gear and depth advance together. The same cost and gate table applies to all three slots, so a full tier 5 kit is 3 × (8+16+32+64+128) = **744 gold** per adventurer.

### Weapon grants

A weapon raises **power**, which drives the damage roll — and for the Cleric, whose power sizes its heal instead, drives healing. The Knight and the Captain are the tanky classes and fight behind a shield or a guarded polearm, so their weapons additionally grant armor:

| Tier | Power (all classes) | Armor (Knight & Captain only) |
|------|---------------------|-------------------------------|
| 0 | +0 | +0 |
| 1 | +1 | +0 |
| 2 | +2 | +1 |
| 3 | +3 | +1 |
| 4 | +4 | +2 |
| 5 | +6 | +2 |

The Knight and Captain have the two lowest base powers of the melee classes (2 and 3, against the Berserker's 5 and the Rogue's 4), so the extra armor is what their weapon buys instead of the damage the others get.

### Armor grants

Uniform across all classes:

| Tier | Grants |
|------|--------|
| 0 | +0 |
| 1 | +1 armor |
| 2 | +1 armor, +5% guard |
| 3 | +2 armor, +5% guard |
| 4 | +2 armor, +10% guard |
| 5 | +3 armor, +15% guard |

### Jewelry grants

Jewelry is the class-dependent slot: instead of giving everyone the same stat, it amplifies whatever that class already wants to be doing. This is the slot that makes a Rogue more of a Rogue.

| Class | Type | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|-------|------|--------|--------|--------|--------|--------|
| Knight | Belt | +3% guard | +6% | +9% | +12% | +18% |
| Captain | Amulet | Rallying Horn restores +1 extra morale | +2 | +3 | +4 | +6 |
| Berserker | Ring | +10% crit damage | +20% | +30% | +40% | +60% |
| Mage | Amulet | +1 power | +2 | +3 | +4 | +6 |
| Rogue | Ring | +3% crit chance | +6% | +9% | +12% | +18% |
| Cleric | Amulet | Heal also restores +1 morale to its target | +2 | +3 | +4 | +6 |

The Captain's amulet additionally raises the Rallying Horn's power buff by +0/+1/+1/+2/+2 by tier (the same curve as the tanky weapon armor). A tier 5 Captain's Horn therefore restores 8 morale to the party and grants +3 power, rather than 2 and +1.

Two notes. The **Mage's amulet deliberately duplicates its weapon** (both are +power) — the Mage's whole identity is AOE damage, and "amplify what the class already does" points straight back at power. It is the one class whose jewelry is not mechanically distinct, and if that reads as a missed opportunity in playtest, +crit chance is the obvious swap — though note that since an AOE rolls one crit for the whole volley, a Mage crit is now an all-targets-at-once spike rather than a per-target lottery. The **Cleric's amulet is deliberately not power** — its weapon already scales the heal, so its amulet adds a second axis (morale) rather than doubling the first.

Ceiling check, at level 9 with a full tier 5 kit and every relevant shop-wide line maxed: Knight guard = 25 base + 15 armor + 10 Reinforced Straps + 18 belt = **68%**, under the 75% guard cap — and a Shield Bash's doubling slams into that cap, so a fully-kitted post-Bash Knight blocks at exactly 75%, not 136%. The cap is what keeps the Knight tanky rather than untouchable. Rogue crit = 20 + 18 ring + 10 Keen Edge = **48%**. Berserker crit damage = 50 + 60 = **110%**, i.e. a 2.1× hit. None of these break their caps, but the Mage's ceiling is worth watching: 2 base + 4 levels + 6 weapon + 6 amulet + 5 Sharper Steel + 5 Sparring Dummies = **28 AOE power**, which roughly one-shots a dungeon 4 caster (20 HP) on every target. That is the intended late-game power fantasy, but it is the first number to cut if level 4 collapses.

**Purchasing AI**: when an adventurer is in town and can afford the next tier they qualify for, they walk to the relevant shop and buy it outright. A tier is buyable only if the adventurer's level meets its hero gate, **that slot's shop has been rebuilt**, and its building level stocks the tier. They upgrade whichever buyable slot is currently at the lowest tier, breaking ties in the order weapon → armor → jewelry. They never save up across days for a tier they cannot currently afford — if they can afford something, they buy it. Because the Cleric's power now drives its heal, "tie goes to the weapon" is no longer a trap for Clerics. Note the shape this gives the early game: if only the weapon shop is rebuilt, the other two slots stay at tier 0 and every adventurer sinks what they can into weapons and nothing else. "What they can" is bounded by the shop's own level, not by their purse — a level 1 shop stocks only tiers 1-2, which is 24 gold of spending, so a rich adventurer buys those two and banks the rest until another shop opens or this one levels up. The player's choice of which shop to rebuild first is therefore a choice about what their whole roster becomes, and their choice of whether to level that shop or rebuild the next one is a choice about how deep versus how broad the roster gets.

### Shop-wide gear lines

Each shop's levels 4 and 5 unlock two lines that apply to every adventurer in town at once, but only to gear of tier 1 or higher in that shop's slot. The split is thematic — weapons are offense, armor is defense, jewelry is morale:

| Shop | Level 4 line | Level 5 line |
|------|--------------|--------------|
| Weapon | **Sharper Steel** — +1 power per pip, max +5 | **Keen Edge** — +2% crit chance per pip, max +10% |
| Armor | **Thicker Plate** — +1 armor per pip, max +5 | **Reinforced Straps** — +2% guard per pip, max +10% |
| Jewelry | **Warding Charms** — +2 max morale per pip, max +10 | **Soothing Stones** — +1 morale regen per pip, max +5 |

These six lines are intentionally the strongest and most expensive thing in the game — a maxed Sharper Steel is worth more than a tier 5 weapon and benefits the entire roster, which is the payoff for investing in the town rather than in individuals. Gating them behind each shop's last two building levels puts them where that payoff belongs: reaching any level 4 line costs 390 gold of building (40 + 100 + 250) on top of that shop's rebuild, and the level 5 line another 625, so they are a late-game commitment rather than a 9 gold day-3 impulse buy. Buying out all six lines across all three shops is 3,045 gold in building levels — 3 × (390 + 625) — on top of 1,200 in pips, and that is before the 10 gold rebuilds and the tier-access levels the shops needed to get there (the town table below lists each shop's full rebuild + levels as 1,025).

## Item names

Equipment is named per class, per slot, per tier — 6 classes × 3 slots × 6 tiers = 108 names. Tier 0 has names too, because the inventory list always shows all three slots. Each class's jewelry is a fixed type: the Knight wears a belt, the Berserker and Rogue wear rings, and the Captain, Mage, and Cleric wear amulets.

**Knight** — jewelry type: Belt

| Tier | Weapon | Armor | Jewelry |
|------|--------|-------|---------|
| 0 | Rusted Longsword | Dented Hauberk | Frayed Sword-Belt |
| 1 | Squire's Longsword | Studded Brigandine | Squire's Belt |
| 2 | Tempered Broadsword | Tempered Mail | Tempered Warbelt |
| 3 | Knightly Bastard Sword | Knight's Plate | Knight's Girdle |
| 4 | Oathkeeper Greatsword | Bulwark Plate | Bulwark Cincture |
| 5 | Dawnbreaker | Aegis of the Unbroken | Girdle of the Unbroken |

**Captain** — jewelry type: Amulet

| Tier | Weapon | Armor | Jewelry |
|------|--------|-------|---------|
| 0 | Cracked Spear | Frayed Gambeson | Tarnished Whistle |
| 1 | Footman's Spear | Ranger's Leathers | Footman's Medallion |
| 2 | Sergeant's Halberd | Officer's Coat | Sergeant's Torc |
| 3 | Banner Pike | Captain's Cuirass | Banner-Bearer's Amulet |
| 4 | Warlord's Glaive | Warden's Harness | Warlord's Gorget |
| 5 | Standard of the Last Charge | Mantle of the Rallying Cry | Voice of the Last Charge |

**Berserker** — jewelry type: Ring

| Tier | Weapon | Armor | Jewelry |
|------|--------|-------|---------|
| 0 | Chipped Axe | Torn Furs | Bent Iron Ring |
| 1 | Woodsman's Axe | Wolfhide Wrap | Woodsman's Band |
| 2 | Twin Hatchets | Bonecarved Harness | Bonecarved Ring |
| 3 | Butcher's Cleavers | Warpainted Plate | Butcher's Signet |
| 4 | Skullsplitter Maul | Berserker's Girdle | Skullsplitter Band |
| 5 | Ruin, the Red Claymore | Hide of the Unkilled | Ring of Red Ruin |

**Mage** — jewelry type: Amulet

| Tier | Weapon | Armor | Jewelry |
|------|--------|-------|---------|
| 0 | Splintered Wand | Moth-Eaten Robes | Clouded Bead |
| 1 | Apprentice's Rod | Apprentice's Robes | Apprentice's Pendant |
| 2 | Emberwood Staff | Warded Vestments | Emberwood Charm |
| 3 | Stormglass Staff | Runewoven Robes | Stormglass Pendant |
| 4 | Archmage's Focus | Archmage's Regalia | Archmage's Sigil |
| 5 | Cataclysm | Shroud of the Ninth Circle | Heart of Cataclysm |

**Rogue** — jewelry type: Ring

| Tier | Weapon | Armor | Jewelry |
|------|--------|-------|---------|
| 0 | Notched Knife | Patchwork Cloak | Bent Copper Ring |
| 1 | Cutpurse's Dagger | Cutpurse's Leathers | Cutpurse's Band |
| 2 | Paired Stilettos | Shadowed Jerkin | Shadowed Signet |
| 3 | Duelist's Rapier | Duelist's Half-Cloak | Duelist's Ring |
| 4 | Venomfang Blades | Nightstalker's Leathers | Venomfang Band |
| 5 | Quietus | Veil of the Unseen | Ring of the Unseen |

**Cleric** — jewelry type: Amulet

| Tier | Weapon | Armor | Jewelry |
|------|--------|-------|---------|
| 0 | Cracked Censer | Threadbare Habit | Cracked Prayer-Bead |
| 1 | Acolyte's Mace | Acolyte's Vestments | Acolyte's Pendant |
| 2 | Blessed Censer | Blessed Chainmail | Blessed Icon |
| 3 | Reliquary Mace | Reliquary Plate | Reliquary Pendant |
| 4 | Bishop's Scepter | Bishop's Raiment | Bishop's Chain |
| 5 | Hand of the Radiant | Raiment of the Undimmed | Heart of the Radiant |

## Name generation

An adventurer's display name is `<first name> <epithet>` — e.g. "Aldric the Unyielding". Both are rolled uniformly and independently from the lists below. The pair must be unique across everything the player can currently see referenced: hired adventurers, hireable recruits standing at the inn, and the names carved on the graveyard's 12 headstones. On a collision, reroll.

**First names (40)**

Aldric, Bram, Cassia, Corvin, Dain, Ede, Elowen, Faron, Greta, Grom, Hale, Hestia, Ilsa, Jorund, Kesta, Lorne, Mabel, Marrow, Morwen, Nix, Orrin, Oswin, Perrin, Piety, Quill, Rook, Roswald, Rulf, Sable, Sela, Tamsin, Torvald, Ulric, Umbra, Vanya, Vex, Wren, Wystan, Yorick, Zeta

**Epithets (40)**

the Unyielding, the Ashen, the Wailing, the Grey, the Kind, the Bitter, the Bright, the Cracked, the Dour, the Eager, the Fond, the Gilded, the Hollow, the Ill-Starred, the Jaded, the Keen, the Lost, the Meek, the Nameless, the Owed, the Patient, the Quiet, the Ruined, the Sour, the Thrice-Buried, the Unfinished, the Vain, the Weary, the Younger, the Zealous, the Rope-Necked, the Half-Drowned, the Second-Best, the Unpaid, the Coin-Bitten, the Late, the Sleepless, the Stubborn, the Fortunate, the Overdue

40 × 40 = 1,600 combinations. A full 31-day run at maxed Hero Capacity generates on the order of 250 recruits, so collisions are uncommon and the reroll almost never fires more than once.

## Enemies

An enemy's level equals the dungeon level it appears on. Each dungeon level's roster is themed to its biome; every enemy is one of three stat archetypes (grunt, caster, boss) with small per-variant tweaks listed in the bestiary below.

### Archetype formulas (valid for any level N)

Every archetype stat extrapolates from a closed-form formula, so a reference enemy exists at every level even though the game only ships four dungeon levels. This is what lets the hero panel's evasion/accuracy display and any future content work without hardcoded tables.

```
                     Grunt                 Caster                Boss
HP           round(8  * 1.6^(N-1))  round(5 * 1.6^(N-1))  round(25 * 1.6^(N-1))
Power        3 + 2(N-1)             2 + 2(N-1)  (AOE)     5 + 2(N-1)
Speed        4                      3                     4
Armor        0                      0                     N
Evasion      40N + 20               40N + 10              40N + 40
Accuracy     40N + 60               40N + 60              40N + 70
Morale Dmg   N                      N                     N + 1
```

All archetypes have **0% guard and 0% crit chance** — blocking and critical hits are adventurer-side mechanics.

### Stats

| Enemy    | Dungeon | HP | Power   | Speed | Armor | Evasion | Accuracy | Morale Dmg |
|----------|---------|----|---------|-------|-------|---------|----------|------------|
| Grunt    | 1       | 8  | 3       | 4     | 0     | 60      | 100      | 1          |
| Caster   | 1       | 5  | 2 (AOE) | 3     | 0     | 50      | 100      | 1          |
| Boss 1   | 1       | 25 | 5       | 4     | 1     | 80      | 110      | 2          |
| Grunt    | 2       | 13 | 5       | 4     | 0     | 100     | 140      | 2          |
| Caster   | 2       | 8  | 4 (AOE) | 3     | 0     | 90      | 140      | 2          |
| Boss 2   | 2       | 40 | 7       | 4     | 2     | 120     | 150      | 3          |
| Grunt    | 3       | 20 | 7       | 4     | 0     | 140     | 180      | 3          |
| Caster   | 3       | 13 | 6 (AOE) | 3     | 0     | 130     | 180      | 3          |
| Boss 3   | 3       | 64 | 9       | 4     | 3     | 160     | 190      | 4          |
| Grunt    | 4       | 33 | 9       | 4     | 0     | 180     | 220      | 4          |
| Caster   | 4       | 20 | 8 (AOE) | 3     | 0     | 170     | 220      | 4          |
| Boss 4   | 4       | 102 | 11     | 4     | 4     | 200     | 230      | 5          |

This table is now generated by the formulas above rather than hand-written, which corrected two cells from the previous draft: dungeon 4 grunt HP 32 → 33, and dungeon 4 caster HP 21 → 20. Both were arithmetic slips of ±1 HP in the original hand-computation; the formula is the source of truth.

### Bestiary

Variant tweaks are relative to that dungeon level's archetype row above. Each level has two stock grunt variants; which one spawns in a grunt slot (including the boss's escort) is a 50/50 roll. Level 1 additionally has the Slime, a tutorial grunt outside that pool: the first fight of dungeon level 1 always spawns only Slimes, and Slimes appear in no other slot. Boss signatures are deliberately one simple flag each — no new resource systems. Undead and demons are flavor on the same math; all enemies remain immune to morale damage. The four dungeon levels are data-driven from this bestiary; the archetype formulas above are what generalize.

**Level 1 — Gentle Forest (beasts and bandits)**
- Slime (grunt): -3 HP, -1 power, -1 speed. Tutorial enemy — fills both grunt slots of dungeon level 1's first fight and spawns nowhere else; green or blue at 50/50, purely cosmetic. Rewards are the stock level 1 grunt row, so the Encounters totals below are unchanged. A Slime that rolls the Gilded trait is the **Golden Slime** — standard ×2 gold, rendered by the Gilded gold shader; day-1 trait suppression plus only two Slime slots per run keep it a rare jackpot sighting.
- Wolf (grunt): -1 HP, +2 speed.
- Bandit (grunt): stock grunt.
- Hedge Witch (caster): stock caster.
- **Bandit King** (boss): Cheap Shot — his attacks ignore armor.

**Level 2 — Swamp**
- Lizardfolk Raider (grunt): stock grunt.
- Giant Leech (grunt): +2 HP, -2 speed; heals itself for the HP damage it deals (lifesteal).
- Bog Witch (caster): stock caster.
- **Swamp Troll** (boss): Regeneration — restores 3 HP at the end of every round. A party that cannot out-damage the regen gets pushed out by the stalemate rule.

**Level 3 — Undead Crypt**
- Skeleton Warrior (grunt): stock grunt.
- Zombie (grunt): +6 HP, -2 speed.
- Necromancer (caster): stock caster.
- **The Lich** (boss): Raise Dead — the first time it drops below 50% HP, it raises 2 Skeleton Warriors into the battle. The raised skeletons carry the **minion** tag (see Minions under Rewards): they drop no gold, award half XP, and award nothing on a repeat summon.

**Level 4 — Volcanic Hellscape (demons)**
- Imp (grunt): -6 HP, +2 speed.
- Demon Soldier (grunt): stock grunt.
- Flamecaller (caster): stock caster.
- **Demon Prince** (boss): Eruption — every 3rd turn his attack hits the entire party instead of a single target. Standard AOE rule: one damage roll applied against every party member, each of whom resolves their own evasion, guard, and armor (and enemies cannot crit).

### Rewards

XP and gold are awarded **to each living party member individually** — not split. A grunt killed by a party of 3 gives 1 XP and a 0-2 gold roll to each of the three, rolled separately. Dead members get nothing; members who fled keep whatever they banked before fleeing — explicitly including all XP from enemies defeated before they fled.

| Enemy  | Dungeon | Gold (per living member) | XP (per living member) |
|--------|---------|--------------------------|------------------------|
| Grunt  | 1       | 0-2                      | 1                      |
| Caster | 1       | 0-2                      | 2                      |
| Boss 1 | 1       | 5-10                     | 6                      |
| Grunt  | 2       | 0-4                      | 2                      |
| Caster | 2       | 0-4                      | 4                      |
| Boss 2 | 2       | 10-20                    | 11                     |
| Grunt  | 3       | 2-9                      | 3                      |
| Caster | 3       | 2-9                      | 6                      |
| Boss 3 | 3       | 22-45                    | 19                     |
| Grunt  | 4       | 4-17                     | 6                      |
| Caster | 4       | 4-17                     | 12                     |
| Boss 4 | 4       | 42-85                    | 35                     |

General formulas, for reference and for any future dungeon levels:

```
gold_min(N) = max(0, 2 * (N - 2))
gold_max(N) = (3N² - 5N + 6) / 2        →  N=1: 2, N=2: 4, N=3: 9, N=4: 17, N=5: 28
boss_gold(N) = 2.5 * gold_max(N)  to  5 * gold_max(N)
xp(N) = round(base_xp * 1.8^(N-1))      →  grunt base 1, caster base 2, boss base 6
```

The gold formula is fitted exactly to the GDD's stated anchors of 0-2 / 0-4 / 2-9.

### Minions

A summoned enemy carries the **minion** tag. Minions:

- **never drop gold** (and therefore never roll gold traits and contribute nothing to the tax-copy);
- award XP at a **50% penalty, rounded down** — a dungeon 3 Skeleton Warrior minion awards 1 XP per living member instead of 3;
- only pay XP **once per summon, per expedition**: if the summoner's ability fires again after its minions have already been defeated that expedition, the re-summoned minions award no XP at all.

Since Raise Dead re-arms per battle but the Lich only ever appears in its one boss battle, the repeat-summon case is a formality today — the rule exists so no future summoner can ever be farmed. The Lich's skeletons are currently the only minions in the game.

For reward tracking, a "summon" means one specific summoning-enemy instance in one party's one expedition. If two future summoners appear in the same battle, each can pay its minion XP once; if the same summoner creates another wave after its first paid wave was defeated, that later wave pays no XP.

### Enemy gold traits

Each non-boss enemy rolls for at most one trait when it spawns, with one exception: on **day 1** (the first expedition — where every party necessarily runs dungeon level 1) enemies never roll a trait, so the opening dive is always trait-free (see the GDD). From day 2 onward the roll applies on every dungeon level, including level 1. Traits only affect gold and the tanking needed to earn it — they never change what the encounter is fundamentally doing.

| Trait   | Chance | Effect                              |
|---------|--------|-------------------------------------|
| Gilded  | 12%    | ×2 gold. Rendered by a whole-sprite gold-sheen shader (gold-ramp remap + glint sweep) — no dedicated art. A Gilded Slime is the Golden Slime. |
| Hoarder | 5%     | ×3 gold, +50% HP, -2 speed. A fat, slow, juicy target. |
| (none)  | 83%    | —                                   |

Bosses never roll traits; their gold is already 2.5×-5× the *maximum* a normal enemy of their level can drop (which works out to roughly 6-7.5× its average, the ratio tightening as `gold_min` goes non-zero from dungeon level 3 on), folded into the table above.

### Encounters

Per the GDD, a dungeon level is **4 regular fights then a boss at dungeon levels 1-2**, and **5 regular fights then a boss at dungeon levels 3 and above** — so 5 battles deep early and 6 battles deep late. For dungeon level N:

```
fight 1:  (1 + N) grunts
fight 2:  (1 + N) grunts + 1 caster
fight 3:  (2 + N) grunts
fight 4:  (1 + N) grunts + 2 casters
fight 5:  (2 + N) grunts + 2 casters     ← dungeon levels 3+ only
boss:     boss + 1 grunt escort          (does not scale)
```

So regular fights gain +1 grunt per dungeon level above 1 while caster counts stay fixed, the fifth fight only exists from dungeon level 3 on, and the boss battle is always boss + 1 grunt.

Each party traverses its own **independent copy** of its chosen dungeon level — separate enemy spawns, separate gold-trait rolls, separate boss, separate once-per-fight ability flags. Two parties on the same level each fight their own Lich, and nothing one party does can affect another's instance.

| Dungeon | Battles | Grunts | Casters | Boss | Total enemies | XP per living member | Gold per living member |
|---------|---------|--------|---------|------|---------------|----------------------|------------------------|
| 1 | 5 | 10 | 3 | 1 | **14** | 22 | ~23 |
| 2 | 5 | 14 | 3 | 1 | **18** | 51 | ~56 |
| 3 | 6 | 23 | 5 | 1 | **29** | 118 | ~221 |
| 4 | 6 | 28 | 5 | 1 | **34** | 263 | ~486 |

Dungeon levels 1 and 2 are unchanged by the 4-vs-5 fight rule — they always ran four fights and a boss. Adding fight 5 to the back half grows dungeon level 3 from 22 enemies to 29 and dungeon level 4 from 26 to 34, which is why the late-game gold and XP figures below are considerably larger than the early ones.

A full dungeon level 1 clear is 14 enemies, worth **22 XP** and roughly **23 gold** to each surviving member (13 non-boss enemies at ~1 gold each × the 1.22 expected trait multiplier, plus ~7.5 from the boss). The ~23 figure is the steady-state level-1 clear from day 2 on; on **day 1** traits are suppressed, so that first clear pays the flat ~13 from grunts (no 1.22× multiplier) for roughly **20 gold** — the 22 XP is unchanged, since traits never touch XP. 22 XP puts a fresh level 1 adventurer at level 2 with 14/16 progress toward level 3; two full clears reach level 3, which is exactly the gate for dungeon level 2. This lines up with the GDD's 3-day target for level 1.

### Dungeon level selection (party AI)

Each party targets the hardest **unlocked** dungeon level whose **minimum average party level** it meets. There is no upper bound — an over-leveled party always takes the hardest thing it can reach.

| Dungeon level | Min average party level |
|---------------|-------------------------|
| 1             | 1 (always fits)         |
| 2             | 3                       |
| 3             | 5                       |
| 4             | 7                       |
| N (general)   | 2N - 1                  |

A level is unlocked once any party has ever cleared the previous one; level 1 is always unlocked.

### Endless mode

Endless mode adds **no new dungeon levels** — there are only ever 4. After the game is won the player keeps sending parties down the same dungeon, and **each expedition in which at least one party fully clears level 4 increments the endless tier by exactly 1**. The increment is per expedition, not per clearing party: three parties all clearing on the same day is still +1, which matches the existing rule that only one party has to beat the boss for a level to count as completed. Since every party at that point averages well over level 7, all three run level 4 and the practical pace is +1 tier per day.

Endless tier starts at **0**. The winning, first clear of dungeon level 4 is fought at tier 0. Each later expedition that has at least one party fully clear level 4 first resolves all rewards using its starting tier, then increases the tier by exactly 1. Every party in one expedition always uses the same starting tier.

At tier `T`, apply the following additive scaling to the base enemy or reward value:

```
enemy_hp(T) = round(base_hp * (1 + 0.25 * T))
enemy_power(T) = base_power + T
xp_reward(T) = max(1, round(base_xp * (1 + 0.20 * T)))
gold_reward(T) = round(base_gold_roll * (1 + 0.20 * T))
```

The scaling is additive rather than compounded so endless enemies stay on the same broadly linear growth curve as uncapped adventurer levels. For enemies with a gold trait, first scale the rolled gold by tier, then apply the trait multiplier. For a Hoarder, first calculate its tier-scaled HP and then apply its +50% HP, rounding again. A minion's 50% XP penalty is applied after endless XP scaling and still rounds down. Evasion and accuracy are untouched by endless tiers, which is why the hero panel's display rule needs no endless-mode special case.

## Building upgrade costs

Every building maxes at level 5. Visual states map as: ruined → normal (levels 1-2) → upgraded (levels 3-4) → max upgraded (level 5).

| Action                    | Cost |
|---------------------------|------|
| Rebuild (ruined → lvl 1)  | 10   |
| Building level 1 → 2      | 40   |
| Building level 2 → 3      | 100  |
| Building level 3 → 4      | 250  |
| Building level 4 → 5      | 625  |

Formula: `building_upgrade(L → L+1) = 40 * 2.5^(L-1)`. Anchored to the GDD's "roughly 10g for the first rebuild, 40g for the next level."

Individual upgrades (pips) within a tree scale from their own base: `pip_cost = base * 1.8^(pips already purchased)`, rounded to the nearest gold.

| Upgrade               | Tree     | Pips | Base | Cost per pip           | Effect per pip                                    | Gate     |
|-----------------------|----------|------|------|------------------------|---------------------------------------------------|----------|
| Hero Capacity         | Inn      | 5    | 12   | 12/22/39/70/126        | +1 hireable hero per day (base 3, max 8)          | —        |
| Elite Recruits        | Inn      | 5    | 15   | 15/27/49/87/157        | +5% elite chance (base 0%, max 25%)               | —        |
| Recruiter's Cut       | Inn      | 1    | 16   | 16                     | Every recruit arrives with 10% of their pre-discount base cost as personal gold | Inn 1 |
| Seasoned Replacements | Inn      | 1    | 25   | 25                     | Kick's replacement roll weights level-appropriate reserves 3× | Inn 1 |
| War Table             | Inn      | 1    | 20   | 20                     | +1 party action during call to arms (base 2, max 3) | —      |
| Horn of Retreat       | Inn      | 1    | 30   | 30                     | Adds the retreat button to the dungeon UI         | Inn 2    |
| Guild Champion        | Inn      | 1    | 45   | 45                     | The highest-level adventurer in town is always drafted into a party | Inn 2 |
| Recruit Discount      | Inn      | 3    | 8    | 8/14/26                | -8% hiring cost (max -24%)                        | Inn 3    |
| Sharper Steel         | Weapon   | 5    | 9    | 9/16/29/52/94          | +1 power to all tier 1+ weapons                   | Weapon 4 |
| Keen Edge             | Weapon   | 5    | 9    | 9/16/29/52/94          | +2% crit chance to all tier 1+ weapons (max +10%) | Weapon 5 |
| Thicker Plate         | Armor    | 5    | 9    | 9/16/29/52/94          | +1 armor to all tier 1+ armor                     | Armor 4  |
| Reinforced Straps     | Armor    | 5    | 9    | 9/16/29/52/94          | +2% guard to all tier 1+ armor (max +10%)         | Armor 5  |
| Warding Charms        | Jewelry  | 5    | 9    | 9/16/29/52/94          | +2 max morale to all tier 1+ jewelry (max +10)    | Jewelry 4|
| Soothing Stones       | Jewelry  | 5    | 9    | 9/16/29/52/94          | +1 morale regen to all tier 1+ jewelry (max +5)   | Jewelry 5|
| Drill Regimen         | Training | 5    | 11   | 11/20/36/64/115        | +10% hero XP gain (max +50%)                      | —        |
| Sparring Dummies      | Training | 5    | 13   | 13/23/42/76/136        | +1 power, +4 accuracy to all heroes               | —        |
| Endurance Course      | Training | 5    | 13   | 13/23/42/76/136        | +2 max HP, +4 evasion to all heroes               | —        |
| Fresh Blood           | Training | 3    | 14   | 14/25/45               | New hires get +25% XP for their first N dives, N = pips (max 3) | Train 2  |
| Veteran Welcome       | Training | 3    | 14   | 14/25/45               | New hires start with +8 XP                        | Train 3  |
| Plunder Tactics       | Training | 5    | 12   | 12/22/39/70/126        | +10% gold your adventurers recover (max +50%)     | —        |

The **Unlock Equipment Tier** line from the previous draft is deleted; each shop's building level does that job now. Note the shape this gives all three equipment trees: levels 1-3 buy tier access and nothing else, and a tree only sprouts pips at level 4. That is intentional and legible — a shop's job is unlocking its slot's gear, and its two shop-wide lines are the reward for finishing it — but it does mean all three shop panels show an empty pip area until level 4, which the UI should handle gracefully rather than looking broken.

### Seasoned Replacements — the weighted Kick roll

Without this upgrade, Kick pulls a uniformly random reserve. With it:

```
for each reserve r:
    w = 1
    if abs(r.level - party.average_level) <= 1 or abs(r.level - party.highest_level) <= 1:
        w = 3
    weight[r] = w
pick a reserve with probability proportional to weight
```

`party.average_level` and `party.highest_level` are computed **after** the kicked adventurer is removed — they describe the party the replacement is actually joining. If that leaves the party empty there is no average or highest to compare against, so every reserve keeps weight 1 and the roll is uniform. The average is fractional and compared as such, so a level 4 reserve matches a party averaging 4.7.

### Guild Champion — seeded formation

Formation normally shuffles all hired adventurers and drafts the first 9. With Guild Champion:

1. Find the highest-level hired adventurer (ties broken uniformly at random).
2. Place them into a party chosen uniformly at random from the 3.
3. Shuffle everyone else and run the normal draft to fill the remaining 8 slots.

### How much these two actually fix

They help, and they do not close the problem. With a roster of 30 (9 veterans at level 7, 21 fresh level 1s):

| Setup | Expected veterans in the 9 slots |
|-------|----------------------------------|
| Neither upgrade | 2.7 |
| Guild Champion | 3.2 |
| Guild Champion + Seasoned Replacements + 3 Kicks | ~4.8 |

(Seasoned Replacements moves a single Kick's odds of pulling a veteran from 28% to 53%, and the War Table's third action is what makes three Kicks possible.)

So the player goes from fielding a quarter veterans to just over half. **This is a known, deliberate partial fix.** Hero Capacity at its max of 8 hires/day can still dilute the parties, but the hired roster has a hard cap of 100. There is no roster browser, retirement action, or direct party assignment; random formation plus Kick/Swap remains the intended party-control model.

## Economy

- Player starts with 19 gold.
- The inn starts built at level 1. All four other buildings — the weapon shop, the armor shop, the jewelry shop, and the training grounds — start ruined, at 10 gold each to rebuild.
- Maximum roster: 100 hired adventurers in town; hiring is disabled while at the cap.
- Recruit class is rolled uniformly at random from the six classes, independently per slot. Duplicates are common; a day producing three Rogues is normal and correct.
- Unhired recruits do not persist. They leave at nightfall and the next crow generates a fresh set.
- **All enemy gold goes to the adventurers.** The player receives nothing directly from the dungeon.

### Hiring costs

Rolled **once, at generation**, and fixed for as long as that adventurer stands at the inn:

```
base_cost = randint(7, 9) + sum of (K - 1) independent randint(4, 7) rolls
```

for an adventurer arriving at level K. A level 1 recruit is 7-9. An elite arriving at level 3 is 7-9 + two rolls of 4-7 = roughly 15-23.

Hire + Sponsor costs `2 * base_cost`, and hands the adventurer `base_cost` in personal gold. The sponsorship amount is always the **pre-discount** base cost — Recruit Discount reduces what the player pays, never what the adventurer receives.

### The fractional-gold accumulators

Two upgrades grant percentage benefits that would round away to nothing on the small numbers involved (8% of an 8 gold hire is 0.64). Both resolve through a hidden floating-point credit that pays out in whole gold once it reaches 1. Purses are always integers; only the credits are fractional, and both persist in the save file.

**Recruit Discount** — spend-then-accrue, because the price has to be shown on the button *before* the purchase:

```
shown_price = max(1, base_cost - floor(discount_credit))

on purchase:
    player pays shown_price
    discount_credit -= floor(discount_credit)
    discount_credit += base_cost * discount_rate       # rate = 0.08 * pips, max 0.24
```

Worked example at 8% with 8 gold recruits:

| Hire | Credit before | Shown price | Paid | Credit after |
|------|---------------|-------------|------|--------------|
| 1 | 0.00 | 8 | 8 | 0.64 |
| 2 | 0.64 | 8 | 8 | 1.28 |
| 3 | 1.28 | **7** | 7 | 0.92 |
| 4 | 0.92 | 8 | 8 | 1.56 |
| 5 | 1.56 | **7** | 7 | 1.20 |
| 6 | 1.20 | **7** | 7 | 0.84 |

Over many hires this converges on exactly 8%, and the player experiences it as an occasional "this one's a gold cheaper" rather than as a fraction. Note the credit accrues on `base_cost` (pre-discount), not on what was actually paid, and that a Hire + Sponsor accrues on its full `2 * base_cost` listed price.

**Recruiter's Cut** — accrue-then-pay, since nothing needs previewing:

```
on hire:
    signing_credit += base_cost * 0.10
    grant = floor(signing_credit)
    signing_credit -= grant
    adventurer.gold += grant
    if sponsored:
        adventurer.gold += base_cost                   # the pre-discount sponsorship
```

So a plain 8 gold hire pays out 1 gold to roughly every second recruit, and a sponsored hire arrives with the full sponsorship plus that same trickle — effectively 110% of the sponsor amount, which is the stated intent.

### The two income streams

**1. The tax-copy — 10% of all gold adventurers earn, rounded down.** Minted, not deducted: the adventurers keep every coin, and the player's 10% is created alongside it. Earn 57 gold, player gains 5, adventurers still hold 57.

> **Implementation note, and this one matters:** compute the tax-copy on the **summed total across all adventurers for the whole expedition**, then take 10%, then floor — **once**, at the end. Flooring per drop pays the player exactly zero: a dungeon level 1 grunt drops 0-2 gold, and `floor(0.1 × 2) = 0`. Every single drop on level 1 rounds away to nothing. Accumulate → multiply → floor.

Gold counted toward the tax-copy remains eligible even if the adventurer who earned it dies later in the run and loses their purse. The player receives the total tax-copy when the expedition resolves, after summing all eligible gold and flooring once.

**2. The sales commission — 10% of every purchase at a player-owned shop, minimum 1 gold, rounded up.** This is a cut of the vendor's revenue, not a surcharge; the adventurer pays the listed price either way. Tier 1 at 8g → 1g. Tier 2 at 16g → 2g. Tier 5 at 128g → 13g.

Sponsored gold is never recovered when spent, but sponsoring raises the adventurer's earning power (more tax-copy) and their spending pays commission like anyone else's.

### Day 1-3 sanity check

- **Day 1**: 19 gold hires 2 adventurers (~16g), leaving ~3g. All three equipment shops are still ruined, so there is nothing for anyone to buy. They clear dungeon level 1 and come home at level 2 with ~23 gold each. Total earned 46 → tax-copy **+4g**. Treasury ~7g.
- **Day 2**: still can't afford a 10g rebuild. Run again: +4g, treasury ~11g. Adventurers are now sitting on ~46g each with nowhere to spend it.
- **Day 3**: **the player picks one shop to rebuild.** Say the weapon shop (10g), treasury ~1g. A level 1 shop stocks tiers 1 **and** 2. Both adventurers immediately buy a tier 1 weapon (8g each) — commission 1g each, **+2g** — and being level 3 by now they qualify for tier 2 as well and upgrade straight into it (16g each) → another 2g each, **+4g**. Treasury ~7g. Their armor and jewelry slots stay at tier 0 because those shops are still rubble, so the ~22g each has left over stays banked against whichever shop opens next.

That day-3 choice is the point of the three-shop split. The old single-shop design had the player rebuilding *the* shop; now they are choosing whether their roster becomes killers, survivors, or specialists first, and the two shops they skip keep their slots at tier 0 until the treasury catches up. Folding tier access into the building level also means a rebuild always stocks two tiers at once, which is the right shape for the purchase the whole early economy is waiting on.

The tax-copy is what makes days 1-2 survivable: without it the player would earn literally nothing until a shop existed, and would have no way to ever afford the first rebuild.

### Long-run projection

Per-member gold for a **full clear** (including the 1.22× expected multiplier from gold traits):

| Dungeon level | Enemies | Gold per living member | 9 members | Tax-copy |
|---------------|---------|------------------------|-----------|----------|
| 1             | 14      | ~23                    | ~210      | ~21g     |
| 2             | 18      | ~56                    | ~508      | ~50g     |
| 3             | 29      | ~221                   | ~1,992    | ~199g    |
| 4             | 34      | ~486                   | ~4,376    | ~437g    |

Plus commission on top as that gold gets spent.

Total cost of a fully-developed town, for reference:

| Building | Rebuild + levels | Pips | Total |
|----------|------------------|------|-------|
| Inn (starts at level 1, no rebuild) | 1,015 | 788 | 1,803 |
| Weapon Shop | 1,025 | 400 | 1,425 |
| Armor Shop | 1,025 | 400 | 1,425 |
| Jewelry Shop | 1,025 | 400 | 1,425 |
| Training Grounds | 1,025 | 1,263 | 2,288 |
| **Grand total** | | | **~8,366** |

Splitting one item shop into three raised the town's price tag from ~5,516 to ~8,366, a jump of 2,850: two extra buildings each carry a full 1,025 gold ladder (2,050), and the shop-wide lines went from one shop's two (400 in pips) to three shops' six (1,200), adding the other 800. Adding the fifth fight to dungeon levels 3-4 paid for it: those levels went from 22 and 26 enemies to 29 and 34, which lifts dungeon 4's tax-copy from ~345 to ~437 a day.

Those two changes very nearly cancel. Cumulative tax-copy across the GDD's intended 31-day arc (3 days on level 1, 5 on level 2, 9 on level 3, 14 on level 4):

```
 3 days × ~21g  =    63
 5 days × ~50g  =   250
 9 days × ~199g =  1,791
14 days × ~437g =  6,118
                  ------
                   8,222   vs. a town costing 8,366
```

So a player running the intended pace finances almost exactly the whole town out of tax-copy alone by the day they win, with sales commission covering the remainder and any slack. That is the shape to protect: nothing is wasted, the last upgrade lands near the last boss, and endless mode inherits a finished town. It also means the arc has very little margin — if playtesting adds a sixth building or another pip line, income has to move with it, and the tax-copy rate is the dial (see Levers below).

This is a healthy shape: player income scales with adventurer earnings, which scale with dungeon depth, which scales forever through endless tiers. Unlike a spend-only tax, it never dries up when a hero finishes their gear, and it does not perversely reward letting adventurers die.

Note that the treasury is still not strictly on the critical path — adventurers level for free, earn their own gold, and buy their own gear, so a broke player still clears the dungeon and a wiped player gets free adventurers for ringing the bell. The treasury buys optimization. It just now accumulates fast enough for that optimization to actually happen inside a normal play session.

Levers, in the order worth pulling if playtesting says the town is too slow or too fast:

1. **The tax-copy rate.** Single cleanest dial, and it scales across the entire game rather than just the early or late half.
2. **Adventurer gold drops** (or lean on Plunder Tactics). Because the tax-copy is a flat percentage of earnings, this moves player and adventurer income together.
3. **The commission rate**, which biases toward rewarding shop investment specifically.
4. **Building costs.** Least interesting, but works.

## Tuning notes for playtesting

- If level 1 feels too easy/hard, adjust grunt power (3) and count per battle before touching hero stats — the Captain anchor depends on hero-side numbers staying put.
- The hit formula gives ~96% hit chance at equal accuracy/evasion ratings, so evasion only matters when stacked well above the attacker's accuracy (Rogue, Captain). This is intentional in the draft; revisit if dodging feels irrelevant. It is also why displayed accuracy is a flat 100% for most of the early game.
- Mage is the glass cannon benchmark: if Mages routinely die in battle 1, add +2 HP rather than evasion (keeps the fantasy of squishy but avoids invalidating the AOE anchor).
- Cleric heal is `power + 1`. Watch the top end: a fully-invested Cleric heals 23, roughly two dungeon-4 hits per turn. If that trivializes level 4, drop to `power` and raise Cleric base power to 3 to hold the level 1 anchor.
- Because heroes heal to full outside the dungeon, difficulty lives entirely inside a single dive. If dives feel too safe, cut regen or lengthen dungeon levels rather than nerfing the heal-to-full rule — it is what makes death, rather than attrition, the real stake.
- XP pacing may be too fast: one full level 1 clear is nearly two levels. If parties are reaching each dungeon level well before its day target, cut base XP before touching the `8 * level` curve.
- Panic tuning: the 0.5 threshold is the main dial. Raising it to 0.6 makes morale a constant background pressure; lowering it to 0.4 makes morale a rare emergency.
- Turn duration is 0.6s. Dropping to 0.4s is the lever for late-dive length; adding a speed toggle is the lever the GDD currently forbids.
