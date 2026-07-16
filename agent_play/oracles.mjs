// Personality-independent invariant checks. Pure-ish: a small closure holds history.
//
// These run every step regardless of personality and catch the failures an LLM critic
// might miss or rationalize away: engine hangs, gameplay softlocks, NaN/out-of-bounds
// positions, and dead inputs (an action that produced no event and no movement).
//
// Note on freezing: the harness sets time_scale=0 while it thinks, but AgentBridge's
// _process still runs (delta=0), so meta.frame keeps advancing — a frozen frame means a
// REAL engine hang, not a deliberate pause. No suppression needed.
import { config } from './config.mjs';

function finding(severity, type, detail) {
  return { severity, title: type, detail, source: 'oracle' };
}

function isFinite2(p) {
  return Array.isArray(p) && p.length >= 2 && Number.isFinite(p[0]) && Number.isFinite(p[1]);
}

export function createOracles() {
  let step = 0;
  let lastFrame = null;
  let lastFrameStep = 0;
  let lastProgressSig = null;
  let staleSteps = 0;
  const fired = new Set(); // de-dupe one-shot findings by type

  function once(out, sev, type, detail) {
    if (fired.has(type)) return;
    fired.add(type);
    out.push(finding(sev, type, detail));
  }

  return {
    // pageSignals: { errors: string[] (drained), crashed: bool }
    check({ state, newEvents, pageSignals, actedThisStep }) {
      step++;
      const out = [];
      const meta = state.meta || {};

      // --- Browser-level signals ---
      if (pageSignals) {
        for (const e of pageSignals.errors || []) out.push(finding('high', 'console_error', e));
        if (pageSignals.crashed) once(out, 'critical', 'page_crash', 'The browser page crashed.');
      }

      // --- Engine hang: render frame counter not advancing ---
      if (meta.frame === lastFrame) {
        if (step - lastFrameStep > config.hangSteps) {
          once(out, 'critical', 'engine_hang', `meta.frame stuck at ${meta.frame} for ${step - lastFrameStep} steps.`);
        }
      } else {
        lastFrame = meta.frame;
        lastFrameStep = step;
      }

      // --- Gameplay softlock: no logical progress while playing and acting ---
      if (state.phase === 'playing' && actedThisStep) {
        const tick = meta.tick;
        const sig =
          tick !== undefined && tick !== null
            ? `tick:${tick}`
            : `score:${state.score}|pos:${JSON.stringify(state.player && state.player.pos)}`;
        const hadEvents = (newEvents || []).length > 0;
        if (sig === lastProgressSig && !hadEvents) {
          staleSteps++;
          if (staleSteps === config.softlockSteps) {
            out.push(
              finding('medium', 'gameplay_softlock', `No state change for ${staleSteps} acting steps while phase=playing.`)
            );
          }
        } else {
          staleSteps = 0;
          lastProgressSig = sig;
        }
      }

      // --- NaN / out-of-bounds positions ---
      const w = state.world || {};
      const b = w.bounds;
      const checkPos = (label, pos) => {
        if (pos == null) return;
        if (!isFinite2(pos)) {
          out.push(finding('high', 'nan_position', `${label} position is non-finite: ${JSON.stringify(pos)}`));
          return;
        }
        if (b && w.coordinate_space) {
          const [x, y] = pos;
          // allow a small margin for pixel-space games
          const margin = w.coordinate_space === 'pixels' ? Math.max(8, (w.cell_size || 0)) : 0;
          if (x < b.min[0] - margin || x > b.max[0] + margin || y < b.min[1] - margin || y > b.max[1] + margin) {
            out.push(finding('medium', 'out_of_bounds', `${label} at ${JSON.stringify(pos)} is outside bounds ${JSON.stringify(b)}`));
          }
        }
      };
      if (state.player) checkPos('player', state.player.pos);
      for (const e of state.entities || []) checkPos(`entity ${e.id || e.type}`, e.pos);

      // --- Dead input: acted, but nothing happened (also a juiciness signal) ---
      if (actedThisStep && state.phase === 'playing') {
        const hadEvents = (newEvents || []).length > 0;
        const sig = `score:${state.score}|pos:${JSON.stringify(state.player && state.player.pos)}`;
        if (!hadEvents && sig === lastProgressSig && staleSteps > 0 && staleSteps % 8 === 0) {
          out.push(finding('low', 'dead_input', 'Action issued but produced no event and no observable change.'));
        }
      }

      return out;
    },
  };
}
