# Lord of Hirelings — Art Asset List

Compiled from the GDD (including its TODO ART section), the balance numbers doc, and the HTML mockups. Global style: 2D pixel art. Characters are single static sprites pivoted at bottom-center — locomotion is a code-driven rotate + squash/stretch tween, so **no walk cycles are needed anywhere**. Horizontal flip covers facing direction.

Legend for the Need column: **MVP** = required before the first playable loop exists; **Full** = required to ship the design as written; **Later** = acceptable to stub with a placeholder or code-only effect for a long time.

Legend for the Status column (audited 2026-07-17 against `lord-of-hirelings/sprites/`, `lord-of-hirelings/fonts/`, and the generators in `SourceArt/tools/`):

- `[x]` — shipped art exists in the Godot project and the game uses it.
- `[~]` — partially shipped: the MVP variant/state is in and used, the rest of the row's variants or states are not. The Status cell names what is in.
- `[ ]` — not started. Anything the game currently draws with code primitives, a `ColorRect`, or a plain `Color` fill counts as not started, not as `[~]`.

---

## 1. Character sprites

Silhouette is the primary read at 48px, so every row names its **dominant shape** and **functional exaggeration** (the master spec is the style guide §6 table). QA: black-fill the whole cast side by side whenever a sprite lands — every class must be identifiable by outline alone.

| Name | Description | Visual description | Need | Status |
|---|---|---|---|---|
| Player character | The lord the player controls in town (WASD). Only appears in town view. | **Silhouette: circle** — bald crown, round shoulders, soft unbroken robe curves; the cast's only unarmed, soft-old-man outline. Kindly but shrewd retired scholar-lord, not a wizard (the Mage owns the hooded-caster silhouette; the Lord's head is bare). Functional exaggeration: the thick ledger held closed against his chest — he reads accounts, not spells. Detail budget: face and book; the robe below the waist stays a plain rest zone. Static standing pose, bottom-center pivot. | MVP | [x] `sprites/lord/lord_sheet.png` |
| Knight ×5 variants | Adventurer class sprite, used in town and dungeon rows. | **Silhouette: square** — blocky closed form, wide stance, flat pauldrons. Functional exaggeration: the shield, oversized and always breaking the outline (he tanks, and the outline says so); the sword stays small so the shield dominates. Variants change secondary/tertiary detail only — helmet crest, shield heraldry, plume/color accents — the envelope never changes, so class reads instantly at 48px. Detail: helm → shield face → chest; legs plain. | MVP (1 variant), Full (5) | [~] variant 1 only, in `sprites/recruits/recruit_variants.png` (col 0) |
| Captain ×5 variants | Adventurer class sprite. | **Silhouette: square plus one tall vertical** — the polearm makes him the tallest outline in the party (he leads from the front); the war horn breaking the hip line is his second tell. Lightly armored ranger-like warrior, less metal than the Knight, more traveled: cloak, straps, worn boots. Variants: spear vs halberd vs pike (same height envelope), cloak colors, horn trim. | MVP (1), Full (5) | [~] variant 1 only (`recruit_variants.png` col 4) |
| Berserker ×5 variants | Adventurer class sprite. | **Silhouette: triangle, wide base** — the biggest non-boss mass in the cast. Functional exaggeration: shoulders, arms, and weapon — huge bare arms and an oversized weapon carried high so the outline reads "hits hard, wears nothing"; wild hair spikes the top line. Minimal armor (furs/hide), skin as big simple value masses. Weapon varies by variant within the same mass envelope: dual axes, dual hammers, giant claymore, giant axe. Warpaint/hair are tertiary. | MVP (1), Full (5) | [~] variant 1 only (`recruit_variants.png` col 1) |
| Mage ×5 variants | Adventurer class sprite. | **Silhouette: tall narrow triangle** — one unbroken robe cone from hem to hood tip; the staff adds a single thin vertical. Focal point: the void hood — the face opening is featureless black, the highest-contrast note on the sprite. The robe stays a plain rest zone so the void reads. Variants: robe color/trim, staff finial, glowing eyes or not — never anything that breaks the cone. | MVP (1), Full (5) | [~] variant 1 only (`recruit_variants.png` col 2) |
| Rogue ×5 variants | Adventurer class sprite. | **Silhouette: small sharp triangles** — the smallest, lowest outline in the party: crouched, compact, lean (skinny reads as fast and fragile, which is the kit). Cloak hem breaks into points; the dagger notches the silhouette. Leather armor, hood up, face shadowed but human — the black void belongs to the Mage. Weapon varies within the crouched envelope: single dagger, whip, dual daggers, sword + buckler, rapier + dagger. | MVP (1), Full (5) | [~] variant 1 only (`recruit_variants.png` col 3) |
| Cleric ×5 variants | Adventurer class sprite. Has no attack — poses should read as supportive. | **Silhouette: circle** — round hood/tonsure, soft robe curves, zero aggressive angles anywhere in the outline. Functional exaggeration: the open book/mace raised to bless, never cocked to strike; open forward-facing stance. Distinct from the Player Lord by vestments and the raised implement (the Lord hugs his book closed). Variants: censer instead of mace, habit colors, tonsure vs hood. | MVP (1), Full (5) | [~] variant 1 only (`recruit_variants.png` col 5) |
| Rooster — roosting | Town interactable; usable only at night. | A rooster perched and dozing — one tucked oval mass, head folded in, night-muted colors. | MVP | [ ] code-drawn placeholder in `scripts/town/rooster.gd` |
| Rooster — crowing | The day-start moment. | Same rooster with the outline thrown upward: chest out, neck stretched, beak wide open mid-crow, wings slightly flared. Pairs with the sunrise VFX. | MVP | [ ] code-drawn placeholder in `scripts/town/rooster.gd` |
| Town dog | Flavor: adventurers can "play with the dog" as a town activity. | Small scruffy mutt, wagging tail, single idle pose (tween handles bounce). | Later | [ ] |

