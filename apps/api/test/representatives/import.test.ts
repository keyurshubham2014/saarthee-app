// T-09-08: roster importer — dry-run errors, atomic abort, idempotent re-run, 4-seat cap, mobile refused (AC-7).
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { checkOfficePhone } from '../../src/modules/representatives/phone';
import { importConstituencies } from '../../src/modules/staff-representatives/constituencies.import';
import { importRoster } from '../../src/modules/staff-representatives/roster.import';
import { ROSTER_HEADER } from '../../src/modules/staff-representatives/roster.validate';
import { resetDb } from '../helpers/db';
import { fixtureWards, SRC } from './helpers';

const HEAD = ROSTER_HEADER.join(',');
const row = (name: string, role: string, ward: string, ac: string, phone = '', source = SRC, email = '') =>
  [name, `ટેસ્ટ ${name}`, role, 'Test Party', '2026-03-01', '2031-02-28', ward, ac, phone, email, source, '2026-09-12'].join(',');

const VALID = [
  ...['A1', 'A2', 'A3', 'A4'].map((n, i) => row(`Ward One ${n}`, 'corporator', '1', '', i === 0 ? '079 2658 1234' : '')),
  ...['B1', 'B2', 'B3', 'B4'].map((n) => row(`Ward Two ${n}`, 'corporator', '2', '', '', SRC, `${n.toLowerCase()}@example.org`)),
  row('Mla Fortyfour', 'mla', '', '44'),
  row('Mp Seat', 'mp', '', '"44;45"'),
];
const FIFTH = row('Ward One A5', 'corporator', '1', '');
const NO_SOURCE = row('No Source', 'corporator', '3', '', '', '');
const MOBILE = row('Has Mobile', 'corporator', '3', '', '98250 12345');

beforeEach(async () => {
  await resetDb();
  await fixtureWards();
  const consts = [
    'ac_number,ac_name_en,ac_name_gu,pc_name_en,pc_name_gu,ward_numbers,source_url',
    `44,Test Ellis,ટેસ્ટ એલિસ,Test Seat,ટેસ્ટ બેઠક,"1;2",${SRC}`,
    `45,Test Naran,ટેસ્ટ નારણ,Test Seat,ટેસ્ટ બેઠક,3,${SRC}`,
  ].join('\n');
  expect((await importConstituencies(consts, { dryRun: false })).committed).toBe(true);
});

describe('reps:import (T-09-08)', () => {
  it('dry run lists the 3 errors with row numbers and writes nothing; commit aborts atomically', async () => {
    const csv = [HEAD, ...VALID, FIFTH, NO_SOURCE, MOBILE].join('\n');
    const dry = await importRoster(csv, { dryRun: true });
    expect(dry.committed).toBe(false);
    expect(dry.counts).toEqual({ create: 10, update: 0, unchanged: 0, error: 3 });
    const errs = dry.rows.filter((r) => r.action === 'error');
    expect(errs.map((e) => e.row)).toEqual([12, 13, 14]);
    expect(errs[0]!.errors![0]).toContain('ward 1 already has 4 active corporators');
    expect(errs[1]!.errors).toContain('source_url: every row needs a source link.');
    expect(errs[2]!.errors).toContain('office_phone: Mobile numbers are never imported. Use an official office landline or leave it empty.');
    expect(await prisma.representative.count()).toBe(0);

    const commit = await importRoster(csv, { dryRun: false });
    expect(commit.committed).toBe(false);
    expect(await prisma.representative.count()).toBe(0);
  });

  it('after fixing: commit creates 10 with areas, re-run is all unchanged, an edit is an update', async () => {
    const csv = [HEAD, ...VALID].join('\n');
    const first = await importRoster(csv, { dryRun: false });
    expect(first).toMatchObject({ committed: true, counts: { create: 10, error: 0 } });
    expect(await prisma.representative.count()).toBe(10);
    const mp = await prisma.representative.findFirstOrThrow({ where: { role: 'mp' }, include: { areas: true } });
    expect(mp.areas).toHaveLength(2);
    const a1 = await prisma.representative.findFirstOrThrow({ where: { nameEn: 'Ward One A1' } });
    expect(a1.publicPhone).toBe('+917926581234');

    const again = await importRoster(csv, { dryRun: false });
    expect(again.counts).toEqual({ create: 0, update: 0, unchanged: 10, error: 0 });
    const edited = csv.replace('Ward Two B1,ટેસ્ટ Ward Two B1,corporator,Test Party', 'Ward Two B1,ટેસ્ટ Ward Two B1,corporator,Independent');
    const third = await importRoster(edited, { dryRun: false });
    expect(third.counts).toMatchObject({ update: 1, unchanged: 9 });
    expect(await prisma.representative.count()).toBe(10);
  });

  it('rejects unknown or missing columns', async () => {
    const bad = await importRoster(`${HEAD},photo\n`, { dryRun: true });
    expect(bad.headerError).toContain('unknown columns: photo');
    const missing = await importRoster('name_en,name_gu\n', { dryRun: true });
    expect(missing.headerError).toContain('missing columns');
  });

  it('validates role-specific area rules and future dates', async () => {
    const csv = [
      HEAD,
      row('No Ward', 'corporator', '', ''),
      row('Mla Two Acs', 'mla', '', '"44;45"'),
      row('Unknown Ac', 'mla', '', '99'),
      [`Future`, 'ટેસ્ટ', 'corporator', '', '2026-03-01', '', '3', '', '', '', SRC, '2099-01-01'].join(','),
    ].join('\n');
    const r = await importRoster(csv, { dryRun: true });
    expect(r.counts.error).toBe(4);
    expect(r.rows[0]!.errors![0]).toContain('ward_number');
    expect(r.rows[1]!.errors![0]).toContain('exactly one');
    expect(r.rows[2]!.errors![0]).toContain('constituency 99');
    expect(r.rows[3]!.errors![0]).toContain('future');
  });
});

describe('office phone guard', () => {
  it.each([
    ['079 2658 1234', 'landline'],
    ['+91 79 2658 1234', 'landline'],
    ['07926581234', 'landline'],
    ['98250 12345', 'mobile'],
    ['+91 98250 12345', 'mobile'],
    ['7926581234', 'mobile'],
    ['', 'empty'],
    ['022 2658 1234', 'invalid'],
    ['call me', 'invalid'],
  ])('%s → %s', (input, kind) => {
    expect(checkOfficePhone(input).kind).toBe(kind);
  });
});
