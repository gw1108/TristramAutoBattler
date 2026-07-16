// LLM transport for the agent-play loop — drives the local **Claude Code CLI** so every
// call is billed against your Claude subscription (OAuth login), NOT an ANTHROPIC_API_KEY.
//
// Why the CLI instead of the Anthropic SDK: the SDK / Agent SDK can only authenticate with an
// API key (console billing). The `claude` CLI falls back to your Pro/Max subscription login when
// no API key is present — so we spawn `claude -p` and strip ANTHROPIC_API_KEY from its env.
//
// `decide` forces structured output (--json-schema) so every step returns a parseable action drawn
// from the current `available_actions`; `summarize` returns the final free-text report.
//
// Transport details (all verified against claude 2.x):
//   * spawn the native binary directly with shell:false so big/complex args (schema, persona,
//     multi-KB state) are passed as argv with no shell-quoting hazards;
//   * stream-json IN (stdin) carries the user message — including base64 image blocks for vision —
//     so large prompts never hit the OS argv length limit; stream-json OUT (+ --verbose) is required
//     to pair with stream-json input. We read the final {type:"result"} event;
//   * --system-prompt REPLACES Claude Code's default agent prompt with the persona (and suppresses
//     the dynamic cwd/git/env sections), and cwd is a neutral temp dir so the repo's CLAUDE.md and
//     project settings are not auto-loaded into the judgment call.
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { config } from './config.mjs';

const BIN = process.platform === 'win32' ? 'claude.exe' : 'claude';

// Neutral, empty working dir: keeps the repo's CLAUDE.md / .claude settings out of the prompt.
const WORKDIR = path.join(os.tmpdir(), 'agent_play_cli');
try {
  fs.mkdirSync(WORKDIR, { recursive: true });
} catch {
  /* best effort */
}

const CALL_TIMEOUT_MS = Number(process.env.AGENT_CLI_TIMEOUT_MS || 120000);

function imageBlocks(images) {
  // images: [{ label, b64 }]
  const blocks = [];
  for (const img of images || []) {
    if (!img || !img.b64) continue;
    if (img.label) blocks.push({ type: 'text', text: img.label });
    blocks.push({
      type: 'image',
      source: { type: 'base64', media_type: 'image/png', data: img.b64 },
    });
  }
  return blocks;
}

const DECIDE_SCHEMA = {
  type: 'object',
  properties: {
    action: {
      type: 'string',
      description:
        'The single action to take this step. Must be one of available_actions, or "noop" to do nothing.',
    },
    reason: { type: 'string', description: 'One short sentence on why.' },
    findings: {
      type: 'array',
      description:
        'Observations, bugs, or critiques noticed THIS step. May be empty. Be specific and evidence-based.',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['info', 'low', 'medium', 'high', 'critical'] },
          title: { type: 'string' },
          detail: { type: 'string' },
        },
        required: ['severity', 'title'],
      },
    },
  },
  required: ['action'],
};

