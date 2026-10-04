// Shared job runner (TASK-06 §5 contract; TASK-06 T-06-16 advisory lock): registry, cron, no overlap, scheduler.
import { Client } from 'pg';
import { afterEach, describe, expect, it } from 'vitest';
import { appJobs, clearJobs, listJobs, registerAppJobs, registerJob, runJob, startScheduler } from '../../src/jobs';
import { cronMatches, parseCron } from '../../src/jobs/cron';

afterEach(() => clearJobs());

const deferred = () => {
  let release!: () => void;
  const promise = new Promise<void>((r) => (release = r));
  return { promise, release };
};

describe('registry', () => {
  it('rejects bad names, duplicates and missing or double schedules', () => {
    const run = async () => undefined;
    expect(() => registerJob({ name: 'Bad Name', everyMs: 1000, run })).toThrow(/kebab-case/);
    expect(() => registerJob({ name: 'no-schedule', run })).toThrow(/exactly one/);
    expect(() => registerJob({ name: 'both', everyMs: 1000, cron: '* * * * *', run })).toThrow(/exactly one/);
    expect(() => registerJob({ name: 'too-fast', everyMs: 10, run })).toThrow(/>= 1000/);
    expect(() => registerJob({ name: 'bad-cron', cron: '* *', run })).toThrow(/5 fields/);
    registerJob({ name: 'ok-job', everyMs: 1000, run });
    expect(() => registerJob({ name: 'ok-job', everyMs: 1000, run })).toThrow(/twice/);
  });

  it('registerAppJobs registers the app list once', () => {
    registerAppJobs();
    registerAppJobs();
    expect(listJobs().map((j) => j.name)).toEqual(appJobs().map((j) => j.name));
    expect(listJobs().map((j) => j.name)).toContain('push-flush');
  });
});

describe('cron', () => {
  it('matches steps, ranges, lists and Sunday as 0 or 7', () => {
    const at = (s: string) => new Date(s);
    expect(cronMatches(parseCron('*/15 * * * *'), at('2026-10-04T10:30:00'))).toBe(true);
    expect(cronMatches(parseCron('*/15 * * * *'), at('2026-10-04T10:31:00'))).toBe(false);
    expect(cronMatches(parseCron('0 9-17 * * 1-5'), at('2026-10-05T09:00:00'))).toBe(true); // Monday
    expect(cronMatches(parseCron('0 9-17 * * 1-5'), at('2026-10-04T09:00:00'))).toBe(false); // Sunday
    expect(cronMatches(parseCron('0 6 * * 7'), at('2026-10-04T06:00:00'))).toBe(true);
    expect(cronMatches(parseCron('5,10 0 1 * *'), at('2026-11-01T00:10:00'))).toBe(true);
    expect(() => parseCron('61 * * * *')).toThrow();
  });
});

describe('runJob', () => {
  it('runs a job and returns its counters', async () => {
    const now = new Date('2026-10-04T00:00:00Z');
    let seen: Date | undefined;
    registerJob({ name: 'counter', everyMs: 1000, run: async (ctx) => ((seen = ctx.now), { done: 3 }) });
    const out = await runJob('counter', now);
    expect(out).toMatchObject({ name: 'counter', status: 'ran', result: { done: 3 } });
    expect(seen).toEqual(now);
    await expect(runJob('missing')).rejects.toThrow(/unknown job/);
  });

  it('never overlaps itself in one process', async () => {
    const gate = deferred();
    let runs = 0;
    registerJob({ name: 'slow', everyMs: 1000, run: async () => (runs++, await gate.promise, {}) });
    const first = runJob('slow');
    const second = await runJob('slow');
    expect(second.status).toBe('skipped_running');
    gate.release();
    expect((await first).status).toBe('ran');
    expect(runs).toBe(1);
  });

  it('a second process holding the advisory lock makes the run exit without work', async () => {
    let runs = 0;
    registerJob({ name: 'locked', everyMs: 1000, run: async () => (runs++, {}) });
    const other = new Client({ connectionString: process.env.DATABASE_URL });
    await other.connect();
    try {
      await other.query(`SELECT pg_advisory_lock(hashtext('saarthee.job:locked'))`);
      expect((await runJob('locked')).status).toBe('skipped_locked');
      expect(runs).toBe(0);
      await other.query(`SELECT pg_advisory_unlock(hashtext('saarthee.job:locked'))`);
      expect((await runJob('locked')).status).toBe('ran');
      expect(runs).toBe(1);
    } finally {
      await other.end();
    }
  });

  it('a failing job reports failed and releases its lock', async () => {
    let fail = true;
    registerJob({
      name: 'flaky',
      everyMs: 1000,
      run: async () => {
        if (fail) throw Object.assign(new Error('boom'), { code: 'E_FLAKY' });
        return { ok: true };
      },
    });
    expect(await runJob('flaky')).toMatchObject({ status: 'failed', error: 'E_FLAKY' });
    fail = false;
    expect((await runJob('flaky')).status).toBe('ran');
  });
});

describe('scheduler', () => {
  it('runs everyMs jobs on their interval and stops cleanly', async () => {
    let runs = 0;
    registerJob({ name: 'tick', everyMs: 1000, run: async () => (runs++, {}) });
    const s = startScheduler();
    await new Promise((r) => setTimeout(r, 2300));
    s.stop();
    const after = runs;
    expect(after).toBeGreaterThanOrEqual(1);
    await new Promise((r) => setTimeout(r, 1200));
    expect(runs).toBe(after);
  });
});
