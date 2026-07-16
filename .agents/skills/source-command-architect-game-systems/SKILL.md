---
name: "source-command-architect-game-systems"
description: "Read a Game Design Document (the kind clarify_game_design produces) and architect the top-level code systems needed to implement a simple playable vertical slice in Godot 4. Identifies hidden technical challenges, decomposes the game into logical modules with stated goals and clear inputs/outputs, and writes a systems architecture document to .taskmaster/docs/systems.md."
---

# source-command-architect-game-systems

Use this skill when the user asks to run the migrated source command `architect_game_systems`.

## Command Template

# Architect Game Systems

You are a **systems engineer**. You take a finished Game Design Document (GDD) and architect the top-level major code systems needed to implement the game in **Godot 4**. Your output is a systems architecture document that maps the design onto a small set of logical, well-bounded modules, and describes a **simple playable vertical slice** that can be implemented directly.

## Your job is to architect, not to redesign

The GDD is the source of truth for *what* the game is. You decide *how* it is built. Honor every explicit requirement and every non-goal in the GDD — do not drop features the design calls for, and do not smuggle in features the design excludes. Your value is the engineering layer the GDD leaves implicit: the modules, their boundaries, their data, and how they interact.

Two standing constraints govern every decision:

1. **Most direct path to implementation.** Surface technical challenges the GDD does not mention, but solve them with the simplest approach that works. No over-engineering, no speculative generality, no roundabout indirection. If a flat array does the job, do not propose an ECS. If a `Timer` does the job, do not propose a fixed-timestep accumulator unless the design's timing demands it.
2. **Godot 4 only.** Every node type, API, signal pattern, and idiom must be correct for **Godot 4**.

## Architecture philosophy (apply this throughout)

Decompose the game so that **game logic lives in pure, stateless modules** and **Godot nodes are thin shells** that hold engine state and delegate to those modules.

- **Prefer pure functions with explicit inputs and outputs.** A system should, wherever possible, be a set of functions that take data in and return data out, holding no internal state between calls.
- **Prefer mutating objects passed by reference over owning state.** When a system must change game state, it should receive the state object (a plain data container) and modify it in place, rather than keeping its own private copy and exposing getters/setters. The state lives in a small number of explicit data objects; systems operate on them.
- **Isolate the engine.** Pure logic modules must not depend on the scene tree, `get_node`, input polling, or rendering. That makes them unit-testable headlessly with gdUnit4 (see project `TESTING.md`) and keeps the Godot-specific surface thin and obvious.
- **Stateful node shells** (the `Node`/`Node2D`/`Control` scripts and any autoload singletons) own only what the engine forces them to own: scene references, timers, input, rendering. They translate engine events into calls on the pure modules and write results back into the data objects.

Each system you define must therefore declare whether it is **pure/stateless logic**, a **stateful node shell**, or an **autoload/service** — and justify any state it holds.

## Starting point

The parameter is a path to a GDD. Read it **fully** (no offsets or limits) before doing anything else.

- If none can be found and none was provided, respond with:

```
Point me at the Game Design Document you want architected and I'll architect the game systems.
```

Then wait.

## Steps

### 1. Read the GDD completely

Read the whole document. Extract, per dimension: the core loop, player verbs, every mechanic and its numbers, every game object and its states, win/lose conditions, progression, world/level structure, UI screens and transitions, scope (MVP vs. later vs. non-goals), and technical constraints. The MVP/vertical-slice scope is what you are architecting — note explicitly what is in the first playable and what is deferred.

### 2. Identify technical challenges the GDD does not state

Before decomposing, think like an engineer about what the design *implies* but does not spell out. For each challenge: name it, say why it matters, and choose the **most direct** Godot-4 approach. Do not invent complexity the design does not need, and do not discard any explicit requirement to make your life easier. Categories worth scanning (use only those that apply):

- **Timing & update model** — is movement frame-rate-independent? Fixed tick vs. `_process`/`_physics_process` vs. `Timer`? What is authoritative each step?
- **Coordinate systems** — grid ↔ pixel conversion, world vs. screen, anchoring/scaling of a pixel-art playfield.
- **State representation** — what data structure holds the core game state (arrays, dictionaries, a small struct-like object)?
- **Input handling** — input map, polling, event driven _input callbacks.
- **Collision / overlap detection** — done by data lookup or by physics nodes? Which is simpler and correct for this design?
- **Game state machine** — the screen states (title, playing, paused, game over, …) and the push down automata to transition between them.
- **Persistence** — what is saved, in what format, to `user://`, and when.
- **Spawning / lifecycle** — object creation/destruction, pooling only if the design's volume actually demands it.
- **Determinism & testability** — what must be reproducible and unit-testable.
- **Edge cases** — boundary conditions the rules create (full board, simultaneous events, first frame, restart).

### 3. Decompose into systems

Define the **top-level major systems** — each a logical module owning exactly one aspect of the game. Aim for the smallest set of systems that cleanly covers the vertical slice; merge anything that would otherwise be a trivial wrapper, and split anything that mixes two concerns. For each system, specify the fields in the output template (goal, type, inputs, outputs/mutations, key function signatures, dependencies, Godot 4 mapping).

Also define the **shared data model**: the plain-data objects that systems read and mutate by reference. These are the backbone of the "modify by reference, don't own state" philosophy — get them right and the systems fall out naturally.

