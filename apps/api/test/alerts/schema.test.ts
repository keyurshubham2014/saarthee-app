// T-08-01 (AC-1, AC-3, AC-7): alerts CHECKs; quiet-hours helper unit tests (§6 step 4, part of T-08-08).
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { holdUntil, isQuietHours, nextQuietEnd } from '../../src/modules/alerts/quietHours';
import { resetDb, sqlError } from '../helpers/db';

const ist = (local: string) => new Date(`${local}+05:30`);

describe('quiet hours (Asia/Kolkata)', () => {
  it('22:00 inclusive to 07:00 exclusive', () => {
    expect(isQuietHours(ist('2030-01-10T21:59:00'))).toBe(false);
    expect(isQuietHours(ist('2030-01-10T22:00:00'))).toBe(true);
    expect(isQuietHours(ist('2030-01-11T06:59:00'))).toBe(true);
    expect(isQuietHours(ist('2030-01-11T07:00:00'))).toBe(false);
  });

  it('next 07:00 IST and Critical exemption', () => {
    expect(nextQuietEnd(ist('2030-01-10T23:30:00'))).toEqual(ist('2030-01-11T07:00:00'));
    expect(nextQuietEnd(ist('2030-01-11T06:59:30'))).toEqual(ist('2030-01-11T07:00:00'));
    expect(holdUntil(ist('2030-01-10T23:30:00'), 'advisory')).toEqual(ist('2030-01-11T07:00:00'));
    expect(holdUntil(ist('2030-01-10T23:30:00'), 'critical')).toBeUndefined();
    expect(holdUntil(ist('2030-01-10T11:00:00'), 'info')).toBeUndefined();
  });
});

describe('alerts table CHECKs (T-08-01)', () => {
  beforeEach(resetDb);

  const insert = (cols: Record<string, string>) => {
    const base: Record<string, string> = {
      type: `'heat'`,
      severity: `'info'`,
      source_name: `'IMD Ahmedabad'`,
      source_url: `'https://mausam.imd.gov.in'`,
      valid_from: `now()`,
      valid_to: `now() + interval '1 hour'`,
      target_scope: `'city'`,
      ...cols,
    };
    return `INSERT INTO alerts (${Object.keys(base).join(', ')}) VALUES (${Object.values(base).join(', ')})`;
  };

  it('accepts a minimal draft', async () => {
    await prisma.$executeRawUnsafe(insert({}));
    expect(await prisma.alert.count()).toBe(1);
  });

  it('rejects valid_to <= valid_from, http source and zone scope without zone', async () => {
    expect(await sqlError(insert({ valid_to: 'now()' }))).toContain('ck_alerts_validity');
    expect(await sqlError(insert({ source_url: `'http://x.in'` }))).toContain('ck_alerts_source_url');
    expect(await sqlError(insert({ source_name: `' '` }))).toContain('ck_alerts_source_name');
    expect(await sqlError(insert({ target_scope: `'zone'` }))).toContain('ck_alerts_zone_target');
  });

  it('rejects a published Warning with one approver (two-person rule) and accepts two', async () => {
    const published = {
      severity: `'warning'`,
      status: `'published'`,
      published_at: 'now()',
      title_en: `'Heat warning'`,
      title_gu: `'ગરમીની ચેતવણી'`,
      body_en: `'Stay indoors from noon to 4 pm.'`,
      body_gu: `'બપોરે 12 થી 4 ઘરમાં રહો.'`,
    };
    const one = `ARRAY[gen_random_uuid()]::uuid[]`;
    const two = `ARRAY[gen_random_uuid(), gen_random_uuid()]::uuid[]`;
    expect(await sqlError(insert({ ...published, approved_by: one }))).toContain('ck_alerts_two_person');
    await prisma.$executeRawUnsafe(insert({ ...published, approved_by: two }));
    expect(await sqlError(insert({ ...published, approved_by: two, title_gu: `''` }))).toContain('ck_alerts_titles');
  });
});