**Note on portraits:** the dungeon rows and expedition summary show party member "portraits" — the mockups reuse the class sprite at small scale. Plan is to reuse sprites; no separate portrait art needed unless small-scale readability fails.

## 2. Enemy sprites

Every enemy needs **two poses: idle and attack**. 17 enemies × 2 poses = 34 drawn frames, plus the blue Slime recolor (36 images). Both gold-trait treatments (Gilded, Hoarder) are **shaders — no extra frames**. Each dungeon level keeps the style guide §6 silhouette pattern — beast/low, humanoid grunt, hunched caster, big boss, with level 1 alone adding the tutorial blob — and every row below names the **outline hook** that keeps it distinct in a black-fill test across the whole bestiary.

| Name | Description | Visual description | Need | Status |
|---|---|---|---|---|
| Slime — green + blue | Dungeon lvl 1 tutorial grunt. The first fight of dungeon level 1 always spawns only Slimes — the first enemy a new player ever fights. Blue is a palette swap of green (cosmetic 50/50 at spawn). | **Silhouette: symmetric upright dome** — deliberately the only circle-language enemy in the bestiary: round reads as harmless, which is exactly what the tutorial fight wants. Glossy gel dome, one big top-left window highlight, two simple dot eyes, no limbs. Idle: relaxed dome with a slight settle; attack: coiled-tall pose tipping into a forward flop (the tween carries the motion). Green = leafy forest green, clearly duller than heal green; blue = desaturated slate, never as bright as the morale bar (reserved-color rule). Must never be confusable with the lvl 2 Giant Leech: Slime = upright dome, Leech = long low horizontal taper. | MVP (green), Full (blue swap) | [ ] |
| Golden Slime | The Gilded Slime — a Slime that rolls the Gilded trait (12%, never on day 1; with only two Slime slots per level-1 run it stays a rare jackpot sighting). Standard ×2 gold. | **No dedicated sprite.** Base Slime frames rendered through the Gilded gold shader at full strength — the shader's showcase case: the whole gel body remaps onto the gold accent ramp with the glint sweep rolling through it, so it reads as living treasure at a glance. Honors the reserved-gold rule: the one gold "hostile" is gold because it means money. | Full (ships with the Gilded shader) | [ ] shader not written |
| Wolf | Dungeon lvl 1 grunt (fast, frail). | **Silhouette: low horizontal quadruped** — the level's beast slot; nothing else on lvl 1 stands on four legs. Gray-brown forest wolf; raised hackles spike the back line in idle, full horizontal stretch with bared jaws in the lunging bite. | MVP | [ ] |
| Bandit | Dungeon lvl 1 stock grunt. | Ragged human outlaw, hood/scarf over face, short sword or club. **Outline hook: slouched posture + lumpy layered rags** — soft broken shapes where later humanoid grunts are scaled (Lizardfolk), skeletal (Skeleton), or spiked (Demon Soldier). Attack: overhead swing. | MVP | [ ] |
| Hedge Witch | Dungeon lvl 1 caster. | Hunched crone in patched forest-colored shawl. All four casters share the **bent-figure + raised-implement envelope**; her markers are the crooked gnarled stick and pointed shawl hood. Attack: raises the stick, casting. | MVP | [ ] |
| Bandit King (boss) | Dungeon lvl 1 boss. Drawn larger than grunts (~64px vs 48px in mockup terms). Ability: Cheap Shot (ignores armor). | The Bandit's silhouette made big and wide: the fur mantle doubles the shoulder mass, the stolen crown or feathered hat spikes the top line. Brutal cleaver or twin dirks. Attack: a dirty low stab — a mean lunge, not a noble swing. | MVP | [ ] |
| Lizardfolk Raider | Dungeon lvl 2 stock grunt. | Scaled humanoid in swamp-reed gear with a crude spear or bone club. **Outline hooks: tail, snout, and head-crest** — no other grunt has a tail, so it reads in black fill. Greens and murk-browns, duller than the Slime's leaf green. | Full | [ ] |
| Giant Leech | Dungeon lvl 2 grunt (lifesteal). | **Silhouette: long, low, tapered horizontal** — segmented and ground-hugging, never confusable with the Slime's upright dome. Fat glistening slug-leech, sucker mouth. Attack: rears the front third up to latch. Lifesteal reads via red drain VFX, not the sprite. | Full | [ ] |
| Bog Witch | Dungeon lvl 2 caster. | Swampier sister of the Hedge Witch — same caster envelope; her markers are dripping moss strands that lengthen and soften the outline, plus bog-glow eyes. Palette swap + redress of Hedge Witch is acceptable. | Full | [ ] |
| Swamp Troll (boss) | Dungeon lvl 2 boss. Ability: end-of-round regeneration. | **Silhouette: a wide low mountain** (64px) — hunched mass, knuckles near the ground, head sunk between boulder shoulders. Massive mossy troll, algae-covered hide, dripping club or bare fists. Wounds that visibly close (regen VFX pulses green). | Full | [ ] |
| Skeleton Warrior | Dungeon lvl 3 stock grunt. **Also reused as the Lich's Raise Dead minions.** | Classic skeleton with rusted blade and broken shield, empty sockets. **Outline hook: negative space** — daylight through the ribs and between limb bones makes it the thinnest, most broken grunt outline in the game. Attack: rattling slash. | Full | [ ] |
| Zombie | Dungeon lvl 3 grunt (tanky, slow). | Shambling corpse in grave-dirt clothes. **Outline hook: asymmetry** — one dropped shoulder, a dragged leg, chunks visibly bitten out of the silhouette. Attack: heavy grab/claw. | Full | [ ] |
| Necromancer | Dungeon lvl 3 caster. | Robed figure in black-and-bone, same caster envelope; markers are the skull-topped staff and ragged sleeve points. Green soul-light accents (within the glow budget). | Full | [ ] |
| The Lich (boss) | Dungeon lvl 3 boss. Ability: Raise Dead at half HP. | Skeletal sorcerer-king (64px): the crown fused to the skull spikes the top of the outline; tattered regal robes break the hem into rags. Value focal: the phylactery glow at the chest (glow budget). Attack: channels green-black energy. | Full | [ ] |
| Imp | Dungeon lvl 4 grunt (fast, frail). | **Silhouette: the bestiary's only airborne outline** — a small sharp triangle held off the ground (the code contact shadow grounds it), bat wings and needle tail breaking the edge. Ember-red devil, needle claws, mid-air hover idle. | Full | [ ] |
| Demon Soldier | Dungeon lvl 4 stock grunt. | Man-sized horned demon in charred armor with a jagged blade. **Outline hooks: horns + serrated blade edge** — hard spikes everywhere the Bandit slouches; upright military bearing, unlike every other grunt. | Full | [ ] |
| Flamecaller | Dungeon lvl 4 caster. | Demonic priest, same caster envelope, arms raised; markers are a wreath of flame around head and shoulders (emissive, within the glow budget) and fire runes on the robes. | Full | [ ] |
| Demon Prince (boss) | Dungeon lvl 4 boss and final boss of the game. Ability: Eruption AOE every 3rd turn. | The largest sprite in the game (96px). **Silhouette: tallest and widest by far** — a crown of great horns plus a cape of fire reading as one huge triangular mass; regal upright posture, never hunched. Obsidian skin with molten cracks as the value focal. Attack: slams the ground (pairs with Eruption VFX). | Full | [ ] |
| Gilded trait treatment | Applied to any non-boss enemy (12% spawn, never on day 1). ×2 gold. | **Decided: no dedicated art — shader effect**, parallel to the Hoarder treatment. Whole-sprite gold sheen: luminance-preserving remap of the base sprite's ramps onto the gold accent ramp (`#c9a15a`→`#ffe9b0`), a restrained diagonal glint every ~2.5 seconds, and rare 2-frame coin sparkles. One shader reused for every enemy; counts against the glow budget (style guide §4). Preserve source alpha and shading; no separate outline or glow halo. Full spec: `LordofHirelings_GildedTech.md`. Showcase case: the Golden Slime. | Full | [ ] shader not written |
| Hoarder trait treatment | Applied to any non-boss enemy (5% spawn). ×3 gold, fat and slow. | **Decided: no dedicated art.** Belly-bulge UV shader + code squash, fatness 0.83, idle "heavy bounce" animation; optional coin-purse overlay on top. Reused for all enemies; per-enemy `can_fatten` opt-out. **Asset-side constraint: enemy sprite frames need ~15% transparent padding.** Full spec: `LordofHirelings_HoarderFattenTech.md`, demo: `mockups/hoarder-fatten-demo.html`. | Full | [ ] shader not written |

