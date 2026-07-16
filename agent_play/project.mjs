// Godot project discovery + resolution, shared by config.mjs and setup.mjs.
// Kept separate so setup.mjs can inspect candidates WITHOUT triggering config.mjs's
// eager resolve-or-throw at import time.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const HERE = path.dirname(fileURLToPath(import.meta.url));
// Repo root is one level up from agent_play/.
export const ROOT = path.resolve(HERE, '..');

export const isGodotProject = (dir) => {
  try {
    return fs.existsSync(path.join(dir, 'project.godot'));
  } catch {
    return false;
  }
};

export function readFileConfig() {
  const p = path.join(HERE, 'agent_play.config.json');
  if (!fs.existsSync(p)) return {};
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8')) || {};
  } catch (e) {
    throw new Error(`agent_play: failed to parse ${p}: ${e.message}`);
  }
}

const SKIP_DIRS = new Set(['node_modules', 'agent_play', 'archive', 'addons']);

// Returns all Godot project dirs at the repo root or one level below (no throw).
export function detectGodotProjects() {
  const found = [];
  if (isGodotProject(ROOT)) found.push(ROOT);
  let entries = [];
  try {
    entries = fs.readdirSync(ROOT, { withFileTypes: true });
  } catch {
    /* ignore */
  }
  for (const e of entries) {
    if (!e.isDirectory()) continue;
    if (e.name.startsWith('.') || SKIP_DIRS.has(e.name.toLowerCase())) continue;
    const dir = path.join(ROOT, e.name);
    if (isGodotProject(dir)) found.push(dir);
  }
  return [...new Set(found)];
}

// Resolves the single Godot project dir or throws an actionable error.
export function resolveProjectDir({ override } = {}) {
  const ov = override || process.env.AGENT_GODOT_PROJECT || readFileConfig().godotProject;
  if (ov) {
    const dir = path.resolve(ROOT, ov);
    if (!isGodotProject(dir)) {
      throw new Error(`agent_play: configured Godot project "${dir}" has no project.godot.`);
    }
    return dir;
  }
  const found = detectGodotProjects();
  if (found.length === 1) return found[0];
  if (found.length === 0) {
    throw new Error(
      `agent_play: no Godot project found (no project.godot at the repo root or one level below ${ROOT}). ` +
        'Run `node setup.mjs --project <dir>`, set AGENT_GODOT_PROJECT=<dir>, or add agent_play.config.json.'
    );
  }
  throw new Error(
    `agent_play: multiple Godot projects found (${found.map((p) => path.relative(ROOT, p) || '.').join(', ')}). ` +
      'Pick one via `node setup.mjs --project <dir>`, AGENT_GODOT_PROJECT=<dir>, or agent_play.config.json.'
  );
}
