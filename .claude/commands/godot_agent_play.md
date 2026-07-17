---
name: godot_agent_play
description: Set up and run an AI agent that plays any 2D Godot 4 WebGL game in a browser — sending inputs, reading game state, and observing visuals in a closed loop. Swappable personalities find bugs (incl. an Edgar-Allan-Poe-voiced variant), evaluate art direction, visual scale/legibility, juiciness (game feel), and audio, and assess design for new and experienced players. Wires a generic JavaScriptBridge into the game and drives it with the agent_play/ toolkit (autonomous harness or interactive Playwright MCP).
model: sonnet
---

# Godot Agent Play

You set up and run an AI agent that **plays a 2D Godot 4 WebGL game in a browser** in a closed
loop — **send inputs → read game state → observe visuals → decide → repeat** — so the agent can
find bugs and evaluate art direction, juiciness (game feel), and audio coverage.

This works for **any** 2D Godot game, not just the one in this repo. A canvas/WebGL game exposes
no game state to the DOM, so the game must deliberately publish a JSON snapshot to the page via
Godot 4's `JavaScriptBridge`; a Playwright-driven harness reads it and sends inputs back over a JS
control channel; screenshots feed Claude's vision for visual/feel review.

The reusable pieces all live in `agent_play/` (toolkit) — the bridge template, server, autonomous
harness, oracles, and personality prompts — and are repo-agnostic (the toolkit auto-detects the
Godot project). Your job is to wire up the **target game** (if not already), build and serve it,
and run a personality — or hand the live game to an interactive driver.

## Starting point

The parameter (optional) names the personality to run (default `bug-hunter`). Personalities:
- `bug-hunter` — adversarial QA: crashes, softlocks, logic & visual bugs.
- `bug-hunter-poe` — same mission, but thinks/writes in the voice of Edgar Allan Poe.
- `art-director` — visual composition, palette, contrast/readability, consistency.
- `visual-scale` — sizing/scale/visibility: is everything correctly scaled and legible?
- `juiciness` — game feel: feedback density, screenshake, particles, sfx-to-action timing.
- `audio` — sound coverage & timing (events + WebAudio probe; not a listening test).
- `new-player` — onboarding / first-time UX: can a weak player learn and progress without harsh punishment?
- `experienced-player` — depth & challenge for skilled players: skill ceiling, replayability.

The toolkit finds the Godot project automatically (the one
directory with a `project.godot` at the repo root or one level below; override with
`AGENT_GODOT_PROJECT` or `agent_play/agent_play.config.json`). If that project already has
`scripts/agent/agent_bridge.gd` and an `AgentBridge` autoload, skip to Step 2; otherwise start at
Step 1. Throughout, `<game>` means that Godot project directory.

## Quick start (automated installer)

For most setups, run the installer first — it does everything mechanical and is idempotent:

```bash
node agent_play/setup.mjs        # add --project <dir> if the repo has several Godot projects
```

It runs `npm install`, downloads Chromium, detects (or lets you pick) the Godot project, gitignores
`.env` and verifies the Claude Code CLI (the harness bills to your subscription via `claude -p` — no
API key), installs this skill
into `.claude/commands/`, adds the Playwright MCP server to `.mcp.json`, and wires the `AgentBridge`
autoload + bridge script into the game. The **one** thing it can't do is write the game-specific
adapter (Step 1.3–1.5 below) — it prints exactly what's left. After the installer + adapter, jump to
Step 2.

The numbered steps below are the manual/explanatory version of what the installer automates.

## Steps

### 1. Wire the AgentBridge into the target game (one-time per game)

Skip if the game already has `scripts/agent/agent_bridge.gd` and an `AgentBridge` autoload.

1. Copy `agent_play/templates/agent_bridge.gd` to `<game>/scripts/agent/agent_bridge.gd`. It is
   generic — do not edit it.
2. Register the autoload in `<game>/project.godot`:
   ```ini
   [autoload]
   AgentBridge="*res://scripts/agent/agent_bridge.gd"
   ```
3. Copy `agent_play/templates/agent_adapter.example.gd` and write a game-specific adapter that
   maps the game's internal state onto the contract (see "The contract" below). Map the game's
   lifecycle enum onto `menu|playing|paused|game_over|loading`, compute `available_actions` for the
   current phase, and convert every `Vector2/Vector2i` to an `[x, y]` array.
4. Register the provider from the game's main controller `_ready()`:
   ```gdscript
   AgentBridge.register_provider(_provide_agent_state)   # func() -> Dictionary
   ```
5. Add a few additive `AgentBridge.emit_event(...)` calls at gameplay moments (score, death,
   spawn, `sfx_played`, `music_changed`, `screen_shake`, `particle_burst`) — these are what make
   the juiciness/audio/bug personalities effective.
6. (Optional) `AgentBridge.register_command_handler(...)` to support `set_seed` (determinism),
   a custom `restart`, or `step`. Without it, the bridge synthesizes `InputEventAction`s so the
   game's existing input code works unchanged, and `restart` reloads the scene.
7. Add a release-safe **"Web-Agent"** export preset to `export_presets.cfg` with
   `custom_features="agent"` so the bridge only activates in builds you intend for agents. (In dev
   you can skip this and just append `?agent=1` to the URL.)
8. Verify it compiles: `godot --headless --path <game> --import` (per CLAUDE.md). Fix any GDScript
   errors before continuing.

### 2. Export the web build