## 3. Backgrounds & environment

| Name | Description | Visual description | Need | Status |
|---|---|---|---|---|
| Town ground/tileset | The walkable town map: square, paths, grass, fences, props. | Rustic medieval village ground — dirt paths, cobble around the square, grass, small props (crates, barrels, well, lanterns). | MVP | [x] `sprites/town/town_ground_tiles.png` |
| Town horizon backdrop — ruined | Skyline behind the town at game start. | Decrepit ruined town on the horizon: collapsed roofs, leaning chimneys, no lights, gray haze. | Full | [ ] |
| Town horizon backdrop — partially rebuilt (1–2 states) | Horizon improves as the player buys upgrades. | Same skyline with scaffolding, patched roofs, a few lit windows and chimney smoke. | Full | [ ] |
| Town horizon backdrop — prosperous | Max upgrade state. | Rebuilt skyline: whole roofs, banners, many lit windows, warm smoke. | Full | [ ] |
| Inn — level 1 / upgraded / max (3 states) | The only building that starts built. Recruits gather outside it. | Cozy timber-framed tavern with a hanging sign (tankard/bed). Upgrades add a second story, glass windows, banners, flower boxes. | MVP (lvl 1), Full (rest) | [~] lvl 1 only (`sprites/town/inn_lv1.png`) |
| Weapon shop — ruined / normal / upgraded / max (4 states) | Equipment shop, weapon slot. Must read as a forge at a glance. | Smithy: open-air forge glow, anvil, chimney, hanging blades sign. Ruined = collapsed roof and cold forge. Upgrades add bigger forge, more racks, sparks. | MVP (ruined + normal), Full (rest) | [~] ruined + normal in `sprites/town/` |
| Armor shop — ruined / normal / upgraded / max (4 states) | Equipment shop, armor slot. Must read as an armourer. | Armourer's workshop: breastplate-and-shield sign, mannequin in plate outside, riveted door. Upgrades add displayed armor sets, metal-clad roof trim. | MVP (ruined + normal), Full (rest) | [~] ruined + normal in `sprites/town/` |
| Jewelry shop — ruined / normal / upgraded / max (4 states) | Equipment shop, jewelry slot. Must read as a goldsmith. | Goldsmith/jeweller: ring sign, ornate window with glinting display, finer masonry, warm lamp light. Upgrades add gilded trim, gem-glints. | MVP (ruined + normal), Full (rest) | [~] ruined + normal in `sprites/town/` |
| Training grounds — ruined / normal / upgraded / max (4 states) | The fifth building. | Open yard: fence, sparring dummies, archery butt, weapon rack, small shed. Ruined = broken fence and toppled dummy. Upgrades add more equipment and a roofed pavilion. | MVP (ruined + normal), Full (rest) | [~] ruined + normal in `sprites/town/` |
| Graveyard plot + headstones | Non-building interactable. Holds 12 graves; oldest is overwritten. | Small fenced plot with 12 grave positions. 3–4 headstone variants (cross, slab, rounded stone) to mix; fresh-dirt mound state for a new grave. Name renders as text, not art. | MVP | [x] `sprites/town/graveyard_plot.png` + `graveyard_headstones.png` |
| Treasury chest — 3–4 fullness states | The gold readout: proximity prompt shows treasury total. | Iron-banded wooden chest. States: nearly empty (few coins), modest pile, overflowing, and spilling heaps of gold around it as the treasury grows. | MVP (1 state), Full (rest) | [ ] |
| Dungeon entrance | The gateway to the dive; the bell stands beside it. Theme: **abandoned mine**. | Timber-braced mine portal cut into a rocky outcrop, cart tracks running into pitch darkness, cold unlit interior. Weathered support beams; reads as long-abandoned, not industrious. | MVP | [x] `sprites/town/mine_entrance.png` |
| Call-to-arms bell | Interactable next to the dungeon entrance. | Bronze bell on a wooden post or small arch, rope hanging. Rung state = tilted with motion arcs (tween). | MVP | [x] `sprites/town/dungeon_bell.png` |

