# Lord of Hirelings — Art Style Guide

The single source of truth for every asset in `LordofHirelings_ArtAssetList.md`. Anything not
covered here gets decided once, then written here. If an existing asset and this guide disagree,
the guide wins and the asset gets fixed in the next art pass.

**Vision in one line:** a warm, lantern-lit town you rebuild, feeding adventurers into a dungeon
that gets colder, darker, and meaner the deeper it goes. Town = cozy, gold, alive. Dungeon =
an escalating color script from sunny forest to hellfire. The contrast IS the game's look.

---

## 1. Technical specs (locked)

| Spec | Decision | Rationale |
|---|---|---|
| Native art resolution | **960×540** | The current project target is lower than the 1280×720 cap, so it remains the native art resolution; integer-scales to 1080p (2×), 1440p (2× letterboxed), and 4K (4×) |
| Screen scaling | **Integer scale only, nearest-neighbor.** Never fractionally scale a sprite. | Mixed pixel densities are the #1 "cheap pixel art" tell |
| Adventurer / grunt sprite canvas | **48×48** (figure fills ~40–46px tall) | Matches mockup `.sprite`; reads at dive-row scale |
| Boss sprite canvas | **64×64** (Swamp Troll, Bandit King, Lich) | Matches mockup boss note |
| Demon Prince | **96×96** — the largest sprite in the game, per GDD | Final boss must dwarf everything |
| Rooster, dog, small props | 24–32px | |
| Town tile grid | **16×16** tiles. Buildings are free-size props snapped to the grid | 48px characters = 3 tiles tall; grid keeps town layout honest |
| Building footprint | Inn/shops roughly **112–160px wide × 96–128px tall** (2–2.5 character-heights) | Characters must feel human-scale against buildings |
| Pivot | Bottom-center on every character/enemy/prop | Required by the rotate + squash/stretch locomotion tween |
| Portraits | **Never downscale.** Reuse the sprite at 1:1, or crop a 32×32 head/torso region at 1:1 | Non-integer scaling destroys pixel art; mockup's 34px scale-down is NOT the plan |
| Rotation tweens | Keep code rotation within **±8°**; rendered at 2× screen scale the off-grid pixels stay chunky and read as style | Full-speed rotation shimmer would fight the pixel look |
| Font | **Pixel Operator** regular + bold. CC0 1.0; source files and license live in `lord-of-hirelings/source-assets/fonts/pixel-operator/`. | Its excellent digits and compact pixel rhythm suit the stat-dense UI; bold is reserved for CRIT and other high-attention text. |

## 2. Master palette & color rules

### Base palette
Start from **Apollo** (lospec.com/palette-list/apollo, 46 colors, pre-built hue-shifted ramps)
plus the UI ramp below. Cap the working palette at **~48 colors game-wide**; each individual
sprite uses **3–4 ramps max, 3 steps each** (shadow / mid / light). Add a color only when no
existing ramp works, and add it to this guide when you do.

### UI palette (already established by the mockups — keep it)
| Role | Hex |
|---|---|
| Deepest ground / fog / shadows | `#101014` |
| App background | `#17171c` |
| Panel fill | `#26262e` |
| Panel border / separators | `#6b6b7a` |
| Secondary label blue | `#99aadd` |
| Gold accent ramp (dark→light) | `#c9a15a` → `#d4b000` → `#f0d890` → `#ffe9b0` |
| Attention gold (turn marker, selection) | `#ffd35a` |
| HP red | `#c0392b` |
| Morale blue | `#2980b9` |
| Positive green | `#7ec97e` |

### Color channels (reserved meanings — never violate)
- **Gold** = money, interactivity, player attention. Prompts, turn marker, XP, coins, primary
  buttons, upgrade pips. Nothing hostile is ever gold (the Gilded trait is gold *because it
  means more money*).
- **Red** = damage and death. Damage numbers, HP fill, blood, death tint. Keep costume reds on
  sprites desaturated so they don't compete.
- **Blue** = morale and panic. Morale bar, cower spiral. (The blue Slime stays a desaturated
  slate — never the bright morale blue.)
- **Green** = healing and regen (and, desaturated, the swamp — heal green is bright and clean,
  swamp green is gray and murky; they never look alike). Slime green sits with the forest
  flora: leafy and mid-saturated, never as bright as heal green.
- Every color meaning also gets a **redundant shape/value cue** (color-blind rule): damage
  numbers are bold+outlined, heals have a `+`, the turn marker is a shape not just a color.

### Ramp rules
- **Hue-shift every ramp:** shadows shift cool (toward blue/purple), highlights shift warm
  (toward yellow/orange). Never darken by adding black — that's where "muddy" comes from.
