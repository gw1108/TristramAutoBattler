// Browser-side audio probe, injected via page.addInitScript BEFORE the game boots.
//
// A headless browser has no audio device, so nothing is audible — but we can still
// observe what the engine *tries* to play. This monkey-patches the WebAudio source
// nodes and <audio>/<video> playback so every attempt is logged to window.__agentAudioLog.
// The audio-evaluator cross-checks this ground truth against the game's declared
// `sfx_played`/`music_changed` events (catches "logged an sfx event but never triggered
// WebAudio", and vice-versa).
//
// This function is serialized and run in the PAGE — it must not reference anything
// from the Node module scope.
export function installAudioProbe() {
  if (window.__agentAudioInstalled) return;
  window.__agentAudioInstalled = true;
  window.__agentAudioLog = [];

  const log = (kind, detail) => {
    try {
      window.__agentAudioLog.push({
        t: (window.performance && performance.now()) || 0,
        kind,
        detail: detail || null,
      });
      // Keep the log bounded.
      if (window.__agentAudioLog.length > 2000) window.__agentAudioLog.splice(0, 1000);
    } catch (e) {
      /* ignore */
    }
  };

  const wrap = (proto, name, kind, detailFn) => {
    if (!proto || typeof proto[name] !== 'function' || proto[name].__agentWrapped) return;
    const orig = proto[name];
    const patched = function (...args) {
      try {
        log(kind, detailFn ? detailFn(this, args) : null);
      } catch (e) {
        /* ignore */
      }
      return orig.apply(this, args);
    };
    patched.__agentWrapped = true;
    proto[name] = patched;
  };

  // Per-sound playback signals. NOTE: these catch sounds in games that play discrete
  // WebAudio nodes (Howler.js, hand-rolled Web Audio, <audio> tags). They do NOT catch
  // Godot, which mixes ALL audio in a single AudioWorklet — individual SFX never appear
  // as separate BufferSource.start() calls. For Godot, the game's `sfx_played` events are
  // the per-sound signal; the AudioContext lifecycle below is the probe's Godot signal.
  if (window.AudioScheduledSourceNode) {
    wrap(AudioScheduledSourceNode.prototype, 'start', 'source_start', null);
  } else {
    if (window.AudioBufferSourceNode) wrap(AudioBufferSourceNode.prototype, 'start', 'buffer_source_start', null);
    if (window.OscillatorNode) wrap(OscillatorNode.prototype, 'start', 'oscillator_start', null);
  }
  if (window.HTMLMediaElement) {
    wrap(HTMLMediaElement.prototype, 'play', 'media_play', (el) => ({
      src: el.currentSrc || el.src || '',
    }));
  }

  // AudioContext lifecycle — proves the audio subsystem initialized and resumed. This is
  // the reliable WebAudio signal for engines (like Godot) that mix in a worklet. Catches
  // "audio never initializes / context stays suspended" bugs.
  const Ctx = window.AudioContext || window.webkitAudioContext;
  if (Ctx && !Ctx.__agentWrapped) {
    const Orig = Ctx;
    const Wrapped = function (...a) {
      const inst = new Orig(...a);
      log('audiocontext_created', { state: inst.state, sampleRate: inst.sampleRate });
      try {
        const origResume = inst.resume.bind(inst);
        inst.resume = function () {
          log('audiocontext_resume', null);
          return origResume();
        };
      } catch (e) {
        /* ignore */
      }
      return inst;
    };
    Wrapped.prototype = Orig.prototype;
    Wrapped.__agentWrapped = true;
    try {
      window.AudioContext = Wrapped;
    } catch (e) {
      /* ignore */
    }
    try {
      if (window.webkitAudioContext) window.webkitAudioContext = Wrapped;
    } catch (e) {
      /* ignore */
    }
  }
}