Then define **how the systems interact**: the ordering of one game tick / frame, who calls whom, and what data moves between them. This is where you prove the decomposition actually runs.

### 4. Clarify only genuine architectural forks

The GDD is already fully clarified, so default to **proceeding directly** — make sound engineering decisions and document them with their rationale. Do **not** ask for confirmation of reasonable choices (per the project's operating principles).

Only stop to ask the user if the GDD contains a true technical contradiction, or an architectural fork that materially changes the implementation and that the design genuinely does not resolve. In that case, ask focused questions (the `AskUserQuestion` tool is good for crisp choices), then continue. Otherwise, choose the most direct option, record it in the document with a one-line rationale, and move on.

### 5. Write the systems document

Write the architecture to **`.taskmaster/docs/systems.md`**. Resolve the absolute path from the repo root and write there directly; the `Write` tool creates the `.taskmaster/docs/` directory if it does not exist. Get the repo root with:

```
git rev-parse --show-toplevel
```

Then `Write` the content (formatted per the template below) to `<repo-root>/.taskmaster/docs/systems.md`. If a `systems.md` already exists, overwrite it with the new architecture.

When the document is complete, your entire reply to the user is the single line:

```
I have exported your game systems architecture into [FULL_FILE_PATH]
```

Replace `[FULL_FILE_PATH]` with the absolute path written. Do not restate the architecture or add other content. (If you had to ask a clarifying question in step 4, those question turns are your replies during iteration; the export line is only your final reply.)

## Output file format

Use this structure. **Omit any section that genuinely doesn't apply** rather than padding it. Keep every system bounded and every decision justified by the design or by a stated technical challenge.

```markdown
# Game Systems Architecture: [Game Title]

## Source
[Path to the GDD this is derived from + one-line summary of the game.]

## Architecture Philosophy
[2-4 sentences: pure stateless logic modules operating on explicit data objects passed by reference, behind thin Godot 4 node shells; engine isolated from logic for headless testability.]

## Technical Challenges & Considerations
[The step-2 analysis. For each challenge: what it is, why it matters, and the chosen most-direct Godot 4 approach (with a one-line rationale). Godot-4-specific.]

## Shared Data Model
[The plain-data objects systems read and mutate by reference — the "state" of the game. For each:]
### [Object name]
- **Purpose:** [what this data represents]
- **Fields:** [name: type — meaning]
- **Lifecycle:** [created when, mutated by which systems, destroyed/reset when]

## Systems
### [System name]
- **Goal:** [one sentence — the single aspect this module owns]
- **Type:** pure/stateless logic | stateful node shell | autoload/service
- **Inputs:** [data taken in]
- **Outputs / mutations:** [return values, and/or which data-model objects it mutates by reference]
- **Key functions:** [Godot 4 typed GDScript signatures, e.g. `static func step(state: GameState, dir: Vector2i) -> void`]
- **Dependencies:** [other systems it calls; data-model objects it touches]
- **Godot 4 mapping:** [node type / autoload / signals it emits or listens for / where it sits in the scene tree; "none — pure module" for stateless logic]
- **State note:** [if stateful, what state and why it cannot be passed in instead]

## System Interaction & Data Flow
[One game tick / frame, in order: which shell receives the engine event, which pure modules it calls, what data is read and mutated, what signals fire, what gets rendered. A numbered step list or simple arrow diagram. Cover the main loop and the key transitions (start, death/loss, restart).]

## Game State Machine
[The screen/flow states and legal transitions, if the design has more than one — e.g. title → playing ⇄ paused → game over → playing. Note who owns it.]

## Godot 4 Scene Tree / Node Layout
[The node hierarchy for the vertical slice, mapping systems/shells to concrete Godot 4 nodes, scripts, and autoloads. Show which scripts are pure modules (no node) vs. attached to nodes.]

## File / Module Layout
[Proposed res:// paths, separating pure logic modules from node shells and mirroring the test/ layout (one _test.gd per pure module). Concrete enough that the next step can create the files.]

## Vertical Slice Definition
[The minimal playable thing this architecture delivers — tied to the GDD's MVP. One short paragraph: what the player can do end to end.]

## Out of Scope
[Features the GDD defers or excludes (later/stretch + non-goals), restated so the architecture is not over-built for them.]
```

## Notes

- This is a Godot 4 pixel-art project; the Godot project lives in `snaketaskmaster/` (run `godot` with `--path snaketaskmaster`). Pure logic modules should be plain `RefCounted`/`Resource` classes or scripts with `static func`s so they compile and test without a scene.
- Lean on the project's headless testing (`gdUnit4`, `TESTING.md`): a system designed as pure functions over data objects is directly unit-testable. Note in the File/Module Layout which modules get a `_test.gd`.
- This produces an **architecture** artifact, not an implementation plan and not code. Describe systems, data, interfaces, and signatures — leave step-by-step build instructions and full implementations to the downstream planning/implementation skills.
- Stay skeptical: if a GDD mechanic is technically incoherent or two requirements conflict at the systems level, surface it (and resolve it via step 4) rather than papering over it.
- Keep the system count small and the boundaries clean. The test of a good decomposition: each system has one goal, most are stateless, and the data flow through one tick reads in a straight line.
