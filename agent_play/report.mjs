// Writes a run report: runs/<ts>-<personality>/{session.jsonl, screenshots/*.png, findings.md}.
import fs from 'node:fs';
import path from 'node:path';
import { config } from './config.mjs';

const SEV_ORDER = { critical: 0, high: 1, medium: 2, low: 3, info: 4 };

export function createReport({ personality }) {
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const dir = path.join(config.runsDir, `${ts}-${personality}`);
  const shotsDir = path.join(dir, 'screenshots');
  fs.mkdirSync(shotsDir, { recursive: true });
  const jsonlPath = path.join(dir, 'session.jsonl');
  const jsonl = fs.createWriteStream(jsonlPath, { flags: 'a' });
  const findings = [];

  return {
    dir,
    logStep(obj) {
      jsonl.write(JSON.stringify(obj) + '\n');
    },
    addFindings(list, step) {
      for (const x of list) findings.push({ ...x, step });
    },
    saveScreenshot(buf, step) {
      const rel = path.join('screenshots', `step-${String(step).padStart(4, '0')}.png`);
      fs.writeFileSync(path.join(dir, rel), buf);
      return rel;
    },
    findingsCount() {
      return findings.length;
    },
    finish({ summaryMarkdown, meta }) {
      return new Promise((resolve) => {
        jsonl.end(() => {
          fs.writeFileSync(path.join(dir, 'findings.md'), buildMd({ personality, meta, findings, summaryMarkdown }));
          resolve(path.join(dir, 'findings.md'));
        });
      });
    },
  };
}

function buildMd({ personality, meta, findings, summaryMarkdown }) {
  const sorted = [...findings].sort(
    (a, b) => (SEV_ORDER[a.severity] ?? 9) - (SEV_ORDER[b.severity] ?? 9) || a.step - b.step
  );
  const counts = {};
  for (const f of findings) counts[f.severity] = (counts[f.severity] || 0) + 1;

  let md = `# Agent-play report — ${personality}\n\n`;
  md += `- Game: ${meta.game_id || 'unknown'} v${meta.version || '?'}\n`;
  md += `- Steps: ${meta.steps}\n`;
  md += `- Model: ${meta.model}\n`;
  md += `- Run: ${meta.startedAt}\n`;
  md += `- Findings: ${findings.length} (${Object.entries(counts).map(([k, v]) => `${k}:${v}`).join(', ') || 'none'})\n\n`;

  md += `## Summary\n\n${summaryMarkdown || '_(no summary produced)_'}\n\n`;

  md += `## Findings (by severity)\n\n`;
  if (!sorted.length) {
    md += '_No findings recorded._\n';
  } else {
    for (const f of sorted) {
      md += `- **[${f.severity}]** ${f.title}${f.source ? ` _(${f.source})_` : ''} — step ${f.step}\n`;
      if (f.detail) md += `  - ${f.detail}\n`;
    }
  }
  md += `\n_Full per-step trace: session.jsonl. Screenshots: screenshots/._\n`;
  return md;
}