```powershell
godot --headless --path <game> --export-release "Web" <ABSOLUTE-path>/build/web/index.html
```
or run the repo's `build_scripts/export_web.bat`. (The harness does this for you by default; use
`--no-export` to skip when already built.) Pass an **absolute** output path — with `--path` a
relative path resolves against the project dir and fails `Target folder does not exist` — and the
output folder must already exist (create it first; Godot won't). See `agent_play/README.md` gotchas.

### 3. Install the toolkit (one-time)

The installer (Quick start, above) already does this. Manual equivalent:
```bash
cd agent_play
npm install
npx playwright install chromium
```
Ensure the Claude Code CLI is installed and logged in (`claude /login`) with your Pro/Max subscription — the harness bills game-play LLM calls to it via `claude -p`. No `ANTHROPIC_API_KEY` is required.

### 4a. Run a personality autonomously (unattended)

```bash
node agent_play/harness.mjs --personality bug-hunter --steps 120 [--seed 123] [--headed] [--no-export]
```
The harness exports (unless `--no-export`), serves with the right headers, launches Chromium,
freezes the game while Claude thinks (`time_scale=0`), reads state/events, screenshots on the
personality's cadence, runs the generic oracles, decides + executes an action, and writes a report.

### 4b. Or drive interactively via the Playwright MCP server

Use this to explore the live game yourself / in a Claude Code session.
1. Start the server: `node agent_play/server.mjs` (serves the build with COOP/COEP).
2. With the `playwright` MCP server configured (it is, in `.mcp.json`), navigate and drive:
   - `browser_navigate` → `http://localhost:8099/index.html?agent=1`
   - read state: `browser_evaluate(() => window.__agentStateJson)` and
     `browser_evaluate(() => window.__agentEventsJson)`
   - send commands: `browser_evaluate(j => window.__agentControl.send(j), '{"type":"tap","action":"ui_accept"}')`
   - look: `browser_take_screenshot`
   Same contract as the harness — just a human/agent in the loop.

### 5. Read the report

The autonomous run writes `agent_play/runs/<timestamp>-<personality>/`:
- `findings.md` — the personality's summary (bug list / art scorecard / juiciness scorecard /
  audio coverage matrix) plus all findings sorted by severity.
- `session.jsonl` — full per-step trace (state, action, events, oracle trips).
- `screenshots/` — frames captured during the run.

Read `findings.md`, then iterate on the game and re-run.

## The contract (what the adapter must publish)

`AgentState` (published as JSON to `window.__agentStateJson` each frame):
- `meta` (the bridge fills `protocol/frame/dt/time/game_id/version`; you may add `tick`)
- `phase`: one of `menu|playing|paused|game_over|loading`
- `player`: `{ pos:[x,y], velocity?, facing?, health?, lives?, alive, extra? }` (may be null)
- `score`, `best?`
- `entities[]`: uniform `{ id, type, pos:[x,y], state }`
- `world`: `{ coordinate_space:"grid"|"pixels", bounds:{min:[x,y],max:[x,y]}, grid?, cell_size?, camera? }`
- `available_actions[]`: the InputMap actions legal in the current phase

Events (separate, bounded, seq-numbered, to `window.__agentEventsJson`): emit via
`AgentBridge.emit_event(type, data)`. Canonical types: `score_changed`, `damage`, `heal`,
`spawn`, `despawn`, `death`, `level_up`, `phase_changed`, `sfx_played`, `music_changed`,
`screen_shake`, `particle_burst`.

Commands (`window.__agentControl.send(jsonString)`): `press`/`release`/`tap` (with `action`),
`set_time_scale` (0 = freeze), `ack_events`, `restart`, `set_seed`, `step`.

## Notes

- **JavaScriptBridge exists only on web exports.** The bridge guards everything with
  `OS.has_feature("web")` and is inert in the editor/desktop and in ungated public web builds.
- **Freeze while thinking.** The harness sets `time_scale=0` before each decision and restores it
  after — without this, a realtime game outruns the agent. `_process` still runs at `time_scale 0`,
  so the bridge keeps publishing state and accepting commands.
- **COOP/COEP headers** are required only for threaded exports (SharedArrayBuffer), but `server.mjs`
  sends them always (harmless otherwise). A plain `python -m http.server` will NOT send them and a
  threaded build will fail to boot. Godot's `ensure_cross_origin_isolation_headers` only affects a
  PWA service worker, not a plain static server.
- **Audio is the lowest-confidence personality.** A headless browser is silent and Claude has no
  ear; the audio-evaluator reviews *coverage and timing* from `sfx_played`/`music_changed` events
  and the WebAudio probe, explicitly NOT how anything sounds. Note the probe is engine-aware:
  Godot mixes all audio in one AudioWorklet, so the probe shows the **AudioContext lifecycle**
  (proving audio initialized), NOT one entry per SFX — per-sound coverage comes from the game's
  events. (Games that play discrete WebAudio nodes additionally get per-sound probe entries.)
  This is why emitting `sfx_played`/`music_changed` events in the adapter matters.
- **Screenshot token cost** — the harness clips to the `#canvas` and screenshots only on each
  personality's cadence. Don't screenshot every step for state-driven personalities.
- **Determinism** needs the game to handle `set_seed`. A game that seeds its RNG from the clock
  will ignore it until you register a handler; wire one if reproducible repros matter.
- **Don't ship the bridge active in public builds** — gate activation on the `agent` custom feature
  or `?agent=1`. The autoload merely existing is harmless; only its activation is gated.
- Keep the game's copy `<game>/scripts/agent/agent_bridge.gd` in sync with the source of truth
  `agent_play/templates/agent_bridge.gd` if you change the bridge.
