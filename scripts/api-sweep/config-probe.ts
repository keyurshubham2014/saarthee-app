// Run by env.mjs with tsx (cwd apps/api): for each variable in __SWEEP_VARS, does parseConfig fail when it is removed
// from __SWEEP_FULL? Prints variable names and config error messages only (messages never contain values).
import { parseConfig } from '../../apps/api/src/config/index';

const full = JSON.parse(process.env.__SWEEP_FULL ?? '{}') as Record<string, string>;
const out: Record<string, string | null> = {};
for (const name of JSON.parse(process.env.__SWEEP_VARS ?? '[]') as string[]) {
  const e: Record<string, string | undefined> = { ...full };
  delete e[name];
  const r = parseConfig(e);
  out[name] = r.ok ? null : r.errors.filter((l) => l.includes(name)).join(' | ') || r.errors.join(' | ');
}
console.log('__SWEEP__' + JSON.stringify(out));
