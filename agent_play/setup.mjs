// agent_play autonomous installer.
//
// Does as much of the setup as can be done safely & deterministically:
//   1. npm install (toolkit deps)            5. install the /godot_agent_play skill
//   2. playwright install chromium           6. merge the playwright MCP server into .mcp.json
//   3. detect / configure the Godot project  7. wire the AgentBridge into the game (copy + autoload)
//   4. .env hygiene + verify the Claude CLI   8. report the one step left to a human/agent (the adapter)
//
// The harness drives the game through the local Claude Code CLI (subscription auth) — no API key.
// Idempotent: re-running skips anything already done. Safe: edits are additive and guarded.
//
// Usage:
//   node setup.mjs [--project <dir>] [--skip-install] [--skip-browser]
//                  [--no-wire] [--force] [--yes]
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { spawn, execFileSync } from 'node:child_process';
import { ROOT, HERE, isGodotProject, detectGodotProjects, resolveProjectDir } from './project.mjs';

const results = [];
const ok = (m) => { results.push(`  [done] ${m}`); console.log(`[done] ${m}`); };
const skip = (m) => { results.push(`  [skip] ${m}`); console.log(`[skip] ${m}`); };
const warn = (m) => { results.push(`  [todo] ${m}`); console.log(`[todo] ${m}`); };
const step = (m) => console.log(`\n=== ${m} ===`);

function parseArgs(argv) {
  const a = { skipInstall: false, skipBrowser: false, noWire: false, force: false, yes: false };
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    if (k === '--project') a.project = argv[++i];
    else if (k === '--skip-install') a.skipInstall = true;
    else if (k === '--skip-browser') a.skipBrowser = true;
    else if (k === '--no-wire') a.noWire = true;
    else if (k === '--force') a.force = true;
    else if (k === '--yes' || k === '-y') a.yes = true;
  }
  return a;
}

function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: 'inherit', shell: process.platform === 'win32', ...opts });
    p.on('error', reject);
    p.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`${cmd} exited ${code}`))));
  });
}

function ask(q) {
  return new Promise((res) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(q, (ans) => { rl.close(); res(ans.trim()); });
  });
}

const interactive = () => process.stdin.isTTY && process.stdout.isTTY;

// ---- 3. project resolution -------------------------------------------------

function writeConfigProject(dir) {
  const rel = path.relative(ROOT, dir) || '.';
  const p = path.join(HERE, 'agent_play.config.json');
  let cfg = {};
  if (fs.existsSync(p)) {
    try { cfg = JSON.parse(fs.readFileSync(p, 'utf8')) || {}; } catch { /* ignore */ }
  }
  cfg.godotProject = rel;
  fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
  return rel;
}

async function resolveProject(args) {
  if (args.project) {
    const dir = path.resolve(ROOT, args.project);
    if (!isGodotProject(dir)) throw new Error(`--project "${dir}" has no project.godot.`);
    const rel = writeConfigProject(dir);
    ok(`Godot project set to "${rel}" (saved to agent_play.config.json)`);
    return dir;
  }
  try {
    const dir = resolveProjectDir();
    ok(`Godot project detected: ${path.relative(ROOT, dir) || '.'}`);
    return dir;
  } catch (e) {
    const cands = detectGodotProjects();
    console.log(e.message);
    if (cands.length > 1 && interactive()) {
      cands.forEach((c, i) => console.log(`    ${i + 1}) ${path.relative(ROOT, c) || '.'}`));
      const ans = await ask('  Choose a project number (or blank to skip wiring): ');
      const idx = Number(ans) - 1;
      if (cands[idx]) { const rel = writeConfigProject(cands[idx]); ok(`Godot project set to "${rel}"`); return cands[idx]; }
    } else if (cands.length === 0 && interactive()) {
      const ans = await ask('  Path to the Godot project dir (or blank to skip wiring): ');
      if (ans) {
        const dir = path.resolve(ROOT, ans);
        if (isGodotProject(dir)) { const rel = writeConfigProject(dir); ok(`Godot project set to "${rel}"`); return dir; }
        warn(`"${dir}" has no project.godot — skipping wiring.`);
      }
    }
    warn('No Godot project resolved — skipped project wiring. Re-run with --project <dir>.');
    return null;
  }
}

// ---- 4. .env hygiene + verify the Claude Code CLI (subscription auth) -------

