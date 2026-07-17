# Goal: Build Lord of Hirelings

Build **Lord of Hirelings**, a 2D pixel-art auto battler / town builder / incremental RPG, in **Godot 4.7**. The playable game is the deliverable: town phase (hiring, upgrades, wandering adventurers), call to arms and party formation, the 4-level dungeon dive with turn-based auto battles, the two-tax economy, the win condition, and endless mode.

## Source of truth

The design documents in `design/` fully specify the game. Do not invent player-facing features, mechanics, or flavor that are not in them.

- `design/LordofHirelings_GameDesignDocument.md` — the master GDD (game loop, town, combat, economy, UI panels).
- `design/LordofHirelings_BalanceNumbers.md` — stats, formulas, ability rules, tuning anchors.
- `design/LordofHirelings_ArtStyleGuide.md` and `design/LordofHirelings_ArtAssetList.md` — how everything should look and what assets exist.
- `design/LordofHirelings_GildedTech.md` and `design/LordofHirelings_HoarderFattenTech.md` — enemy gold-trait tech specs.
- `mockups/` — HTML mockups referenced by the GDD (hero panel, dungeon HUD). Match them.

Also binding: tunables go in `data/balance.csv` via `BalanceData.get_value`, testing philosophy, project map and `VISUAL_RULES.md` (pixel-art rendering rules — read it before importing or rendering any texture, sprite, or VFX).

## Scope for this phase

- **In scope: game code** — the Godot project lives in `lord-of-hirelings/` (open that folder, not the repo root).
- **In scope: AI-generated art** — generate the sprites, tiles, portraits, icons, and UI art the game needs per the art style guide and art asset list. Prefer transparent-background generation for sprites/icons.
- **Out of scope: audio.** Do not implement audio systems, buses, or playback code, and do not generate or source any audio assets, even though `design/LordofHirelings_AudioAssetList.md` exists. Audio comes in a later phase.

## Environment notes

- The `agent_play/` harness exists for agent-driven playtesting of the running game; use it when verifying feel/behavior end-to-end.

## Working style

- Thin vertical slices: prefer a small playable increment (e.g. "rooster crow starts the day and recruits appear") over broad scaffolding.
- Placeholder art is acceptable to unblock code, but replace it with generated art that follows the style guide as the relevant task.
- Tests are optional and never come before the implementation; verify by running the game.