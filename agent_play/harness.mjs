// agent-play harness: export -> serve -> launch Chromium -> drive a personality loop.
//
// Usage:
//   node harness.mjs --personality bug-hunter --steps 120 [--seed 123] [--headed] [--no-export] [--port 8099]
//
// Personalities: bug-hunter | bug-hunter-poe | art-director | visual-scale | juiciness | audio
//                | new-player | experienced-player
//
// Each step: freeze (time_scale 0) -> read state+events -> screenshot (cadence) ->
// run oracles -> ask Claude for an action -> execute via the control channel ->
// unfreeze + settle. A run report is written to runs/<ts>-<personality>/.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';
import { config, ROOT } from './config.mjs';
import { startServer } from './server.mjs';
import { installAudioProbe } from './audio_probe.mjs';
import { loadPersonality, PERSONALITIES } from './personalities/index.mjs';
import { createOracles } from './oracles.mjs';
import { createReport } from './report.mjs';
import { decide, summarize, checkCliAvailable } from './claude_cli.mjs';

function parseArgs(argv) {
  const a = {
    personality: 'bug-hunter',
    steps: config.defaultSteps,
    seed: null,
    headed: false,
    export: true,
    port: config.port,
  };
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    if (k === '--personality' || k === '-p') a.personality = argv[++i];
    else if (k === '--steps' || k === '-s') a.steps = Number(argv[++i]);
    else if (k === '--seed') a.seed = Number(argv[++i]);
    else if (k === '--headed') a.headed = true;
    else if (k === '--no-export') a.export = false;
    else if (k === '--port') a.port = Number(argv[++i]);
    else if (k === '--help' || k === '-h') a.help = true;
  }
  return a;
}

function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: 'inherit', shell: process.platform === 'win32', ...opts });
    p.on('error', reject);
    p.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`${cmd} exited with code ${code}`))));
  });
}

async function exportWeb() {
  const out = path.join(config.buildDir, 'index.html');
  fs.mkdirSync(config.buildDir, { recursive: true });
  console.log(`[export] ${config.godotProjectName}: --export-release "${config.exportPreset}" -> ${out}`);
  // Absolute --path + absolute output: a relative output would resolve against the project dir.
  await run(config.godotBin, ['--headless', '--path', config.godotProjectDir, '--export-release', config.exportPreset, out], {
    cwd: ROOT,
  });
}

const send = (page, cmd) =>
  page.evaluate((j) => window.__agentControl && window.__agentControl.send(j), JSON.stringify(cmd));

const readPage = (page) =>
  page.evaluate(() => ({
    state: window.__agentStateJson || null,
    events: window.__agentEventsJson || '[]',
    audioLen: (window.__agentAudioLog && window.__agentAudioLog.length) || 0,
  }));

const readAudioSince = (page, sinceLen) =>
  page.evaluate((n) => (window.__agentAudioLog || []).slice(n), sinceLen);