// Ensure the repo-root .gitignore keeps .env out of version control. The harness no longer needs
// an API key, but a user may still keep one in .env for other tools — keep it un-committable.
// Idempotent + additive: only appends a block if .env isn't ignored yet.
function ensureGitignore() {
  const giPath = path.join(ROOT, '.gitignore');
  const text = fs.existsSync(giPath) ? fs.readFileSync(giPath, 'utf8') : '';
  const ignoresEnv = text.split(/\r?\n/).some((l) => {
    const t = l.trim();
    return t === '.env' || t === '/.env' || t === '.env*' || t === '.env.*';
  });
  if (ignoresEnv) { ok('.env already gitignored'); return; }
  const block =
    '\n# Secrets / local environment — never commit API keys (added by agent_play setup)\n' +
    '.env\n.env.*\n!.env.example\n';
  fs.writeFileSync(giPath, (text && !text.endsWith('\n') ? text + '\n' : text) + block);
  ok(`.env added to .gitignore (the key never lands in a commit)`);
}

// Write a committable, secret-free .env.example the docs point at, if absent.
function ensureEnvExample() {
  const exPath = path.join(ROOT, '.env.example');
  if (fs.existsSync(exPath)) { skip('.env.example already present'); return; }
  fs.writeFileSync(
    exPath,
    '# agent_play — optional local overrides. Copy to `.env` (gitignored).\n' +
      '# NO API KEY REQUIRED: the harness drives the game through the Claude Code CLI, billed to\n' +
      '# your Pro/Max subscription. Run `claude /login` once. ANTHROPIC_API_KEY is ignored by the\n' +
      '# harness — set one only if OTHER tools in this repo need API-key billing.\n' +
      '\n# Optional overrides (uncomment as needed):\n' +
      '# AGENT_MODEL=claude-opus-4-8\n' +
      '# GODOT=godot\n' +
      '# AGENT_GODOT_PROJECT=\n' +
      '# AGENT_PORT=8099\n'
  );
  ok('wrote .env.example (committable template, no secret)');
}

// gitignore can't save an ALREADY-tracked .env — warn loudly so the human knows
// they have a leaked key to rotate + purge, not just a file to ignore going forward.
function warnIfEnvTracked() {
  try {
    execFileSync('git', ['ls-files', '--error-unmatch', '.env'], { cwd: ROOT, stdio: 'ignore' });
  } catch {
    return; // not tracked (or not a git repo) — the good path
  }
  warn(
    '.env is ALREADY TRACKED by git — gitignore alone will NOT remove it. Run ' +
      '`git rm --cached .env`, ROTATE the leaked key, and purge it from history ' +
      '(e.g. `git filter-repo --path .env --invert-paths`) before pushing.'
  );
}

async function ensureAuth() {
  // Keep .env un-committable (a user may still keep keys there for other tools), then verify the
  // Claude Code CLI — the harness bills the game-play LLM calls to your subscription, not an API key.
  ensureGitignore();
  ensureEnvExample();
  warnIfEnvTracked();

  const bin = process.platform === 'win32' ? 'claude.exe' : 'claude';
  let version = '';
  try {
    version = execFileSync(bin, ['--version'], { encoding: 'utf8' }).trim();
  } catch {
    version = '';
  }
  if (version) {
    ok(`Claude Code CLI present (${version}) — harness uses your subscription login, no API key needed`);
    if (process.env.ANTHROPIC_API_KEY) {
      skip('ANTHROPIC_API_KEY is set in your env but the harness ignores it (uses the subscription)');
    }
  } else {
    warn(
      `Claude Code CLI ('${bin}') not found on PATH — install it and run 'claude /login' with your ` +
        `Pro/Max subscription before running the harness.`
    );
  }
}

// ---- 5. install the skill --------------------------------------------------

function installSkill(args) {
  const src = path.join(HERE, 'skill', 'godot_agent_play.md');
  if (!fs.existsSync(src)) { warn('bundled skill missing (agent_play/skill/) — cannot install it'); return; }
  const dstDir = path.join(ROOT, '.claude', 'commands');
  const dst = path.join(dstDir, 'godot_agent_play.md');
  if (fs.existsSync(dst) && !args.force) { skip('skill already at .claude/commands/godot_agent_play.md (use --force to overwrite)'); return; }
  fs.mkdirSync(dstDir, { recursive: true });
  fs.copyFileSync(src, dst);
  ok('installed /godot_agent_play skill -> .claude/commands/godot_agent_play.md');
}

// ---- 6. playwright MCP server in .mcp.json ---------------------------------

function mergeMcp() {
  const p = path.join(ROOT, '.mcp.json');
  let cfg = { mcpServers: {} };
  if (fs.existsSync(p)) {
    try { cfg = JSON.parse(fs.readFileSync(p, 'utf8')) || {}; } catch { warn('.mcp.json is invalid JSON — leaving it alone'); return; }
  }
  cfg.mcpServers = cfg.mcpServers || {};
  if (cfg.mcpServers.playwright) { skip('playwright MCP server already in .mcp.json'); return; }
  cfg.mcpServers.playwright = { type: 'stdio', command: 'npx', args: ['-y', '@playwright/mcp@latest', '--caps=vision'], env: {} };
  fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
  ok('added playwright MCP server to .mcp.json');
}

