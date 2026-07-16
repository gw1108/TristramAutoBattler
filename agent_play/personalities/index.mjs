// Personality registry. Each maps a name to its system-prompt file plus loop config:
//   screenshotEvery : take a canvas screenshot every N steps (0 = never)
//   pairedShots     : pass the previous + current frame together (for before/after feel)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.dirname(fileURLToPath(import.meta.url));

const SPECS = {
  'bug-hunter': { file: 'bug_hunter.md', screenshotEvery: 10, pairedShots: false },
  'bug-hunter-poe': { file: 'bug_hunter_poe.md', screenshotEvery: 10, pairedShots: false },
  'art-director': { file: 'art_director.md', screenshotEvery: 2, pairedShots: false },
  'visual-scale': { file: 'visual_scale.md', screenshotEvery: 2, pairedShots: false },
  'juiciness': { file: 'juiciness_evaluator.md', screenshotEvery: 1, pairedShots: true },
  'audio': { file: 'audio_evaluator.md', screenshotEvery: 8, pairedShots: false },
  'new-player': { file: 'new_player_experience.md', screenshotEvery: 4, pairedShots: false },
  'experienced-player': { file: 'experienced_player_experience.md', screenshotEvery: 6, pairedShots: false },
};

export const PERSONALITIES = Object.keys(SPECS);

export function loadPersonality(name) {
  const spec = SPECS[name];
  if (!spec) {
    throw new Error(`Unknown personality '${name}'. Options: ${PERSONALITIES.join(', ')}`);
  }
  const system = fs.readFileSync(path.join(dir, spec.file), 'utf8');
  return { name, system, ...spec };
}
