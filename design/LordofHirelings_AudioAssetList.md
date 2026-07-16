# Lord of Hirelings — Audio Asset List

This is the source of truth for music, ambience, UI, and SFX. All durations are the delivered asset
length, not the time an implementation may hold or loop it. Export game-ready files as OGG Vorbis at
48 kHz; retain 24-bit WAV masters outside the game build. Keep gameplay SFX mono so positional town
audio can pan; music and ambience beds may be stereo.

Need: **MVP** = needed for the first playable loop (town + dungeon level 1). **Full** = needed to ship
the written design. **Later** = can use an existing generic cue until the dedicated asset is made.

## 1. Music

| Asset | Situation played | Duration | Audio direction | Need |
|---|---|---:|---|---|
| Title theme | Title screen; restarts only after its tail ends. | 75-105 s seamless loop | Sparse, worn medieval melody; promise warmth without sounding triumphant. | Later |
| Town night | Night town phase; fades in after the summary/win panel closes. | 75-105 s seamless loop | Quiet lute/woodwind, soft distant lantern-town life; restful but a little melancholy. | MVP |
| Town day | Day town phase after the rooster transition. | 75-105 s seamless loop | Brighter variation of the night theme with hand percussion and a modest forward pulse. | MVP |
| Forest dive | Dungeon level 1 row scene. | 75-105 s seamless loop | Gentle but tense woodland rhythm; leaves space for turn SFX and combat text. | MVP |
| Swamp dive | Dungeon level 2 row scene. | 75-105 s seamless loop | Wet, slow, uneasy low strings and hollow percussion. | Full |
| Crypt dive | Dungeon level 3 row scene. | 75-105 s seamless loop | Cold drones, bone-like percussion, restrained choral texture. | Full |
| Hellscape dive | Dungeon level 4 row scene. | 75-105 s seamless loop | Heavy low percussion, furnace drones, tense rising figure. | Full |
| Victory sting | Final dungeon boss falls, before the win panel. | 4-6 s | Brief earned resolution of the town motif; celebratory, not orchestral. | Full |
| Endless-tier sting | An expedition raises endless tier. | 1.5-2.5 s | Short, darker upward coin-and-metal flourish. | Later |

## 2. Ambience and town movement

| Asset | Situation played | Duration | Audio direction | Need |
|---|---|---:|---|---|
| Town night ambience | Low bed beneath night music; moonlit town, sleeping hirelings. | 20-35 s seamless loop | Crickets, low wind, occasional distant creak; no constant animal calls. | MVP |
| Town day ambience | Low bed beneath day music. | 20-35 s seamless loop | Light birds, breeze, distant town activity; calm enough for UI reading. | MVP |
| Lord footsteps: dirt/cobble | Looped or stepped while the Lord walks in town, selected from surface. | 0.18-0.28 s per step | Soft leather boots; dirt is muffled, cobble is a little sharper. | MVP |
| Adventurer footsteps | Background movement in town; lower volume and randomized pitch. | 0.18-0.28 s per step | Lighter leather/cloth steps, less prominent than the Lord. | Full |
| Rooster idle | Occasional spatial town sound while the rooster is visible at night. | 0.5-0.9 s | Soft rustle/cluck; infrequent. | Full |
| Rooster crow | Player starts the day. | 1.8-2.8 s | Clear three-part crow with a small wing flutter; it must cut through music. | MVP |
| Bell ring | Player calls to arms. | 2.5-4.0 s tail | Heavy bronze bell with one strong strike and decaying town-space resonance. | MVP |
| Treasury coin shift | Player enters the chest readout radius. | 0.35-0.6 s | Subtle coins settling; rate-limit so pacing around the chest cannot spam it. | Full |
| Shop forge bed | Spatial ambience near the weapon shop when rebuilt. | 4-7 s loop | Low forge fire with a rare muted hammer. | Full |
| Graveyard wind | Spatial ambience near the graveyard. | 3-5 s loop | Thin wind and a faint wooden creak; no horror jump scare. | Full |
| Mine wind | Spatial ambience near the dungeon entrance. | 3-5 s loop | Cold, hollow draft and a faint distant rock tick. | Full |