Both are `SourceArt/tools/generate_mine_entrance.py`. `mine_entrance.png` is 128x128, bottom-center pivot, and stands at the east end of the path arm with its east flank running off the map edge. `dungeon_bell.png` is a 2-cell 32x48 sheet — cell 0 the wooden arch, cell 1 the bell and rope alone, hanging point (16, 10) — because the rung state is a runtime rotation tween around that point rather than a baked frame. Both are made and imported but not yet placed: `scripts/town/dungeon_entrance.gd` and `dungeon_bell.gd` still `_draw()` their placeholders, so swapping each for a Sprite2D (and pivoting the bell's swing on cell 1's hanging point) is what turns these on.

| Town background — day | The town view backdrop during the day (post-crow, expedition-time). | Full daytime version of the town background: bright sky, sun, daylight palette. | MVP | [ ] |
| Town background — night | The town view backdrop at night (rooster usable, adventurers sleep). | Full nighttime version of the same background: dark blue sky, moon and stars, lit windows and lantern glows painted directly into the sprite. Swapped 1:1 with the day background — no code lighting pass. | MVP | [ ] |
| Dungeon biome backdrop — lvl 1 Gentle Forest | Side-scrolling row backdrop for the dive; also cropped as the party-column header in the expedition summary. | Sunny grassy field with scattered trees, soft hills, forest edge. Gentle and green — the "easy" read. | MVP | [x] |
| Dungeon biome backdrop — lvl 2 Swamp | Same usage. | Swampy forest: standing water, hanging moss, dead trees, mist, murky green-brown palette. | Full | [x] |
| Dungeon biome backdrop — lvl 3 Undead Crypt | Same usage. | Underground crypt: stone pillars, sarcophagi, bone piles, cold blue-green torchlight. | Full | [x] |
| Dungeon biome backdrop — lvl 4 Volcanic Hellscape | Same usage. | Volcanic caverns with rivers of lava, basalt spikes, ember rain, red-orange glow. | Full | [x] |

