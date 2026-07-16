---
name: "source-command-clarify-game-design"
description: "Read a source document (a rough game design doc, pitch, brief, or notes) and work interactively with the user to resolve anything unclear, vague, or missing. Asks clarifying questions back and forth, then writes a clear, structured game design document to thoughts/shared/game-design/."
---

# source-command-clarify-game-design

Use this skill when the user asks to run the migrated source command `clarify_game_design`.

## Command Template

# Clarify Game Design

You are tasked with turning a rough, vague, or incomplete game document into a clear, structured Game Design Document (GDD). You do this by **interrogating the source for ambiguity and gaps, asking the user clarifying questions, and iterating** until the design can be implemented into a full featured game — only then do you write the GDD. You create the GDD file early and update it continuously as answers arrive — by the time you finish, nothing is left unclarified and there are no open questions.

## Your job is to clarify, not to invent

You clarify what the user already has. Where the source is clear, preserve it. Where it is vague, contradictory, or silent, **ask** — do not fill gaps with your own assumptions and present them as fact. The output is only as good as the answers you draw out of the user.

## Starting point

The parameter is a path to a document — a rough GDD, a pitch, a one-pager, a brief, or notes. Read it **fully** (no offsets or limits) before doing anything else.

If the user pasted the document text directly instead of a path, use that. If no document was provided at all, respond with:

```
Point me at the document you want clarified (a path, or paste it here) and I'll turn it into a clear game design document.
```

Then wait.

## Steps

### 1. Read the source completely

Read the entire document. If it references other files (a separate mechanics spec, an art brief, a competitor teardown), read those in full too. Extract:
- The core concept / fantasy / pitch
- What is stated clearly vs. asserted vaguely vs. simply missing
- Any internal contradictions

### 2. Scan for vagueness and gaps across the GDD dimensions

Go through these dimensions. For each, classify the source as **clear**, **vague** (stated but underspecified, e.g. "fast-paced", "fun progression", "lots of enemies"), **contradictory**, or **missing**. Only the non-clear ones become questions.

- **Concept & fantasy** — the one-sentence pitch; what the player *is* and *does*; why it's compelling
- **Genre & references** — genre, and concrete comparison titles ("like X but Y")
- **Platform & audience** — target platform(s), input method, who this is for
- **Core gameplay loop** — the moment-to-moment loop the player repeats; what makes it satisfying
- **Player verbs & controls** — the actions the player can take and how they're triggered
- **Rules & mechanics** — how each system actually works; numbers where they matter (speed, costs, cooldowns)
- **Objects & entities** — every game object and its behavior, states, and interactions
- **Win/lose & failure** — victory conditions, fail states, what happens on death/loss
- **Progression & difficulty** — how the game escalates; difficulty curve; unlocks or scoring
- **World / level structure** — level layout, generation (authored vs. procedural), boundaries
- **Art & visual direction** — style, palette, resolution, mood (this project ships pixel-art Godot games — see notes)
- **Audio direction** — music style, key SFX, audio's role
- **UI / UX** — HUD, menus, feedback, game feel/juice
- **Scope & MVP** — what's in the first playable vs. later; explicit non-goals
- **Technical constraints** — Game engine, anything that bounds the design

A useful test: if a programmer or artist read the source and would have to *guess* to start work, that's a gap worth a question.

### 3. Ask clarifying questions, grouped

Present your findings in a single turn:

1. **Your read of the concept** — one or two sentences, so the user can correct you fast if you've misunderstood the core idea.
2. **What's already clear** — a short bullet list, so the user sees you won't re-litigate settled things.
3. **Questions**, grouped by dimension. For each ambiguity ask a focused question. Where a choice has a small set of natural options, offer them so the user can answer quickly (and flag contradictions explicitly: "X says A here but B there — which holds?").

Ask as many questions as it takes. Group them by dimension so the user can work through them efficiently. For crisp multiple-choice decisions you may use the `AskUserQuestion` tool (it accepts at most 4 questions per call, so issue multiple calls or fall back to markdown when you have more); for open-ended or numeric answers, plain grouped markdown questions are better.

Do not ask about things the source already settles. Do not ask cosmetic questions whose answer wouldn't change the design.

### 4. Iterate until the design is clear

The user will answer some questions, push back, or add context. After **every** round:
1. **Update the GDD file** (see step 5) so it reflects every decision settled so far.
2. Ask focused follow-ups on whatever is still vague, contradictory, or missing.

