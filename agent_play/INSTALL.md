# Installing agent_play in a repo

One command does almost everything. From the repo root:

```bash
node agent_play/setup.mjs
```

That installer is **idempotent** (safe to re-run) and does:

1. `npm install` in `agent_play/`
2. `npx playwright install chromium`
3. Detects the Godot project (or, with several, lets you pick / `--project <dir>`) and saves the
   choice to `agent_play/agent_play.config.json`
4. Gitignores `.env` (and drops a secret-free `.env.example`), then verifies the **Claude Code CLI** is installed. The harness bills game-play LLM calls to your Pro/Max **subscription** via `claude -p` (run `claude /login` once) — **no `ANTHROPIC_API_KEY` needed**. If `.env` was *already* committed with a key, it warns you to rotate + purge it.
5. Installs the `/godot_agent_play` skill into `.claude/commands/`
6. Adds the Playwright MCP server to `.mcp.json`
7. Wires the `AgentBridge` autoload + bridge script into the game

It prints a summary marking each item `[done]` / `[skip]` / `[todo]`.

## The one manual step

The installer cannot write the **per-game adapter** — that requires understanding your game's
state. When it prints `[todo] ADAPTER NEEDED`, do this (the `/godot_agent_play` skill Step 1
walks through it):

1. Copy `agent_play/templates/agent_adapter.example.gd` into your game and map your state onto the AgentState contract (phase → `menu|playing|paused|game_over|loading`; vectors → `[x,y]`; `available_actions` per phase).
2. Register it from your main controller `_ready()`: `AgentBridge.register_provider(_provide)`.
3. Add a few `AgentBridge.emit_event(...)` calls at gameplay moments (score, death, sfx).
4. (Optional) add a `Web-Agent` export preset with `custom_features="agent"`; otherwise just use `?agent=1` in the URL.

Then verify it compiles (`godot --headless --path <game> --import`) and run.

## Flags

```
node agent_play/setup.mjs
  --project <dir>     use this Godot project dir (saved to agent_play.config.json)
  --api-key <key>     write this key to .env non-interactively
  --skip-install      skip npm install
  --skip-browser      skip the Chromium download
  --no-wire           don't touch the game's project.godot / scripts
  --force             overwrite the installed skill and refresh the bridge from the template
  --yes               don't prompt (CI / agent use)
```

## Running an AI agent to install it autonomously

Point Claude Code (or any agent) at this and let it drive:

> Install agent_play in this repo: run `node agent_play/setup.mjs --yes`, read its summary, then
> complete any `[todo]` items — in particular write the per-game adapter by following the
> `/godot_agent_play` skill's Step 1 (map the game's state onto the AgentState contract, register
> the provider, add `emit_event` calls). Finally run `godot --headless --path <game> --import` to
> confirm it compiles.

After that, run a personality: `node agent_play/harness.mjs --personality bug-hunter --steps 60`.
See `README.md` for the contract, personalities, and gotchas.
