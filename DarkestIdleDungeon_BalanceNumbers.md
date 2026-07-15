# Darkest Idle Dungeon — Balance Numbers (First Draft)

These numbers are a first draft authored to satisfy the anchor points in the game design document. They are expected to change through playtesting. When a number here conflicts with the GDD, the GDD wins.

## Anchor points (from the GDD)

1. A level 1 Mage deals 1-3 AOE damage (med-low to med-high damage output).
2. A Captain survives 6-7 attacks (dodging some of them) from the very first level 1 enemy encounter.

## Core rules used by these numbers

- Damage roll: uniform integer in [power - 1, power + 1], minimum 1, rolled before armor. Armor subtracts flat damage from the roll (minimum 1 damage on a landed hit).
- Chance to hit: `AA * 1.25 * 100 / (AA + DE * 0.3)`, clamped to [5%, 100%] (per the GDD).
- Crit: multiplies the damage roll by (1 + crit damage bonus) before armor.
- Guard: a blocked attack deals 0 HP damage but full morale damage.
- Morale damage: applied on every landed (non-evaded) hit. When a party member dies, each surviving party member takes 2 morale damage.
- HP regen and morale regen apply at the end of each battle (not per turn).

## Anchor verification

- Captain: 12 HP, 1 armor, 150 evasion. Level 1 grunt: 100 accuracy, 3 power. Hit chance vs Captain = 12500 / (100 + 45) ≈ 86%. Average landed hit = 3 - 1 armor = 2 damage. Landed hits to kill = 12 / 2 = 6. Expected attacks = 6 / 0.86 ≈ 7. → survives 6-7 attacks, dodging some. ✔
- Mage: power 2, damage roll 2 ± 1 = 1-3, hits all enemies in the battle. ✔

## Adventurer base stats (level 1)

| Class     | HP | HP Regen | Power   | Speed | Armor | Guard % | Evasion | Accuracy | Crit % | Crit Dmg | Max Morale | Morale Regen |
|-----------|----|----------|---------|-------|-------|---------|---------|----------|--------|----------|------------|--------------|
| Knight    | 14 | 1        | 2       | 3     | 2     | 25%     | 120     | 100      | 5%     | 50%      | 12         | 1            |
| Captain   | 12 | 1        | 3       | 4     | 1     | 10%     | 150     | 100      | 5%     | 50%      | 12         | 2            |
| Berserker | 12 | 1        | 5       | 5     | 0     | 0%      | 100     | 100      | 15%    | 50%      | 10         | 1            |
| Mage      | 6  | 0        | 2 (AOE) | 4     | 0     | 0%      | 80      | 110      | 5%     | 50%      | 8          | 1            |
| Rogue     | 10 | 0        | 4       | 7     | 0     | 5%      | 180     | 110      | 20%    | 75%      | 9          | 1            |
| Cleric    | 10 | 1        | 0       | 6     | 1     | 10%     | 110     | 100      | 0%     | —        | 11         | 2            |

## Class abilities (first draft)

- Knight — Shield Bash: single target attack; after attacking, guard chance is doubled until his next turn (his "defensively attack").
- Captain — Attack normally; every 3rd turn uses Rallying Horn instead: restores 2 morale to every living party member and grants them +1 power on their next attack.
- Berserker — Attack normally; passive Frenzy: +1 power while below 50% HP.
- Mage — AOE bolt: hits every enemy in the battle for a power ± 1 roll each (each target rolls evasion separately).
- Rogue — Attack normally; relies on high crit chance and crit damage.
- Cleric — Heal: restores 3 HP to the lowest-HP living ally. If all allies are at full HP, casts Blessing instead: +1 armor to a random ally until the end of the battle.

## Adventurer growth per level

- +2 HP (Knight +3)
- +1 power every 2 levels (on even levels)
- +12 evasion, +12 accuracy
- +1 max morale every 2 levels (on odd levels after 1)
- XP required to reach the next level: `8 * current level` (level 1→2: 8 XP, 2→3: 16 XP, 3→4: 24 XP, ...)

## Enemies (placeholder names — theme is a future visualization task)

### Dungeon level 1

| Enemy   | HP | Power   | Speed | Armor | Evasion | Accuracy | Morale Dmg | Gold | XP |
|---------|----|---------|-------|-------|---------|----------|------------|------|----|
| Grunt   | 8  | 3       | 4     | 0     | 60      | 100      | 1          | 2    | 2  |
| Caster  | 5  | 2 (AOE) | 3     | 0     | 50      | 100      | 1          | 3    | 3  |
| Boss 1  | 25 | 5       | 4     | 1     | 80      | 110      | 2          | 10   | 8  |

Encounters per row (5 battles, per the GDD's 4-5 battles per level): battle 1 = 2 grunts; battle 2 = 2 grunts + 1 caster; battle 3 = 3 grunts; battle 4 = 2 grunts + 2 casters; battle 5 (boss) = boss + 1 grunt.

### Scaling for dungeon levels 2 and 3

Per dungeon level above 1: HP ×1.6 (rounded), power +2, evasion +40, accuracy +40, morale damage +1, gold ×1.7, XP ×1.8. Bosses additionally gain +1 armor per dungeon level. Encounter sizes grow by +1 enemy in the non-boss battles.

### Dungeon level selection (party AI)

Each party targets the hardest unlocked dungeon level whose character-level range contains the party's average level (a level is unlocked once any party has ever cleared the previous one; level 1 is always unlocked):

| Dungeon level | Character level range |
|---------------|-----------------------|
| 1             | any                   |
| 2             | 4 ± 2 (2-6)           |
| 3             | 6 ± 3 (3-9)           |
| 4             | 8 ± 3 (5-11)          |
| N (general)   | 2N ± min(N, 3)        |

If the party's average level fits no higher unlocked range, they go to level 1. Where ranges overlap (e.g. average level 6 fits both level 2 and level 3), the party picks the higher unlocked level.

### Endless mode

After the game is won, each subsequent full clear of level 3 increments an endless tier: all enemies gain +25% HP and +1 power per tier, and gold/XP rewards gain +20% per tier.

## Economy (mirrors the GDD)

- Player starts with 19 gold.
- Rebuilding a ruined building: 10 gold.
- Hiring a level 1 adventurer: 7-9 gold; each level beyond 1 adds 4-7 gold.
- Hire + sponsor: doubles the hiring cost; the extra amount is given to the adventurer as personal gold to spend in the player's shops.
- Enemy gold rewards go to the player treasury. Each surviving party member additionally pockets 1-2 personal gold per battle won (for their own equipment purchases).

Day 1 sanity check: 19 gold hires 2 adventurers (~16 gold) with ~3 left over, or 1 adventurer plus a 10 gold rebuild. A partial level 1 run (2 battles) returns roughly 8-13 gold to the treasury, which funds another hire or a rebuild on day 2 — consistent with the 3-day target for level 1.

## Tuning notes for playtesting

- If level 1 feels too easy/hard, adjust grunt power (3) and count per battle before touching hero stats — the Captain anchor depends on hero-side numbers staying put.
- The hit formula gives ~96% hit chance at equal accuracy/evasion ratings, so evasion only matters when stacked well above the attacker's accuracy (Rogue, Captain). This is intentional in the draft; revisit if dodging feels irrelevant.
- Mage is the glass cannon benchmark: if Mages routinely die in battle 1, add +2 HP rather than evasion (keeps the fantasy of squishy but avoids invalidating the AOE anchor).