All four biomes are `SourceArt/tools/generate_biome_backdrops.py`, one 320x128 tileable scene each, written out as two crops: `biome_<name>_header.png` (320x64) is live in the expedition summary's party columns; `biome_<name>_row.png` (320x128) is the dive-row backdrop, made and imported but not yet drawn — the dive scene does not exist yet.
| Stairs down | Revealed when a level's boss dies (visual only — never descended). | Stone stairway descending into darkness, fitted to each biome or one neutral version with biome tint. | MVP | [x] `sprites/dungeon/stairs_down.png` |
| Fog of war treatment | Hides the unexplored right side of each dungeon row. | Soft-edged darkness rolling back as the party advances. Can be a shader/gradient; optional pixel-noise edge texture to keep it in style. | MVP (gradient), Later (styled edge) | [x] `sprites/dungeon/fog_of_war_edge.png` (MVP gradient; styled edge still Later) |

Both are `SourceArt\tools\generate_dive_row_overlays.py`. `fog_of_war_edge.png` is 80x128: a 64px alpha ramp to `#101014` plus a 16px solid tail the consumer repeats or stretches out to the row's right edge. Every column is uniform in y, so it takes any row height (the dive splits the screen into up to 3 equal rows) without distortion. `stairs_down.png` is one neutral 64x48 stairway, biome-tinted via `modulate` — the tint values are in the generator's `BIOME_TINTS` and belong in `data/balance.csv` when the dive scene wires them up. Both are made and imported but not yet placed: the dive scene does not exist yet.

## 4. UI — panels, buttons, chrome

