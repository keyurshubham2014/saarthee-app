/**
 * Minimal five-field cron matcher (minute hour day-of-month month day-of-week) so the runner needs no
 * scheduling dependency. Supports `*`, `*\/n`, `a`, `a-b`, `a-b/n` and comma lists. Day-of-week 0 and 7
 * are Sunday. When both day fields are restricted, a date matches if either matches (classic cron).
 */
const RANGES: [number, number][] = [
  [0, 59],
  [0, 23],
  [1, 31],
  [1, 12],
  [0, 7],
];

export interface CronSpec {
  fields: Set<number>[];
  domStar: boolean;
  dowStar: boolean;
}

function parseField(text: string, [min, max]: [number, number]): Set<number> {
  const out = new Set<number>();
  for (const part of text.split(',')) {
    const m = /^(\*|(\d+)(?:-(\d+))?)(?:\/(\d+))?$/.exec(part);
    if (!m) throw new Error(`invalid cron field "${text}"`);
    const step = m[4] ? Number(m[4]) : 1;
    const lo = m[1] === '*' ? min : Number(m[2]);
    const hi = m[1] === '*' ? max : m[3] !== undefined ? Number(m[3]) : m[4] ? max : lo;
    if (step < 1 || lo < min || hi > max || lo > hi) throw new Error(`invalid cron field "${text}"`);
    for (let v = lo; v <= hi; v += step) out.add(v);
  }
  return out;
}

export function parseCron(expr: string): CronSpec {
  const parts = expr.trim().split(/\s+/);
  if (parts.length !== 5) throw new Error(`cron "${expr}" must have 5 fields`);
  const fields = parts.map((p, i) => parseField(p, RANGES[i]!));
  if (fields[4]!.has(7)) fields[4]!.add(0);
  return { fields, domStar: parts[2] === '*', dowStar: parts[4] === '*' };
}

export function cronMatches(spec: CronSpec, d: Date): boolean {
  const [min, hour, dom, mon, dow] = spec.fields as [Set<number>, Set<number>, Set<number>, Set<number>, Set<number>];
  if (!min.has(d.getMinutes()) || !hour.has(d.getHours()) || !mon.has(d.getMonth() + 1)) return false;
  const domOk = dom.has(d.getDate());
  const dowOk = dow.has(d.getDay());
  if (spec.domStar || spec.dowStar) return domOk && dowOk;
  return domOk || dowOk;
}
