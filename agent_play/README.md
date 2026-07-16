# agent_play — let an AI agent play a Godot WebGL game

A reusable, **game-agnostic** toolkit for driving any 2D Godot 4 WebGL game with an AI agent
in a closed loop: **send inputs → read game state → observe visuals → decide → repeat**. Use
it to find bugs and to evaluate art direction, juiciness (game feel), and audio coverage.

It works by having the game publish a small JSON state snapshot to the page via Godot's
`JavaScriptBridge`, which a Playwright-driven harness reads; inputs go back over a JS control
channel. See the `/godot_agent_play` skill (`.claude/commands/godot_agent_play.md`) for the
step-by-step playbook. This README is the quick reference.

## Layout

```
agent_play/
  setup.mjs         ONE-COMMAND INSTALLER (deps, browser, CLI auth, skill, MCP, bridge wiring)
  INSTALL.md        install guide (human + agent)
  templates/agent_bridge.gd          generic drop-in Godot autoload (copy into a game)
  templates/agent_adapter.example.gd  annotated per-game adapter to copy & fill in
  skill/godot_agent_play.md          bundled skill (installer copies it to .claude/commands/)
  server.mjs        static server w/ COOP/COEP + correct MIME for the web build
  harness.mjs       autonomous loop: export -> serve -> Chromium -> personality loop -> report
  claude_cli.mjs    Claude Code CLI transport (subscription auth; forced-schema action + summary)
  oracles.mjs       generic invariant checks (hang/softlock/NaN-OOB/console/crash/dead-input)
  audio_probe.mjs   page init script: logs WebAudio playback attempts (works headless)
  report.mjs        writes runs/<ts>-<personality>/{session.jsonl,screenshots,findings.md}
  config.mjs        model id, port, pacing; reads .env
  project.mjs       Godot project auto-detection (shared by config + setup)
  personalities/    bug_hunter | art_director | juiciness_evaluator | audio_evaluator + index
```

This toolkit is repo-agnostic — nothing is hardcoded to a specific game. Drop the `agent_play/`
folder, the `/godot_agent_play` skill, and the `playwright` MCP entry into any repo and it works;
see **Porting to another repo** below.

## Wiring a game (one-time, ~15 lines of game code)

1. Copy `templates/agent_bridge.gd` into the game at `scripts/agent/agent_bridge.gd`.
2. Register it as an autoload in `project.godot`:
   ```ini
   [autoload]
   AgentBridge="*res://scripts/agent/agent_bridge.gd"
   ```
3. Write a per-game adapter (copy `templates/agent_adapter.example.gd`) that maps your state
   onto the contract and register it from your main controller's `_ready`:
   ```gdscript
   AgentBridge.register_provider(_provide_agent_state)   # func() -> Dictionary (the contract)
   ```
   Map your phase enum onto `menu|playing|paused|game_over|loading`, list `available_actions`
   per phase, and convert every `Vector2/Vector2i` to `[x, y]`.
4. Emit events at gameplay moments so the juiciness/audio/bug personalities have signal:
   ```gdscript
   AgentBridge.emit_event("score_changed", {"to": score})
   AgentBridge.emit_event("death", {})
   AgentBridge.emit_event("sfx_played", {"name": "eat"})
   ```
5. (Optional) `AgentBridge.register_command_handler(...)` for `set_seed`/custom `restart`/`step`.

The bridge is inert unless the build is a web export AND the agent gate is on (a `Web-Agent`
export preset with `custom_features="agent"`, or just `?agent=1` in the URL). Public builds
never expose the hooks.

## Install (one command)

```bash
node agent_play/setup.mjs        # deps, browser, project, CLI auth, skill, MCP, bridge wiring
```
Idempotent and safe to re-run. It does everything mechanical and prints what's left (the per-game
adapter). Full details + flags + the agent-autonomous install prompt: **`INSTALL.md`**.

## Running

