# Agent guide — TristramAutoBattler

The primary project guide is [`claude.md`](claude.md) (Project Map, operating rules, testing philosophy).
Read it first. This repo is a Godot 4.7 auto battler town builder vertical slice; the actual Godot project is
`lord-of-hirelings/`.

## Balance & tuning convention (hard rule)

All tunable gameplay/visual scalars — player move speed, sprite scales, damage, cooldowns, pacing — live as rows in
`lord-of-hirelings/data/balance.csv`. Never add game design values as hardcoded `.gd` consts; Full rule in [`claude.md`](claude.md) Operating Principles.

## Autonomous agent tooling (cosmic-agent-tools)

Three installed tools for running coding agents autonomously. **Read the linked doc before you run,
configure, or reason about any of them.**

- **Workshop — `workshop/`** — the SINGLE-agent counterpart: one agent, fresh context each pass, draining
  an operator-curated backlog toward `workshop/GOAL.md`, with a live web UI. Read
  [`workshop/README.md`](workshop/README.md). Run: `node workshop/ui/server.js` → http://localhost:4455,
  or `./workshop/start-workshop.ps1`. Knobs in `workshop/workshop.config.ps1`.