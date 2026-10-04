/**
 * City-time helpers (V2 TASK-12 §6 step 7; shared with TASK-08 alerts). Quiet hours are a local
 * "HH:MM-HH:MM" window in TZ_CITY that may wrap midnight (default "22:00-07:00", Asia/Kolkata).
 */
export const DEFAULT_QUIET_HOURS = '22:00-07:00';
export const DEFAULT_TZ = 'Asia/Kolkata';

interface LocalParts {
  year: number;
  month: number;
  day: number;
  minutes: number;
}

function localParts(now: Date, tz: string): LocalParts {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const n = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? 0);
  return { year: n('year'), month: n('month'), day: n('day'), minutes: n('hour') * 60 + n('minute') };
}

function parseWindow(window: string): [number, number] {
  const m = /^(\d{2}):(\d{2})-(\d{2}):(\d{2})$/.exec(window.trim());
  if (!m) throw new Error(`invalid quiet hours window: ${window}`);
  const [, h1, m1, h2, m2] = m.map(Number) as [number, number, number, number, number];
  return [h1 * 60 + m1, h2 * 60 + m2];
}

/** Offset of `tz` from UTC at `now`, in minutes. */
function offsetMinutes(now: Date, tz: string): number {
  const p = localParts(now, tz);
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, Math.floor(p.minutes / 60), p.minutes % 60);
  return Math.round((asUtc - Math.floor(now.getTime() / 60_000) * 60_000) / 60_000);
}

export function isQuietHours(now: Date, window = DEFAULT_QUIET_HOURS, tz = DEFAULT_TZ): boolean {
  const [start, end] = parseWindow(window);
  const { minutes } = localParts(now, tz);
  if (start === end) return false;
  return start < end ? minutes >= start && minutes < end : minutes >= start || minutes < end;
}

/** The instant quiet hours end (next local `end` time) when `now` is inside them; otherwise null. */
export function quietHoursEnd(now: Date, window = DEFAULT_QUIET_HOURS, tz = DEFAULT_TZ): Date | null {
  if (!isQuietHours(now, window, tz)) return null;
  const [, end] = parseWindow(window);
  const p = localParts(now, tz);
  const dayShift = p.minutes >= end ? 1 : 0;
  const localAsUtc = Date.UTC(p.year, p.month - 1, p.day + dayShift, Math.floor(end / 60), end % 60);
  return new Date(localAsUtc - offsetMinutes(now, tz) * 60_000);
}

/** "Sun 12 Oct, 7:00 am" style local time for push bodies. */
export function formatCityTime(at: Date, lang: 'en' | 'gu', tz = DEFAULT_TZ): string {
  return new Intl.DateTimeFormat(lang === 'gu' ? 'gu-IN' : 'en-IN', {
    timeZone: tz,
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
  }).format(at);
}