```bash
# one-time (or just run setup.mjs above): npm install && npx playwright install chromium
# Auth: the Claude Code CLI must be installed + logged in (`claude /login`) with your Pro/Max
# subscription — the harness drives the game via `claude -p`. No ANTHROPIC_API_KEY needed.

node harness.mjs --personality bug-hunter --steps 120 [--seed 123] [--headed] [--no-export]
```

Personalities: `bug-hunter` · `bug-hunter-poe` (Poe voice) · `art-director` · `visual-scale`
(sizing/legibility) · `juiciness` · `audio` · `new-player` (onboarding UX) · `experienced-player`
(depth for veterans). Output lands in `agent_play/runs/<timestamp>-<personality>/findings.md`
(+ `session.jsonl` and screenshots).

Just want to serve the build and poke at it yourself (or via the Playwright MCP server)?
```bash
node server.mjs        # serves the web build with the right headers
# then open http://localhost:8099/index.html?agent=1
```

## Porting to another repo

The `agent_play/` folder is self-contained (it bundles the skill in `skill/`). To port:

1. Copy the whole `agent_play/` folder into the target repo's root.
2. `node agent_play/setup.mjs` — installs deps + browser, detects the Godot project, verifies the Claude Code CLI (subscription auth), installs the skill into `.claude/commands/`, adds the MCP server, and wires the bridge.
3. Complete the one `[todo]` it prints: write the per-game adapter (see `INSTALL.md` / skill Step 1).

If the repo has **no** Godot project at the auto-detect depth (repo root or one level below), or
**more than one**, point the toolkit at the right one — no code edit needed — via:
- `node agent_play/setup.mjs --project path/to/project` (saves it to `agent_play.config.json`), or
- env var `AGENT_GODOT_PROJECT=path/to/project`, or
- a committable `agent_play/agent_play.config.json` (copy `agent_play.config.example.json`).

Other overrides (env or config file): `AGENT_BUILD_DIR`, `AGENT_EXPORT_PRESET`, `AGENT_MODEL`,
`AGENT_PORT`, `GODOT` (godot binary path).

## The contract (what the bridge publishes)

- `window.__agentStateJson` — JSON string of the AgentState (`meta`, `phase`, `player`,
  `score`, `entities`, `world`, `available_actions`).
- `window.__agentEventsJson` — JSON array of bounded, seq-numbered gameplay events.
- `window.__agentReady` — `true` once the first state is published.
- `window.__agentControl.send(jsonString)` — command channel (page → game).

Commands: `press`/`release`/`tap` (action name), `set_time_scale` (0 freezes while the agent
thinks), `ack_events`, `restart`, `set_seed`, `step`.

## Notes & gotchas

- **Freeze while thinking.** The harness sets `time_scale=0` before each decision and restores
  it after, turning a realtime game into a turn-based one for the agent. `_process` still runs
  at `time_scale 0`, so the bridge keeps publishing.
- **Audio is the weakest channel.** Headless = nothing audible; the audio personality reviews
  coverage/timing from events + the WebAudio probe, not a listening test. The probe is
  engine-aware: for Godot (worklet-mixed audio) it logs the AudioContext lifecycle, not per-SFX
  — per-sound coverage comes from the game's `sfx_played`/`music_changed` events.
- **COOP/COEP** headers are sent always; required only for threaded exports but harmless otherwise.
- **Web export path (CLI).** Pass an **absolute** output path to `--export-release`. With
  `--path <project>`, a *relative* output path resolves against the project dir and fails with
  `Target folder does not exist or is inaccessible`. The output folder must already exist —
  Godot won't create it. `harness.mjs` handles both (absolute `config.buildDir`, `mkdirSync`); only
  hand-run exports hit this.
- **Headless WebGL flags.** A Godot WebGL build will NOT render in modern headless Chromium
  without `--enable-unsafe-swiftshader --use-gl=angle --use-angle=swiftshader` (headless disables
  SwiftShader WebGL by default). `harness.mjs` already passes these; replicate them in any other
  Playwright launcher (e.g. an interactive driver) or the canvas stays blank.
- **Determinism** needs the game to implement a `set_seed` handler. A game that seeds its RNG
  from the clock will ignore `set_seed` until it registers one (see the example adapter).
