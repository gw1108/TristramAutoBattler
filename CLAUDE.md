# Claude.md

The role of this file is to describe common mistakes and confusion points that agents might encounter as they work in this project. If you ever encounter something in the project that surprises you, please alert the developer working with you and indicate that this is the case in the AgentMD file to help prevent future agents from having the same issue.

---

## Operating Principles (Non-Negotiable)

- If something is described or asked for do not ask for confirmation.
- **Do NOT invent player-facing features, mechanics, or "flavor" that are not described in the design documents (`design`).** If you think a feature or flavor pass would improve the game, write it up as a suggestion in the suggested-features file.
- **Tunable numbers belong in `data/balance.csv`, NOT in `.gd` constants.** Any scalar someone might want to tweak while balancing or art-passing the game — player move speed, enemy/player/projectile sprite scale, light radii, damage, cooldowns/intervals, spawn pacing, projectile speed/lifetime — must be read through `BalanceData.get_value("<id>", <default>)`. For example: `static var BASE_SPEED := BalanceData.get_value("fire_ball_base_speed", 300.0)` — the CSV row is the source of truth; the second argument is only a missing-row fallback (keep the two in sync when you add the row). A `const` is acceptable only for genuine non-tunables: file/texture, colors, shader source, protocol/schema versions, sprite-sheet grid geometry, and structural/tabular data that already lives in its own CSV (`*_levels.csv`, wave/boss CSVs).
When you touch code that still hardcodes a tunable, migrate that value to `balance.csv` as part of your change. (`get_value` returns floats only — non-scalar tunables like a Vector2 get one row per component or a single uniform-scale row.)
- **Dev/debug tooling is the exception:** it is fine to add tooling that makes debugging, testing, or authoring easier (agent-play harnesses, debug overlays, cheat toggles, etc.),

---

## Project Structure

Do NOT scan files in the /thoughts/ folder unless specified.
Do NOT scan files under any folder named ARCHIVE unless specified.
Do NOT scan workshop transcript files unless specified.

### Where things are (Project Map)

This is Godot 4.7

**`lord-of-hirelings/`** — the actual Godot project (open *this* folder in the editor, not the repo root).
- `addons/*` — addons and plugins go here. Don't edit or read this unless specified.
- `test/` — test suites live here. New `*_test.gd` go here. (See Testing philosophy below — tests are optional.)
- `reports/*` — generated gdUnit4 HTML/XML test reports. Generated output, not source.
- Game source (scenes `.tscn`, scripts `.gd`, resources) will live under this folder.

**Design, planning & research:**
- `design` — the Game Design Document(s). Source of truth for what to build.

**Art:**
- `SourceArt/*` — Art assets and audio assets which do not need to be opened or reasoned over unless specified or fetching art assets.

**Visual / rendering rules:**
- `VISUAL_RULES.md` (repo root) — **this is a pixel-art game.** Read it before importing or rendering any texture, sprite, or VFX.

---

## Testing & Verification Philosophy

Tests are **not required**. Do not use TDD / test-first / red-green-refactor on this project.

**Unit testing framework: gdUnit4** is installed (at `lord-of-hirelings/addons/gdUnit4/`) and is the framework to use when tests *are* written. Test scripts are named `*_test.gd` and live in `lord-of-hirelings/test/`. See `lord-of-hirelings/test/smoke_test.gd` for a minimal example suite.

- **Implementation and tuning come first.** Build the feature, then tune its numbers by feel — game rules and balance are discovered by playing, not specified up front.
- **Tests emerge from play and from regressions, not from process.** Write a test when:
  - playtesting (with agents or with humans) surfaces behavior worth pinning down, or
  - a regression is detected and you want to keep it from recurring.
- **Never propose writing a test before the implementation** for this project.
- Feel, balance, and "is it fun" are verified by running and playing the game, not by assertion.

---

## Workflow Orchestration

### 1. Subagent Strategy (Parallelize Intelligently)
- Use subagents to keep the main context clean and to parallelize:
  - repo exploration, pattern discovery, test failure triage, dependency research, risk review.
- Give each subagent **one focused objective** and a concrete deliverable:
  - "Find where X is implemented and list files + key functions" beats "look around."

### 2. Incremental Delivery (Reduce Risk)
- Prefer **thin vertical slices** over big-bang changes.

### 3. Self-Improvement Loop
- After any user correction or a discovered mistake, add a new entry to `tasks/lessons.md`. `tasks/lessons.md` is the catch-all log — always record there first.
- Then, if the lesson is durable project knowledge tied to specific code or tooling (a tool gotcha, a setup step, a convention, an API quirk), **ask the user whether it should be promoted to a more permanent home** next to what it concerns — e.g. the relevant skill, a README, or this file. Durable knowledge lives beside the code; `lessons.md` keeps the process/meta lessons. Leave it in `lessons.md` if the user declines or it's a one-off process note.
- Keep each entry minimal: a short **category header** (e.g. `### Research scoping`) plus a **one-line prevention rule**. Nothing else.
- The category lets future agents skim and skip entries that look unrelated without reading the body. If a rule needs more context to be actionable, the category itself is too broad.
- Before adding a new entry, check if an existing category already covers it; extend or refine that line instead of duplicating.
