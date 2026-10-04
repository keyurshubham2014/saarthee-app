// TASK-06 §7.2: no status write anywhere except through transition() (src/modules/lifecycle).
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { expect, it } from 'vitest';

const SRC = path.join(__dirname, '../../src');

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((f) => {
    const p = path.join(dir, f);
    return statSync(p).isDirectory() ? files(p) : p.endsWith('.ts') ? [p] : [];
  });
}

it('only modules/lifecycle writes issues.status', () => {
  const offenders: string[] = [];
  for (const file of files(SRC)) {
    if (file.includes(`${path.sep}modules${path.sep}lifecycle${path.sep}`)) continue;
    const text = readFileSync(file, 'utf8');
    const orm = /\.issue\.(update|updateMany|upsert)\(\{[\s\S]{0,400}?data:\s*\{[^}]*\bstatus\s*:/g;
    const raw = /UPDATE\s+issues\s+SET[^;`]*\bstatus\s*=/gi;
    if (orm.test(text) || raw.test(text)) offenders.push(path.relative(SRC, file));
  }
  expect(offenders).toEqual([]);
});