// One CLI invocation. `content` is an Anthropic-style content block array (text [+ images]).
// Returns the parsed {type:"result"} event from the stream-json output.
function invoke({ system, content, schema }) {
  return new Promise((resolve, reject) => {
    const env = { ...process.env };
    delete env.ANTHROPIC_API_KEY; // force subscription (OAuth) instead of API-key billing
    delete env.ANTHROPIC_AUTH_TOKEN;

    const args = [
      '-p',
      '--input-format', 'stream-json',
      '--output-format', 'stream-json',
      '--verbose', // required to pair with stream-json output
      '--model', config.model,
      '--system-prompt', system,
    ];
    if (schema) args.push('--json-schema', JSON.stringify(schema));

    const child = spawn(BIN, args, {
      env,
      cwd: WORKDIR,
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true,
    });

    let out = '';
    let err = '';
    let done = false;
    const finish = (fn, arg) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      fn(arg);
    };
    const timer = setTimeout(() => {
      try {
        child.kill('SIGKILL');
      } catch {
        /* ignore */
      }
      finish(reject, new Error(`claude CLI timed out after ${CALL_TIMEOUT_MS}ms`));
    }, CALL_TIMEOUT_MS);

    child.stdout.on('data', (d) => (out += d));
    child.stderr.on('data', (d) => (err += d));
    child.on('error', (e) =>
      finish(
        reject,
        new Error(
          `failed to spawn '${BIN}': ${e.message}. Is the Claude Code CLI installed and on PATH?`,
        ),
      ),
    );
    child.on('close', (code) => {
      let result = null;
      for (const line of out.split('\n')) {
        const s = line.trim();
        if (!s) continue;
        try {
          const o = JSON.parse(s);
          if (o && o.type === 'result') result = o;
        } catch {
          /* non-JSON line, ignore */
        }
      }
      if (!result) {
        finish(
          reject,
          new Error(
            `claude CLI produced no result (exit ${code}). stderr: ${err.trim().slice(0, 400) || '(empty)'}`,
          ),
        );
        return;
      }
      if (result.is_error || result.subtype !== 'success') {
        finish(
          reject,
          new Error(
            `claude CLI error (${result.subtype || 'unknown'}): ${String(result.result || err).slice(0, 400)}`,
          ),
        );
        return;
      }
      finish(resolve, result);
    });

    const msg = { type: 'user', message: { role: 'user', content } };
    child.stdin.write(JSON.stringify(msg) + '\n');
    child.stdin.end();
  });
}

// One transient retry — a single overloaded/flaky call shouldn't abort a 120-step run.
async function invokeWithRetry(opts) {
  try {
    return await invoke(opts);
  } catch (e) {
    await new Promise((r) => setTimeout(r, 1500));
    return invoke(opts);
  }
}

export async function decide({ system, state, events, audio, availableActions, images }) {
  const actions = availableActions && availableActions.length ? availableActions : [];
  const allowed = [...actions, 'noop'];

  const content = [...imageBlocks(images)];
  let text =
    `AgentState (current):\n\`\`\`json\n${JSON.stringify(state)}\n\`\`\`\n\n` +
    `New events since last step:\n\`\`\`json\n${JSON.stringify(events || [])}\n\`\`\`\n\n`;
  if (audio && audio.length) {
    text += `Audio playback attempts (from the WebAudio probe) since last step:\n\`\`\`json\n${JSON.stringify(audio)}\n\`\`\`\n\n`;
  }
  text +=
    `Legal actions this step: ${JSON.stringify(allowed)}.\n` +
    `Respond with the structured object: pick one action from that list and report any findings.`;
  content.push({ type: 'text', text });

  const result = await invokeWithRetry({ system, content, schema: DECIDE_SCHEMA });

  let input = result.structured_output;
  if (!input || typeof input !== 'object') {
    try {
      input = JSON.parse(result.result); // fallback: schema text in the result field
    } catch {
      input = {};
    }
  }
  let action = typeof input.action === 'string' ? input.action : 'noop';
  if (!allowed.includes(action)) action = 'noop'; // guard against off-list actions
  return {
    action,
    reason: input.reason || '',
    findings: Array.isArray(input.findings) ? input.findings : [],
    usage: result.usage || null,
  };
}

export async function summarize({ system, transcript }) {
  const sys =
    system +
    '\n\n---\nThe play session is over. Write your FINAL REPORT in Markdown based on the session log below. ' +
    'Follow the output format described in your role above (scorecard / findings / coverage matrix as applicable). ' +
    'Be concrete and cite specific steps/events.';
  const result = await invokeWithRetry({
    system: sys,
    content: [{ type: 'text', text: transcript }],
  });
  return String(result.result || '').trim();
}

// Fail fast in the harness if the CLI transport can't work, with an actionable message.
export function checkCliAvailable() {
  let probe;
  try {
    probe = spawnSync(BIN, ['--version'], { encoding: 'utf8', windowsHide: true });
  } catch (e) {
    probe = { error: e };
  }
  if (!probe || probe.error || probe.status !== 0) {
    return {
      ok: false,
      message:
        `Claude Code CLI ('${BIN}') not found or not runnable on PATH. Install it and run ` +
        `'claude /login' with your Pro/Max subscription. ` +
        `(agent_play bills against your subscription, not ANTHROPIC_API_KEY.)`,
    };
  }
  return { ok: true, version: (probe.stdout || '').trim() };
}