- Saturation peaks in the **midtone/terminator**, not the highlight.
- **No dithering on sprites** (they're 48px — dither reads as noise). Dither is allowed on
  large background gradients (sky) only.
- Banned pixel-art tells: banding, pillow shading (always honor the global light direction),
  jaggy inconsistent line slopes, grayscale-tinted ramps.

### Color script (per zone — the emotional arc)
| Zone | Key | Gamut | Mood |
|---|---|---|---|
| Town — day | High-key | Warm: golds, grass greens, timber browns, blue sky | Safe, industrious |
| Town — night | Low-key | Deep blues/purples + warm gold window/lantern accents | Quiet, cozy |
| Dungeon 1 — Gentle Forest | High-key | Analogous fresh greens + warm sunlight | Deceptively friendly |
| Dungeon 2 — Swamp | Mid-key | Desaturated gray-greens, murk browns, mist | Uneasy |
| Dungeon 3 — Undead Crypt | Low-key | Cold blue-greens, stone grays, sickly soul-green accents | Dread |
| Dungeon 4 — Volcanic Hellscape | Low-key | Near-black basalt vs saturated orange-red lava (complementary) | Hostile, climactic |

The arc: each level drops in key and warmth until level 4 breaks the pattern with violent
warm-on-dark contrast. Adventurer sprites keep their own palettes in every biome — they're
the constant; the world changes around them.

## 3. Outlines & rendering convention

- **Characters, enemies, and interactable props get a 1px selective outline.** Outline color is
  a very dark hue-shifted version of the local color (e.g. deep cool brown for a bandit, deep
  blue-gray for a knight) — **never pure black**. Break/lighten the outline on the lit (top)
  side so form pushes through ("selout").
- **Backgrounds, backdrops, and tiles get NO outline** — form and value only. This one rule
  gives free figure/ground separation in every scene.
- UI chrome uses the mockup convention: hard 2–3px borders in `#6b6b7a`, outer drop of `#101014`.
- Uniform 1px line weight everywhere; no "doubles."

## 4. Lighting (one global rule)

- **Light comes from the top, biased slightly left, in every sprite in the game.** Town, dungeon,
  UI icons — no exceptions. Inconsistent shadow direction is the fastest "amateur" tell.
- Every character/enemy gets a **code-drawn soft contact-shadow ellipse** at the pivot. This is
  what grounds sprites that rotate and squash — without it the tween looks floaty.
- Biome backdrops may add flavor light (forge glow, torchlight, lava glow) but flavor light is
  always **weaker than the global key** on sprites.
- Night town is a **fully repainted backdrop** (per GDD — no code lighting pass): moon, stars,
  lit windows, lantern pools painted in. Warm gold lights against the cool blue night is the
  money shot of the whole game — spend polish here.
- **Glow budget:** emissive glow only on — Mage/caster VFX, tier-5 relic icons, phylactery,
  lava, the Gilded shader's glint sweep, lit windows at night. If everything glows, nothing
  glows.

## 5. Readability stack (dungeon dive rows)

Rank of value + saturation range, widest to narrowest — nothing lower on the list may out-pop
anything above it:

1. **UI** — floating combat text, turn marker, HP/morale bars, Horn of Retreat
2. **VFX** — hit sparks, bolts, heals, Eruption
3. **Combatants** — clearly brighter and more saturated than the backdrop
4. **Biome backdrop** — compressed mid values, low contrast, desaturated relative to sprites

Concrete rules:
- Backdrops live in the **middle 50% of the value range** at reduced saturation; sprites own the
  extremes. Even the lava biome: the *backdrop* lava is duller than the Flamecaller's flame VFX.
- The fog of war ramps to `#101014`, matching UI shadow — it reads as "UI curtain," not world.
- The defeated-encounter ✕ marker is deliberately low-contrast (`#555`-ish) — it's history, not
  action.
- **QA every dive-row composition with the grayscale + squint tests:** desaturate a screenshot —
  you must instantly find the acting unit (turn marker), then the party, then the enemies, and
  the backdrop must recede. If a backdrop element pops, mute it.

## 6. Shape language

### Adventurer classes (silhouette is sacred)
Each class owns one dominant shape + one **functional exaggeration** — the thing the class
*does*, made the biggest element of the outline. The 5 variants per class may only change
secondary/tertiary elements (heraldry, trim, colors, weapon *within the same envelope*); the
silhouette never changes, so class reads instantly at 48px.

| Class | Dominant shape | Exaggerate (the verb) | Silhouette notes |
|---|---|---|---|
| Knight | **Square** | The shield — oversized, always visible | Blocky, wide stance, closed form |
| Captain | Square + upward line | The polearm — tallest silhouette in the party | Lighter frame than Knight; horn breaks the hip line |
| Berserker | **Triangle**, wide base | Weapons + shoulders — huge arms, giant axe/claymore | Biggest non-boss mass; wild hair spikes the outline |
| Mage | Tall narrow triangle | The void hood — featureless black face opening | Unbroken robe cone; staff adds one thin vertical |
| Rogue | Small sharp triangles | Crouched compactness — smallest, lowest adventurer | Cloak points, dagger notch; nimble = lean |
| Cleric | **Circle** | The book/raised mace — supportive, open pose | Round hood/tonsure, soft robe curves; zero aggression |
| Player Lord | Circle | The book + bald head | Round, warm, unarmed — the only "soft old man" shape in the cast |

**Silhouette QA:** fill the whole cast solid black at 48px, side by side. Every class must be
identifiable. Rerun whenever a variant is added.

### Enemies
Each dungeon level keeps the same four-silhouette pattern so encounters parse instantly:
**beast/low** (Wolf, Leech, Zombie, Imp), **humanoid grunt** (Bandit, Lizardfolk, Skeleton,
Demon Soldier), **hunched caster** (all witches/Necromancer/Flamecaller share a "bent figure +
raised implement" envelope), **big boss** (64px+). Level 1 alone adds a fifth: the **tutorial
blob** (Slime, green/blue palette variants). Enemies lean triangle/jagged overall — they get
the aggressive shape language the adventurers avoid — with the Slime as the one deliberate
exception: it is pure circle on purpose, because the first enemy a player ever fights should
read as harmless. The two blob enemies must never share an outline: Slime = symmetric upright
dome, Giant Leech = long low horizontal taper. A Slime that rolls the Gilded trait renders as
the **Golden Slime** via the Gilded gold shader — no dedicated sprite. Casters across biomes
may share a base silhouette with redress (explicitly OK per asset list: Bog Witch = Hedge
Witch redress).

### Buildings (must read as trades at a glance)
Each building gets a signature **sign shape + accent color + one unique silhouette feature**:

| Building | Sign | Accent | Silhouette feature |
|---|---|---|---|
| Inn | Tankard/bed | Warm gold light | Wide + welcoming, chimney smoke |
| Weapon shop | Hanging blades | Forge orange glow | Open forge front, big chimney |
| Armor shop | Breastplate + shield | Steel blue-gray | Mannequin in plate outside |
| Jewelry shop | Ring | Gem teal/purple glints | Finest masonry, ornate window |
| Training grounds | (none — it's a yard) | Weathered wood | Fence + dummy posts, no roof mass |

Upgrade states change **mass and light**, not identity: ruined = broken silhouette, dark, cold;
max = taller/fuller silhouette, more lit windows, banners. A player must recognize the smithy
from its ruined state through max.

## 7. Detail budget

- Per 48px sprite: detail concentrates at **head → weapon/hands → chest**; legs and feet are
  simple value masses. Tertiary detail (stitches, rivets) must vanish at game distance — if you
  need it to identify the sprite, the silhouette failed.
- Roughly **60/30/10**: one detailed focal zone, one supporting zone, one plain rest zone per
  sprite (an unbroken cloak or plain robe *makes* the detailed head read).
- Town scene: buildings and interactables get the detail; ground tiles and horizon stay quiet.
  The horizon backdrop is atmospheric-perspective flat — lighter, cooler, low contrast.
- Avoid the window-blind effect: vary fold/plank/fence-post spacing and size; never even stripes.

## 8. VFX rules

- VFX own the brightest, most saturated values in any scene (see §5). Hit sparks 2–4 frames,
  white-gold core.
- Floating combat text: red damage / gray MISS / large gold CRIT with punch-scale / green +heals.
  Bold weight + 1px dark outline so it survives any backdrop.
- Enemy caster bolts recolor per biome (thorn green / bog murk / soul green-black / flame
  orange) but share one base shape — "incoming enemy magic" always reads the same.
- Buffs = gold/warm (Rally, Blessing, guard aura). Debuffs/enemy magic = the biome's sickly
  hue. Heals = clean bright green.
- Additive/glow effects cap: this game's rows are small — one screen-wide flash (Eruption,
  Horn) at a time; everything else stays local to its target.

## 9. Production order & QA

### Anchor assets (make these first, to final quality — everything else must match)
1. Knight (variant 1) — the character rendering benchmark
2. Slime + Wolf + Bandit — enemy benchmark (the Slime is the first enemy a player ever sees)
3. Forest biome backdrop + one full dive row composited with UI bars/markers
4. Final town art: Inn (level 1), the town ground tileset, and the Player Lord, assembled directly into the scrollable town map — no separate graybox-art phase
5. Panel + button 9-slice + the pixel font in place

This set IS the vertical slice. Screenshot it, grayscale it, squint at it. When it passes,
lock it and match all ~60 remaining MVP assets to it. Do not polish asset #6 before the
anchors are approved.

### Standing QA checklist (run on every asset, at game zoom, on the real backdrop)
- [ ] Grayscale: does it separate from its background by value alone?
- [ ] Squint: does it mass into 2–3 clean value blocks, not noise?
- [ ] Silhouette: black-fill — still identifiable? Distinct from the rest of the cast?
- [ ] Light from top-left? No pillow shading, banding, or pure-black outlines?
- [ ] Palette: only approved ramps? Hue-shifted shadows? Saturation reserved correctly?
- [ ] At 1× game scale on the real backdrop (never judge on the editor checkerboard)?

### Open items this guide does not decide
- Exact tier-5 relic glow treatment (decide when the first relic icon is drawn).