Keep iterating. You are done **only when every dimension is fully resolved**: nothing vague, nothing contradictory, nothing missing, and no open questions remain.

Do not leave gaps. If the user skips a question or says "just go", do **not** record it as unresolved — instead propose a concrete, sensible default for each remaining item and let the user confirm or tweak (a "go" confirms your proposed defaults). The proposal-and-confirmation is itself clarification, so the result is a recorded decision, never an open question. This keeps you honest to "clarify, not invent" while guaranteeing nothing is left open.

### 5. Create the GDD file early, then update it continuously

You do **not** wait until the end to write. Create the file as soon as you have done your first read and scan (step 2), and rewrite it after every round of answers.

- **Create early.** After the first scan, get the target path (Step 1 below) and write an initial draft: fill in everything already clear, and use an explicit `TBD` placeholder for every dimension still open. Get the path **once** and reuse it for all subsequent updates.
- **Update every round.** Each time the user answers, rewrite the file so it captures every decision settled so far and shrinks the remaining `TBD` placeholders. Use the `Write` tool to overwrite the file (or `Edit` for targeted changes).
- **Finish only when complete.** When every dimension is resolved and **no `TBD` placeholders remain**, the file is the final GDD. Do not pause to ask for confirmation before saving — saving is continuous and the iteration *is* the agreement.

Saving is a two-step process to avoid shell-quoting bugs with large markdown content:

**Step 1 (run once, when you first create the file)** — get the target path by running:

```
python "$(git rev-parse --show-toplevel)/create_thought.py" game-design <file_name_description> [ticket]
```

The `$(git rev-parse --show-toplevel)` resolves to the repo root with forward slashes, so the command works from any subdirectory and avoids Bash interpreting backslashes in a Windows path as escape characters.

Where `<file_name_description>` is a short kebab-case label for the game/topic, and `[ticket]` is optional. The script prints the absolute path to stdout (and creates the parent directory). It does NOT write the file.

**Step 2** — use the `Write` tool directly to write the content (formatted per the template below) to that printed path.

While you are still iterating, each reply to the user is your next round of questions (not the export line), even though you have already written/updated the file behind the scenes.

Only once the design is **fully clarified and the file is complete** (no `TBD` remaining), your entire reply to the user is the single line:

```
I have exported your game design document into [FULL_FILE_PATH]
```

Replace `[FULL_FILE_PATH]` with the absolute path printed by `create_thought.py`. Do not restate the GDD, list decisions, or add any other content.

## Output file format

Use this structure. **Omit any section that genuinely doesn't apply** rather than padding it. The finished document must contain **no unresolved items** — every dimension is a settled decision. (Interim drafts may carry explicit `TBD` placeholders while you iterate, but none may remain when you finish, and there is no Open Questions section.)

```markdown
# Game Design Document: [Game Title]

## Concept
[One-sentence pitch, then a short paragraph: what the player is, does, and why it's compelling.]

## Genre & References
[Genre and concrete comparison titles.]

## Platform & Audience
[Target platform(s), input method, intended audience.]

## Core Gameplay Loop
[The moment-to-moment loop the player repeats, and what makes it satisfying.]

## Player Verbs & Controls
[Every action the player can take and how it's triggered.]

## Mechanics & Rules
### [Mechanic / System name]
[How it works, including concrete numbers where they matter.]

## Game Objects & Entities
### [Object name]
[Behavior, states, interactions.]

## Win / Lose Conditions
[Victory conditions, fail states, what happens on death/loss.]

## Progression & Difficulty
[How the game escalates; scoring, unlocks, difficulty curve.]

## World / Level Structure
[Layout, authored vs. procedural generation, boundaries.]

## Art & Visual Direction
[Style, palette, resolution, mood.]

## Audio Direction
[Music style, key SFX, audio's role.]

## UI / UX
[HUD, menus, feedback, game feel.]

## Scope
### MVP (first playable)
[What's in the first version.]
### Non-Goals
[Explicit list of what this game is NOT.]

## Technical Constraints
[Game Engine, platform limits.]
```

## Notes

- This is a Godot pixel-art game project. Default technical assumptions are Godot + 2D pixel art unless the source or the user says otherwise — but confirm rather than silently assuming when it materially shapes the design.
- Stay skeptical: if the source contradicts itself or a stated mechanic doesn't actually work, surface it instead of smoothing it over.
- Preserve the user's vision and wording where the source is already clear; clarify, don't redesign.
- This produces a *design* artifact, not an implementation plan. Don't write code-level steps — that's for the planning skills downstream.