## 3. UI, town actions, and economy

| Asset | Situation played | Duration | Audio direction | Need |
|---|---|---:|---|---|
| UI hover/focus | Pointer or keyboard focus enters a button or actionable row. | 0.04-0.08 s | Very soft wood/metal tick. | MVP |
| UI confirm | Valid button press: Close, Hire, purchase confirmation. | 0.08-0.15 s | Warm, concise click. | MVP |
| UI disabled | Player presses a disabled or unavailable control. | 0.12-0.2 s | Dry low tick; informative, never harsh. | MVP |
| Panel open | Hero, upgrade, tutorial, settings, summary, or win panel appears. | 0.18-0.3 s | Parchment/wood unfold with a small UI chime. | MVP |
| Panel close | A panel closes. | 0.12-0.22 s | Short inverse of panel open. | MVP |
| Hire adventurer | Normal hire completes and recruit joins town. | 0.5-0.8 s | Coin pouch handoff plus a small affirmative flourish. | MVP |
| Sponsor adventurer | Hire and Sponsor completes. | 0.7-1.0 s | Richer coin handoff than normal hire, ending in the same affirmative flourish. | MVP |
| Building rebuild | A ruined building becomes level 1. | 1.5-2.5 s | Hammering, timber lift, then a warm completion chord. | MVP |
| Building upgrade | Any building gains a later level. | 0.9-1.5 s | Shorter construction rise and completion hit. | MVP |
| Upgrade pip purchase | Any upgrade-tree pip purchase succeeds. | 0.35-0.55 s | Small gold notch/metal click. | MVP |
| Shop purchase | Adventurer buys one equipment tier automatically. | 0.45-0.75 s | Coin handoff and appropriate light trade sound; do not play more than once every 0.4 s globally. | MVP |
| Commission received | The player receives a sales commission. | 0.2-0.35 s | Quiet single coin chime, mixed below shop purchase. | Full |
| Tax-copy received | Expedition resolution awards the player treasury tax-copy. | 0.6-0.9 s | Measured coin cascade, one cue for the total rather than one per drop. | MVP |
| Party formation | Bell resolves into parties. | 0.8-1.2 s | Boots gathering, shield/weapon readiness, brief rally cue. | Full |
| Kick or Swap | A valid formation action completes. | 0.3-0.5 s | Shuffle of gear/boots and a decisive UI click. | Full |
| Horn of Retreat | Player presses retreat. | 1.5-2.5 s | Urgent war-horn blast, distinct from the Captain's smaller Rallying Horn. | Full |

## 4. Core dungeon combat

| Asset | Situation played | Duration | Audio direction | Need |
|---|---|---:|---|---|
| Party dungeon walk | A party advances into a level or between fights. | 3-4 s loopable bed | Mixed boots and gear, matching the four-second travel animation; fades out on interception. | MVP |
| Enemy intercept | Enemies enter and stop a party. | 0.45-0.75 s | Short hostile stinger: rustle/weapon-ready, no spoken vocalization. | MVP |
| Melee swing | Knight, Captain, Berserker, Rogue, Bandit, Wolf, or other physical attacker begins an attack. | 0.12-0.22 s | Flexible cloth/weapon whoosh; pitch-varied. | MVP |
| Melee hit | A landed physical attack deals HP damage. | 0.12-0.22 s | Dry impact with a very light metal layer when appropriate. | MVP |
| Miss | An attack fails its accuracy/evasion check. | 0.12-0.2 s | Clean swish past the target. | MVP |
| Guard block | An attack is absorbed by guard. | 0.2-0.35 s | Shield/armor ring with a blunt stop. | MVP |
| Critical hit | A landed critical attack is confirmed. | 0.25-0.4 s | Bright, sharp metal-and-gold accent layered over the hit. | MVP |
| Enemy damage voice/body | Any hero takes a landed enemy hit. | 0.18-0.35 s | Restrained exertion/grunt or cloth impact; randomized so it never becomes a bark loop. | Full |
| Hero death | A hero reaches 0 HP and falls. | 0.8-1.2 s | Heavy fall and brief fading breath/armor settle; serious, not gory. | MVP |
| Enemy death | A normal enemy reaches 0 HP. | 0.35-0.65 s | Short body-specific collapse; forest version covers Slime, Wolf, Bandit, and Witch for MVP. | MVP |
| Boss death | Any boss reaches 0 HP. | 1.5-2.5 s | Larger collapse with a resolved tail; Demon Prince may layer lava crack. | Full |
| Cower | A hero panics but remains in the dungeon. | 0.4-0.7 s | Breath catch, small tremble/gear rattle. | MVP |
| Flee | A hero panic-flees or the retreat horn resolves. | 0.6-1.0 s | Fast retreating steps fading left. | MVP |
| Stalemate withdrawal | The three-round no-damage rule forces a party out. | 0.8-1.2 s | Deflated retreat cue; distinct from panic. | Full |
| Coin drop | A dead enemy awards personal gold. | 0.25-0.45 s | A few coins pop and settle; aggregate simultaneous drops per battle beat. | MVP |
| Level up | Summary XP bar crosses a level boundary. | 0.75-1.1 s | Warm ascending coin/metal flourish; safe to repeat for multiple levels. | MVP |