async function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    console.log(`Personalities: ${PERSONALITIES.join(' | ')}`);
    console.log('node harness.mjs --personality <name> --steps <n> [--seed n] [--headed] [--no-export] [--port n]');
    return;
  }
  const persona = loadPersonality(args.personality);
  console.log(`[project] ${config.godotProjectName} (${config.godotProjectDir})`);
  const cli = checkCliAvailable();
  if (!cli.ok) {
    console.error(`ERROR: ${cli.message}`);
    process.exit(1);
  }
  console.log(`[llm] Claude Code CLI ${cli.version} — billed to your subscription (model: ${config.model})`);
  if (process.env.ANTHROPIC_API_KEY) {
    console.log('[llm] note: ANTHROPIC_API_KEY is set but ignored — the CLI uses your subscription login.');
  }

  if (args.export) {
    await exportWeb();
  }
  const indexPath = path.join(config.buildDir, 'index.html');
  if (!fs.existsSync(indexPath)) {
    console.error(`ERROR: no build at ${indexPath}. Run without --no-export, or export first.`);
    process.exit(1);
  }

  const server = await startServer({ port: args.port });
  const report = createReport({ personality: persona.name });
  const oracles = createOracles();
  const transcript = [];
  const startedAt = new Date().toISOString();

  const browser = await chromium.launch({
    headless: !args.headed,
    // WebGL flags are REQUIRED for a Godot build to render in headless Chromium — modern
    // headless disables SwiftShader WebGL by default, so the game won't boot without these.
    args: [
      '--autoplay-policy=no-user-gesture-required',
      '--enable-unsafe-swiftshader',
      '--use-gl=angle',
      '--use-angle=swiftshader',
      '--ignore-gpu-blocklist',
    ],
  });
  const page = await browser.newPage({ viewport: { width: 800, height: 640 } });

  // Page-level signals for the oracles.
  const pageErrors = [];
  let crashed = false;
  page.on('console', (m) => {
    if (m.type() === 'error') pageErrors.push(m.text());
  });
  page.on('pageerror', (e) => pageErrors.push(String(e)));
  page.on('crash', () => {
    crashed = true;
  });

  // Install the audio probe BEFORE the game boots (so it wraps WebAudio first).
  await page.addInitScript(installAudioProbe);

  let lastSeq = 0;
  let audioLen = 0;
  let prevShotB64 = null;
  let metaSeen = {};
  let finalState = null;

  try {
    const url = `${server.url}/index.html?agent=1`;
    console.log(`[load] ${url}`);
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => window.__agentReady === true, { timeout: config.readyTimeoutMs });
    console.log(`[ready] agent bridge is live. Driving personality: ${persona.name}`);

    if (args.seed != null) {
      await send(page, { type: 'set_seed', value: args.seed });
    }

    const canvas = page.locator('#canvas');

    for (let step = 1; step <= args.steps; step++) {
      // 1) Freeze so the game doesn't advance while Claude thinks.
      await send(page, { type: 'set_time_scale', value: 0 });

      // 2) Read state + new events.
      const raw = await readPage(page);
      if (!raw.state) {
        await send(page, { type: 'set_time_scale', value: 1 });
        await page.waitForTimeout(config.tickSettleMs);
        continue;
      }
      const state = JSON.parse(raw.state);
      finalState = state;
      metaSeen = state.meta || metaSeen;
      const allEvents = JSON.parse(raw.events || '[]');
      const newEvents = allEvents.filter((e) => e.seq > lastSeq);
      if (newEvents.length) lastSeq = Math.max(...newEvents.map((e) => e.seq));
      await send(page, { type: 'ack_events', seq: lastSeq });

      // New audio probe entries since last step (for the audio personality).
      let newAudio = [];
      if (raw.audioLen > audioLen) {
        newAudio = await readAudioSince(page, audioLen);
        audioLen = raw.audioLen;
      }

      // 3) Screenshot on the personality's cadence.
      let shotRel = null;
      const images = [];
      const wantShot = persona.screenshotEvery && step % persona.screenshotEvery === 0;
      if (wantShot) {
        let buf;
        try {
          buf = await canvas.screenshot();
        } catch {
          buf = await page.screenshot();
        }
        const b64 = buf.toString('base64');
        shotRel = report.saveScreenshot(buf, step);
        if (persona.pairedShots && prevShotB64) {
          images.push({ label: 'BEFORE (previous frame):', b64: prevShotB64 });
          images.push({ label: 'AFTER (current frame):', b64 });
        } else {
          images.push({ label: 'Current frame:', b64 });
        }
        prevShotB64 = b64;
      }

      // 4) Oracles (state + page signals).
      const drainedErrors = pageErrors.splice(0, pageErrors.length);
      const oracleFindings = oracles.check({
        state,
        newEvents,
        pageSignals: { errors: drainedErrors, crashed },
        actedThisStep: step > 1, // we issued an action on every prior step
      });
      report.addFindings(oracleFindings, step);

      // 5) Decide.
      let action = 'noop';
      let reason = '';
      let claimFindings = [];
      try {
        const d = await decide({
          system: persona.system,
          state,
          events: newEvents,
          audio: persona.name === 'audio' ? newAudio : [],
          availableActions: state.available_actions,
          images,
        });
        action = d.action;
        reason = d.reason;
        claimFindings = d.findings;
      } catch (err) {
        console.error(`[decide] error at step ${step}: ${err.message}`);
      }
      report.addFindings(claimFindings.map((f) => ({ ...f, source: 'claude' })), step);

      // 6) Execute (discrete tap; press/release available for held-input games).
      if (action && action !== 'noop') {
        await send(page, { type: 'tap', action });
      }

      // 7) Unfreeze and let consequences (and their events) materialize.
      await send(page, { type: 'set_time_scale', value: 1 });
      await page.waitForTimeout(config.tickSettleMs);

      // 8) Log + transcript.
      const stepLog = {
        step,
        phase: state.phase,
        score: state.score,
        action,
        reason,
        newEvents,
        newAudio,
        findings: [...oracleFindings, ...claimFindings],
        screenshot: shotRel,
        frame: (state.meta || {}).frame,
        tick: (state.meta || {}).tick,
      };
      report.logStep(stepLog);
      transcript.push(
        `Step ${step} [${state.phase}] score=${state.score} action=${action} :: ${reason}` +
          (newEvents.length ? ` | events: ${newEvents.map((e) => e.type).join(',')}` : '') +
          (claimFindings.length ? ` | notes: ${claimFindings.map((f) => `${f.severity}:${f.title}`).join('; ')}` : '')
      );

      if (crashed) {
        console.error('[crash] page crashed — stopping.');
        break;
      }
      if (step % 10 === 0) console.log(`[step ${step}/${args.steps}] phase=${state.phase} score=${state.score} action=${action}`);
    }

    // Final summary from the personality.
    console.log('[summarize] generating final report...');
    let summaryMarkdown = '';
    try {
      const transcriptText =
        transcript.join('\n').slice(-16000) + // keep the tail bounded
        `\n\nFinal state: ${JSON.stringify(finalState)}`;
      summaryMarkdown = await summarize({ system: persona.system, transcript: transcriptText });
    } catch (err) {
      summaryMarkdown = `_(summary failed: ${err.message})_`;
    }

    const findingsPath = await report.finish({
      summaryMarkdown,
      meta: {
        game_id: metaSeen.game_id,
        version: metaSeen.version,
        steps: args.steps,
        model: config.model,
        startedAt,
      },
    });
    console.log(`\nDone. ${report.findingsCount()} findings.`);
    console.log(`Report: ${findingsPath}`);
    console.log(`Run dir: ${report.dir}`);
  } finally {
    await browser.close();
    await server.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