| Name | Description | Visual description | Need | Status |
|---|---|---|---|---|
| Generic panel background (9-slice) | Every panel in the game: hero stats, upgrades, summary, tutorials, settings, win screen. | Square-ish parchment-or-dark-wood panel with a sturdy pixel border, subtle inner texture. 9-slice safe. | MVP | [ ] |
| Button (9-slice) — normal / hover / pressed / disabled | Every button. | Chunky pixel button matching the panel trim. Disabled = desaturated; pressed = 1–2px depress. | MVP | [ ] |
| Primary button variant | Emphasized actions (Hire, Rebuild, level-up purchase, Close). | Same 9-slice with a gold/highlight trim. | MVP | [ ] |
| Panel separator line + labeled separator | Section dividers inside panels ("Inventory" label style). | Thin ornamental rule; labeled version has centered small-caps text with rule on both sides. | MVP | [ ] |
| Circle frame | Hangs outside the hero panel's top corners; holds class icon (left) and gold bag (right). | Ringed medallion circle matching panel trim, drop shadow so it reads as hanging off the panel edge. | MVP | [ ] |
| Shield level banner | Shows level under the class circle; also flanks XP bars in the summary. | Small heater-shield shape with room for 1–2 digit number. | MVP | [ ] |
| Proximity prompt background | The only town-view UI: "E — Hire…", "Treasury: X Gold". | Small dark tooltip lozenge with pixel border; must sit legibly over the world. | MVP | [ ] |
| Keycap icon | The "E" (and rebindable key) chip inside prompts. | Tiny keyboard keycap frame that takes a letter. | MVP | [ ] |
| Upgrade pip — empty / filled | Tier progress dots on every upgrade row. | Small round or diamond pip; filled = warm gold, empty = dark socket. | MVP | [ ] |
| Lock icon | Locked upgrade rows and gated tiers. | Small padlock in the UI accent color. | MVP | [ ] |
| Scrollbar (track + thumb, 9-slice) | Expedition summary results area, any overflow. | Slim wooden/metal track with a grippable thumb, in panel style. | MVP | [ ] |
| Horn of Retreat button | The only dive overlay; appears top-right once purchased. | A war horn icon on the standard button chrome; must read at a glance mid-battle. | Full | [ ] |
| HP bar (frame + fill) | Under every combatant in the dive. | Thin bar, red fill on dark track with 1px border. | MVP | [ ] |
| Morale bar (frame + fill) | Under adventurers only (enemies have none). | Same bar in blue, stacked below the HP bar. | MVP | [ ] |
| XP bar (frame + fill) | Expedition summary; loops on multi-level-ups. | Wider bar in gold/green with the shield banners at each end. | MVP | [ ] |
| Turn marker | Yellow ▼ hovering over the acting combatant. | Small bouncing yellow-gold downward chevron/arrow. | MVP | [ ] |
| Defeated-encounter marker | ✕ left behind on the row where a fight was won. | Weathered X — crossed swords or scratched mark, low-contrast so it reads as history, not action. | MVP | [ ] |
| Cower indicator | Shows a panicking adventurer is cowering. | Sweat-drop + trembling lines or a blue spiral over the huddled sprite. | MVP | [ ] |
| Coin pile (progressive) | Expedition summary gold earned: 1 coin drawn per 3–6 gold, up to 100 coins, looking richer as it grows. | Single gold coin sprite (plus 2–3 stack/pile clumps) composed procedurally into an increasingly luxurious heap. | MVP | [ ] |
| Blood splatter + death tint | Summary treatment for dead adventurers (sprite rotated flat, tinted red). | Pixel blood splatter decal under/behind the rotated sprite; red tint is code. | MVP | [ ] |
| Settings controls set | Slider (track + handle), toggle (on/off), dropdown (closed + open), key-rebind row highlight. | All in the same panel/button chrome; slider handle matches pip styling. | Full | [ ] |
| Title screen background | Behind New Game / Continue / Manage Save. | Key art: the ruined town at dusk with the dungeon looming, or the lord overlooking the square. Can start as a plain panel. | Later | [ ] |
| Game logo / title treatment | "Lord of Hirelings" wordmark. | Pixel-lettered title with a gold-coin or hireling-contract motif. | Later | [ ] |
| Win panel flourish | "You Win!" panel shown after conquering level 4. | Standard panel; optional laurel/banner ornament and celebrating-party vignette. Text-only is acceptable per GDD. | Later | [ ] |
| Tutorial panel images ×5 | "Starting Out", "Entering the Dungeon", "Dungeon Runs", "Upgrade Buildings", "Summoning Heroes" use screenshots + arrow/label overlays. | Use temporary scene art or composed placeholders until the matching in-engine screenshot is ready; replace the temporary image with the screenshot later without changing panel layout or text. | Later | [ ] |
| Pixel font | All UI text, floating combat text, prompts. | Pixel Operator regular and bold, CC0 1.0. The included source files live in `lord-of-hirelings/fonts/pixel-operator/`; bold is reserved for CRIT and other high-attention text. | MVP | [x] `lord-of-hirelings/fonts/pixel-operator/` |