## 5. Class, enemy, and boss ability SFX

| Asset | Situation played | Duration | Audio direction | Need |
|---|---|---:|---|---|
| Knight Shield Bash | Knight attacks and gains guard. | 0.35-0.55 s | Shield slam with a protected metallic ring. | Full |
| Captain Rallying Horn | Captain's every-third-turn morale/power buff. | 0.8-1.2 s | Compact brass horn and a warm banner-like rise; clearly smaller than retreat horn. | Full |
| Berserker Frenzy | Berserker first crosses below half HP. | 0.35-0.6 s | Low rage breath and weapon-grip scrape; play once per activation. | Later |
| Mage AOE bolt | Mage begins its all-enemy volley. | 0.5-0.8 s | Arcane ignition and splitting travel sound. | MVP |
| Mage AOE impacts | Mage volley strikes every valid target. | 0.15-0.25 s each, capped | Crisp arcane impacts; cap/layer simultaneous hits to avoid noise. | MVP |
| Cleric heal | Cleric restores HP. | 0.6-0.9 s | Clean soft chime and upward shimmer. | MVP |
| Cleric Blessing | Cleric buffs armor when all allies are full HP. | 0.45-0.7 s | Short gold-shield shimmer. | Full |
| Enemy caster bolt | Hedge Witch attack; recolor/revoice by biome later. | 0.5-0.8 s | Thorny arcane cast and projectile travel. | MVP (Hedge Witch) |
| Enemy caster impact | Caster bolt lands on a hero. | 0.18-0.32 s | Sickly magical hit, mixed with damage impact. | MVP (Hedge Witch) |
| Bandit King Cheap Shot | Boss attack ignores armor. | 0.35-0.55 s | Dirty low stab with a threatening scrape. | MVP |
| Giant Leech lifesteal | Giant Leech heals from actual damage dealt. | 0.35-0.55 s | Wet suction plus a short reverse-health shimmer. | Full |
| Swamp Troll regeneration | End of round when the Troll restores HP. | 0.6-0.9 s | Wet stone-and-flesh knitting pulse; no gore emphasis. | Full |
| Lich Raise Dead | Lich first crosses below half HP and summons skeletons. | 1.2-1.8 s | Grave-earth rumble, green-black rise, bone rattle. | Full |
| Demon Prince Eruption | Demon Prince's every-third-turn party AOE. | 1.0-1.6 s | Heavy ground slam, lava crack sweep, multiple fire bursts. | Full |

## Counts at a glance

- **MVP:** 5 music/ambience loops, 17 town/UI/economy cues, 13 core-combat cues, and 5 level-1 ability/boss cues — approximately **40 delivered assets** before harmless pitch variations.
- **Full design:** add the remaining biome loops, spatial ambience, class abilities, enemy signatures, bosses, title/victory/endless cues, and body-specific deaths — approximately **70-80 delivered assets**.
- Reuse should be intentional: color/VFX may change an enemy caster bolt by biome, but its core timing remains shared; never reuse the retreat horn for Rallying Horn or the bell.