// ---- 7. wire the bridge into the game --------------------------------------

function wireBridge(gameDir, args) {
  // 7a. copy the generic bridge
  const src = path.join(HERE, 'templates', 'agent_bridge.gd');
  const dstDir = path.join(gameDir, 'scripts', 'agent');
  const dst = path.join(dstDir, 'agent_bridge.gd');
  if (fs.existsSync(dst) && !args.force) {
    skip('agent_bridge.gd already in the game (use --force to refresh from template)');
  } else {
    fs.mkdirSync(dstDir, { recursive: true });
    fs.copyFileSync(src, dst);
    ok('copied agent_bridge.gd -> ' + path.relative(ROOT, dst));
  }

  // 7b. register the autoload in project.godot
  const projFile = path.join(gameDir, 'project.godot');
  let text = fs.readFileSync(projFile, 'utf8');
  if (/^\s*AgentBridge\s*=/m.test(text) || /AgentBridge=/.test(text)) {
    skip('AgentBridge autoload already registered');
  } else {
    const line = 'AgentBridge="*res://scripts/agent/agent_bridge.gd"';
    if (/^\[autoload\]/m.test(text)) {
      text = text.replace(/^\[autoload\][^\n]*\n/m, (m) => m + line + '\n');
    } else {
      // insert a new [autoload] section after [application] if present, else append
      if (/^\[display\]/m.test(text)) {
        text = text.replace(/^\[display\]/m, `[autoload]\n\n${line}\n\n[display]`);
      } else {
        text += `\n[autoload]\n\n${line}\n`;
      }
    }
    fs.writeFileSync(projFile, text);
    ok('registered AgentBridge autoload in project.godot');
  }

  // 7c. the per-game adapter — the one thing a script can't write
  const gdFiles = walkGd(path.join(gameDir, 'scripts'));
  const wired = gdFiles.some((f) => {
    try { return fs.readFileSync(f, 'utf8').includes('register_provider'); } catch { return false; }
  });
  if (wired) {
    ok('a state provider is registered (adapter looks wired)');
  } else {
    warn(
      'ADAPTER NEEDED: write the per-game adapter that maps your state -> the AgentState contract, ' +
        'and call AgentBridge.register_provider(...) from your main controller _ready(). ' +
        'Copy agent_play/templates/agent_adapter.example.gd and follow the /godot_agent_play skill Step 1. ' +
        'Also add a few AgentBridge.emit_event(...) calls (score/death/sfx) and an optional "Web-Agent" export preset.'
    );
  }
}

function walkGd(dir, acc = []) {
  let entries = [];
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return acc; }
  for (const e of entries) {
    if (e.name === 'addons' || e.name === '.godot' || e.name.startsWith('.')) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walkGd(p, acc);
    else if (e.name.endsWith('.gd')) acc.push(p);
  }
  return acc;
}

// ---- main ------------------------------------------------------------------

async function main() {
  const args = parseArgs(process.argv);
  console.log('agent_play setup — making this repo ready to run agent-play.\n');

  step('1/2. Install toolkit dependencies');
  if (args.skipInstall) skip('npm install (--skip-install)');
  else { await run('npm', ['install'], { cwd: HERE }); ok('npm install'); }
  if (args.skipBrowser) skip('playwright chromium (--skip-browser)');
  else { await run('npx', ['playwright', 'install', 'chromium'], { cwd: HERE }); ok('playwright chromium installed'); }

  step('3. Resolve the Godot project');
  const gameDir = await resolveProject(args);

  step('4. .env hygiene + verify the Claude Code CLI');
  await ensureAuth();

  step('5. Install the /godot_agent_play skill');
  installSkill(args);

  step('6. Configure the Playwright MCP server');
  mergeMcp();

  step('7. Wire the AgentBridge into the game');
  if (args.noWire) skip('bridge wiring (--no-wire)');
  else if (!gameDir) skip('bridge wiring (no project resolved)');
  else wireBridge(gameDir, args);

  // ---- summary
  console.log('\n========================================');
  console.log('agent_play setup summary');
  console.log('========================================');
  for (const r of results) console.log(r);
  const todos = results.filter((r) => r.includes('[todo]'));
  console.log('\nNext:');
  if (todos.length) {
    console.log('  Finish the [todo] item(s) above, then:');
  }
  if (gameDir) {
    console.log('  - Verify the game compiles:  godot --headless --path ' + (path.relative(ROOT, gameDir) || '.') + ' --import');
  }
  console.log('  - Run a personality:         node agent_play/harness.mjs --personality bug-hunter --steps 60');
  console.log('  - Or drive interactively:    node agent_play/server.mjs  (then open /index.html?agent=1)');
}

// This file is a CLI entry point — always run.
main().catch((err) => {
  console.error('\nsetup failed:', err.message);
  process.exit(1);
});
