import { config } from '../../config';

/** India Standard Time: fixed +05:30, no daylight saving (APP_TIMEZONE is restricted to Asia/Kolkata). */
const IST_OFFSET_MIN = 330;
const DAY_MIN = 24 * 60;

function parseWindow(text: string): { start: number; end: number } {
  const [a, b] = text.split('-') as [string, string];
  const toMin = (hhmm: string) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));
  return { start: toMin(a), end: toMin(b) };
}

/** Minutes since local (IST) midnight. */
function localMinutes(d: Date): number {
  return Math.floor((((d.getTime() / 60_000 + IST_OFFSET_MIN) % DAY_MIN) + DAY_MIN) % DAY_MIN);
}

/** True when `d` falls in the quiet window (default 22:00–07:00 IST; start inclusive, end exclusive). */
export function isQuietHours(d: Date, window: string = config.QUIET_HOURS): boolean {
  const { start, end } = parseWindow(window);
  const m = localMinutes(d);
  return start <= end ? m >= start && m < end : m >= start || m < end;
}

/** The next moment the quiet window ends (e.g. 07:00 IST) at or after `d`. */
export function nextQuietEnd(d: Date, window: string = config.QUIET_HOURS): Date {
  const { end } = parseWindow(window);
  const m = localMinutes(d);
  let delta = end - m;
  if (delta <= 0) delta += DAY_MIN;
  const startOfMinute = Math.floor(d.getTime() / 60_000) * 60_000;
  return new Date(startOfMinute + delta * 60_000);
}

/** When a push for an alert of `severity` published at `d` may go out: undefined = now. Critical is never held. */
export function holdUntil(d: Date, severity: string): Date | undefined {
  if (severity === 'critical' || !isQuietHours(d)) return undefined;
  return nextQuietEnd(d);
}