## 5. Icons

| Name | Description | Visual description | Need | Status |
|---|---|---|---|---|
| Class icons ×6 | Hero panel circle, hire prompt, anywhere a class is referenced. | One emblem per class on a shared shape language: Knight = shield, Captain = war horn, Berserker = crossed axes, Mage = arcane spark/staff, Rogue = dagger, Cleric = holy book/cross-mace. | MVP | [ ] |
| Stat icons ×12 | Hero panel stat rows. | HP (heart), Power (fist/flexed arm), Morale (banner or resolute face), HP Regen (heart+plus), Morale Regen (banner+plus), Speed (lightning/boots), Armor (breastplate), Guard (raised shield/hand), Evasion (dodge swish), Accuracy (target), Crit (starburst), Crit Damage (bursting star+blade). Single-color glyph style, ~12px. | MVP | [ ] |
| Gold bag icon | Hero panel wealth circle. | Tied coin pouch with a coin peeking out. | MVP | [ ] |
| Coin icon | Costs on buttons, treasury prompt, commissions. | Single gold coin, embossed face. | MVP | [ ] |
| Item icons — first pass ×18 | One per class per slot (6 classes × 3 slots), reused across tiers; name text conveys tier. | Weapon, armor, and jewelry icons matching each class's item tables (e.g. Knight: longsword / plate chest / belt; Mage: wand-staff / robes / amulet; Rogue: dagger / leathers / ring). Jewelry must visibly distinguish **belt (Knight), ring (Berserker, Rogue), amulet (Captain, Mage, Cleric)**. | MVP | [ ] |
| Item icons — full set ×108 | Per class per slot per tier (6 × 3 × 6, tiers 0–5), matching the naming tables in the balance doc. | Tier progression reads at a glance: tier 0 = rusted/cracked/frayed, mid tiers = solid and polished, tier 5 = unique glowing named relic (Dawnbreaker, Cataclysm, Quietus…). | Later | [ ] |
| Building icons ×5 | Upgrade panel titles (inn, weapon, armor, jewelry, training). | Miniature emblem of each building: tankard sign, anvil, breastplate, ring, sparring dummy. | Full | [ ] |

## 6. VFX & projectiles

Most motion is code-tweened; these are the sprite/particle assets the tweens need.

