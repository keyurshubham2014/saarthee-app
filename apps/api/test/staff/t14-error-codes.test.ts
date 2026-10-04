// TASK-14 error-code sweep: codes that neither the live sweep (scripts/api-sweep.mjs) nor another Vitest file produced
// by name — FLAG_QUOTA, INITIATIVE_STARTED, EXPORT_TOO_LARGE (both export routes). Asserts status and code.
import { describe, expect, it, vi } from 'vitest';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { useMemoryPush } from '../auth/helpers';
import { goingRsvp, inHours, makeInitiative } from '../services/helpers';
import { as, get, issueInWard, makeCategory, post, PREFIX, wards } from './helpers';

vi.mock('../../src/config', async (orig) => {
  const real = (await orig()) as { config: Record<string, unknown> };
  return { ...real, config: { ...real.config, EXPORT_MAX_ROWS: 1 } };
});

useMemoryPush();

describe('error codes without a named producer (T-14 sweep)', () => {
  it('FLAG_QUOTA: the 21st flag of the day → 429', async () => {
    await resetDb();
    await wards();
    const citizen = await as('citizen');
    const issues = [];
    const cat = await makeCategory();
    for (let n = 0; n < 21; n++) issues.push(await issueInWard(1, { categoryId: cat.id }));
    for (const i of issues.slice(0, 20)) expect((await post(citizen.auth, `/issues/${i.id}/flags`, { reason: 'spam' })).status).toBe(201);
    const over = await post(citizen.auth, `/issues/${issues[20]!.id}/flags`, { reason: 'spam' });
    expect(over.status).toBe(429);
    expect(over.body.error.code).toBe('FLAG_QUOTA');
  });

  it('INITIATIVE_STARTED: cancelling an RSVP after the drive started → 409', async () => {
    await resetDb();
    const citizen = await as('citizen');
    const started = await makeInitiative({ status: 'published', startsAt: inHours(-1), endsAt: inHours(2) });
    await goingRsvp(started.id, citizen.user.id);
    const res = await api().delete(`${PREFIX}/initiatives/${started.id}/rsvp`).set(citizen.auth);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('INITIATIVE_STARTED');
  });

  it('EXPORT_TOO_LARGE: staff export and ward dashboard export over EXPORT_MAX_ROWS → 413', async () => {
    await resetDb();
    const w = await wards();
    const admin = await as('admin');
    await issueInWard(1);
    await issueInWard(1);
    const today = new Date().toISOString().slice(0, 10);
    const staff = await get(admin.auth, `/staff/export?dataset=issues&from=${today}&to=${today}`);
    expect(staff.status).toBe(413);
    expect(staff.body.error.code).toBe('EXPORT_TOO_LARGE');
    const ward = await get(admin.auth, `/staff/ward-dashboard/export?ward=${w.byNumber(1).id}&from=${today}&to=${today}`);
    expect(ward.status).toBe(413);
    expect(ward.body.error.code).toBe('EXPORT_TOO_LARGE');
  });
});
