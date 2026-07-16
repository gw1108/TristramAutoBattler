// Free boot check (NO Anthropic API calls): serve the existing web build, load it in headless
// Chromium with the agent gate (?agent=1), and confirm the AgentBridge goes live and the per-game
// adapter publishes valid AgentState. Use this to verify a build is functional + the adapter is wired
// before spending tokens on a full harness run, and to prove an export is good despite Godot's
// headless export segfaulting on shutdown (it writes a valid build, then crashes on exit on Windows).
//
// Usage:  node agent_play/boot-check.mjs
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { startServer } from './server.mjs';
import { config } from './config.mjs';

const indexPath = path.join(config.buildDir, 'index.html');
if (!fs.existsSync(indexPath)) {
  console.error(`[boot-check] no build at ${indexPath}. Export the "Web" preset first.`);
  process.exit(1);
}

const server = await startServer({ port: config.port });
const browser = await chromium.launch({
  headless: true,
  args: [
    '--autoplay-policy=no-user-gesture-required',
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--ignore-gpu-blocklist',
  ],
});
const page = await browser.newPage({ viewport: { width: 800, height: 640 } });
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

let state = null;
try {
  const url = `${server.url}/index.html?agent=1`;
  console.log(`[boot-check] loading ${url}`);
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => window.__agentReady === true, { timeout: config.readyTimeoutMs });
  await page.waitForTimeout(600); // settle a few frames so the adapter publishes live state
  const raw = await page.evaluate(() => window.__agentStateJson);
  state = raw ? JSON.parse(raw) : null;
} catch (e) {
  console.error(`[boot-check] FAILED: ${e.message}`);
  if (errors.length) console.error('  page errors:', errors.slice(0, 5));
} finally {
  await browser.close();
  await server.close();
}

if (state) {
  const p = state.player || {};
  console.log('[boot-check] PASS — agent bridge live, adapter publishing state.');
  console.log(`  phase=${state.phase} score=${state.score} entities=${(state.entities || []).length}`);
  console.log(`  player: pos=${JSON.stringify(p.pos)} hp=${p.health}/${p.max_health} lvl=${(p.extra || {}).level}`);
  console.log(`  available_actions=[${(state.available_actions || []).join(', ')}]`);
  process.exit(0);
} else {
  console.error('[boot-check] no AgentState was published — bridge/adapter not live or build broken.');
  process.exit(2);
}