| Name | Description | Visual description | Need | Status |
|---|---|---|---|---|
| Floating combat text styles | Damage, MISS, CRIT -X!, +X heals popping over targets. | Font styling + colors: red damage, gray MISS, large gold CRIT with punch-scale, green heals. Rendering is code; needs the bold font + outline treatment. | MVP | [ ] |
| Melee hit spark | Every landed physical attack. | 2–4 frame white-gold impact star with small debris pixels. | MVP | [ ] |
| Block/guard flash | Attack absorbed by guard. | Brief shield-shaped blue-white flash in front of the defender. | MVP | [ ] |
| Mage AOE bolt | The Mage's volley hitting every enemy at once. | Elemental projectile (arcane fire) that fans/splits across all enemies, with a small per-target burst. One damage roll — one shared color flash. | MVP | [ ] |
| Enemy caster bolt ×4 flavors | Hedge Witch, Bog Witch, Necromancer, Flamecaller attacks. | One base magic bolt recolored/redressed per biome: thorn-green, bog-murk, soul-green/black, flame-orange. Small travel trail + impact puff each. | MVP (1), Full (4) | [ ] |
| Cleric heal | Heal on the lowest-HP ally. | Soft golden glow rising off the target with cross/spark motes; pairs with green +X text. | MVP | [ ] |
| Cleric Blessing | +armor buff when everyone is full HP. | Brief golden shield-outline shimmer settling onto the ally. | Full | [ ] |
| Captain Rallying Horn | Every-3rd-turn party buff: morale restore + power buff. | Horn-blast ring expanding from the Captain, brief banner-gold flash on each ally; buffed allies get a small +power pip (see status icons). | Full | [ ] |
| Knight Shield Bash / guard-up | His attack doubles his guard through next turn. | Shield slam impact plus a lingering faint shield-aura outline on the Knight while the buff holds. | Full | [ ] |
| Berserker Frenzy indicator | Passive +power below 50% HP. | Red rage wisps / steam rising from the sprite while active. | Later | [ ] |
| Status effect pips | Generic over-sprite indicators for buffs/debuffs with durations. | Tiny icons above the bar area: +power (red fist), +armor (gold shield), regen (green drops). Shared system, ~8px. | Full | [ ] |
| Death sequence support | Flash red, fall over, fade (all code) — plus a dust/soul puff. | Small dust burst on the fall; crypt/demon enemies may get a wisp instead. | MVP (code only), Later (puff) | [ ] |
| Lich Raise Dead | Once per fight below half HP, summons 2 Skeleton Warriors. | Green-black ground sigils; skeletons rise from them with dirt/bone particles. | Full | [ ] |
| Demon Prince Eruption | Every-3rd-turn party-wide AOE. | Ground slam, lava cracks racing under the whole party, fire columns bursting up beneath each member. | Full | [ ] |
| Swamp Troll regeneration | End-of-round self-heal. | Green knitting-flesh pulse over the troll + green +X text. | Full | [ ] |
| Giant Leech lifesteal | Heals for damage dealt. | Thin red streak flowing from victim to leech. | Full | [ ] |
| Coin drop sparkle | Enemies dropping gold to the adventurers. | Coins burst from the dying enemy, arc, and wink out with a glint. | Full | [ ] |
| Level-up flourish | Expedition summary when the XP bar rolls over. | Gold burst around the shield banner as the number increments; short shine sweep on the bar. | MVP | [ ] |
| Sunrise / crow transition | Rooster crow brings the sun up and starts the day. | Code crossfade from the night background sprite to the day background sprite; musical-note or crow-lines burst from the rooster. No dedicated transition art beyond the two backgrounds. | Full | [ ] |
| Nightfall transition | After the summary closes, night falls. | Code crossfade from the day background sprite to the night background sprite. No dedicated transition art. | Full | [ ] |
| Bell ring effect | Call to arms. | Ring arcs off the bell + a brief screen-wide rally cue (banner flash). | Full | [ ] |
| Celebration effect | Party celebrates on conquering the final level. | Confetti pixels / thrown hats / cheering jump tweens over the party. | Full | [ ] |
| Speech/emote bubbles | Town flavor: chatting, graveyard "I miss you, X", sleep Zzz, eating, working out. | Small pixel speech bubble that fits one short line, plus emote glyphs: 💤 Zzz, chat dots, food, dumbbell, heart-break (graveyard). | Later | [ ] |

---

## Counts at a glance

- **MVP (first playable loop, dungeon level 1 only, 1 variant per class):** ~67 discrete assets — 8 characters, 5 enemies (10 poses; the green Slime opens the tutorial fight), town map + inn + 4 ruined/normal shells + interactables, 1 biome, panel/button chrome, ~37 icons, ~8 effects.
- **Full design as written:** roughly 175–200 discrete images (30 adventurer variants, 36 enemy images — 34 drawn poses plus the blue Slime recolor; both gold-trait treatments are shaders, not images — ~19 building states, 4 biomes, horizon states, full VFX set, 18-icon item pass).
- **Max (108-item icon set, title key art):** ~300.

## Known gaps blocking art (not blocking iteration)

1. ~~**No style reference sheet.**~~ **Resolved** — see `LordofHirelings_ArtStyleGuide.md`: 960×540 native at integer scale, 48px character sprites (64px bosses, 96px Demon Prince), 16px town tiles, Apollo-based palette + the mockup UI ramp, selective hue-shifted outlines on sprites only, top-left global light.
2. ~~**Dungeon entrance theme is explicitly TBD**~~ **Resolved** — the dungeon is an abandoned mine (see the entrance row above and the GDD).
3. ~~**Tutorial images are in-engine screenshots.**~~ **Resolved** — use temporary composed scene art until the matching screenshot is ready, then replace it without changing panel layout or copy.
4. ~~**The Gilded shader has no tech spec yet.**~~ **Resolved** — see `LordofHirelings_GildedTech.md` for the luminance remap, glint cadence, sparkle budget, and shader constraints.
