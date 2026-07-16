// Central config for the agent-play harness. Reads .env at repo root for optional AGENT_* / GODOT
// overrides. The LLM is driven through the local Claude Code CLI (subscription auth) — see
// claude_cli.mjs — so NO ANTHROPIC_API_KEY is required.
//
// The Godot project is AUTO-DETECTED so this toolkit drops into any repo unchanged — nothing
// here is hardcoded to a specific game. Detection/override logic lives in project.mjs. Resolution:
//   1. AGENT_GODOT_PROJECT env var          (path, absolute or relative to the repo root)
//   2. agent_play.config.json godotProject  (committable per-repo config)
//   3. auto-detect the single project.godot at the repo root or one level below.
import 'dotenv/config';
import path from 'node:path';
import { ROOT, resolveProjectDir, readFileConfig } from './project.mjs';

export { ROOT };

const FILE = readFileConfig();
const godotProjectDir = resolveProjectDir();

export const config = {
  // Vision-capable model used for every decision + the final summary.
  model: process.env.AGENT_MODEL || FILE.model || 'claude-opus-4-8',

  // Auto-detected Godot project (absolute). Used as `--path` for export and to locate the build.
  godotProjectDir,
  godotProjectName: path.basename(godotProjectDir),
  godotBin: process.env.GODOT || FILE.godotBin || 'godot',
  exportPreset: process.env.AGENT_EXPORT_PRESET || FILE.exportPreset || 'Web',
  buildDir:
    (process.env.AGENT_BUILD_DIR && path.resolve(ROOT, process.env.AGENT_BUILD_DIR)) ||
    (FILE.buildDir && path.resolve(ROOT, FILE.buildDir)) ||
    path.join(godotProjectDir, 'build', 'web'),

  // Local server + run output.
  port: Number(process.env.AGENT_PORT || FILE.port || 8099),
  runsDir: path.join(ROOT, 'agent_play', 'runs'),

  // Loop pacing.
  defaultSteps: 120,
  readyTimeoutMs: 60000, // Godot web download + boot can be slow on first load.
  tickSettleMs: 180, // wait after unfreeze so the action's consequences/events materialize.

  // Engine hang oracle: how many consecutive steps meta.frame may be unchanged.
  hangSteps: 30,
  // Gameplay softlock oracle: steps of no logical progress (while playing + acting).
  softlockSteps: 24,
};
