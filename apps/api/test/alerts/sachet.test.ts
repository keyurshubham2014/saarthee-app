// T-08-15 (AC-13): SACHET adapter on fixtures — filter, mapping, polygon → wards, de-dup, never publishes.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { logger } from '../../src/lib/logger';
import { capToDraft } from '../../src/modules/alerts/sources/sachet';
import { mapSeverity, mapType, parseCap, parseRss, polygonToWkt } from '../../src/modules/alerts/sources/cap';
import { ingestSource } from '../../src/modules/alerts/sources/ingest';
import { sachetSource } from '../../src/modules/alerts/sources/sachet';
import type { FetchText } from '../../src/modules/alerts/sources/http';
import { useMemoryPush } from '../auth/helpers';
import { resetDb } from '../helpers/db';
import { ist, wardsFixture } from './helpers';

const DIR = path.resolve(__dirname, '../fixtures/sachet');
const read = (f: string) => readFileSync(path.join(DIR, f), 'utf8');
const FEED = 'https://sachet.ndma.gov.in/cap_public_website/rss/rss_gujarat.xml';
const AT = ist('2026-10-01T20:00:00');

const fixtureFetch: FetchText = async (url) => {
  if (url === FEED) return { status: 'ok', body: read('rss_gujarat.xml') };
  const id = new URL(url).searchParams.get('identifier');
  return { status: 'ok', body: read(`cap-${id}.xml`) };
};

const push = useMemoryPush();
let fx: Awaited<ReturnType<typeof wardsFixture>>;
beforeEach(async () => {
  await resetDb();
  push.sent.length = 0;
  fx = await wardsFixture();
});

describe('CAP parsing and mapping', () => {
  it('parses the real feed structure and a real CAP file', () => {
    expect(parseRss(read('rss_gujarat.xml')).map((i) => i.guid)).toEqual(['9990000000000001', '1790861421726020', '9990000000000002']);
    const cap = parseCap(read('cap-1790861421726020.xml'));
    expect(cap).toMatchObject({ identifier: 'IN-1790861421726020_20', msgType: 'Update' });
    expect(cap.infos[0]!.areas[0]!.areaDesc).toContain('Amreli');
  });

  it('maps severity, type, both languages, source and validity', () => {
    const d = capToDraft(parseCap(read('cap-9990000000000001.xml')), 'https://sachet.ndma.gov.in/x?identifier=1')!;
    expect(d).toMatchObject({ severity: 'warning', type: 'heat', sourceName: 'NDMA SACHET (IMD Ahmedabad)', areaMatched: true });
    expect(d.titleGu).toContain('અમદાવાદ');
    expect(d.validFrom.toISOString()).toBe(ist('2026-10-02T11:00:00').toISOString());
    expect(d.polygons[0]).toMatch(/^POLYGON\(\(72\.501 23\.001/);
    expect([mapSeverity('Extreme'), mapSeverity('Minor'), mapSeverity('Unknown')]).toEqual(['critical', 'info', 'info']);
    expect([mapType('Thunderstorm'), mapType('Cyclone'), mapType('Cold Wave')]).toEqual(['rain_flood', 'rain_flood', 'other']);
    expect(polygonToWkt('1,2 3')).toBeNull();
  });
});

describe('ingest (drafts only)', () => {
  it('creates one Ahmedabad draft with polygon wards; skips non-Ahmedabad and already stored; second run creates nothing', async () => {
    // The thunderstorm identifier is already stored (ingested earlier).
    await prisma.alert.create({
      data: {
        type: 'rain_flood', severity: 'advisory', sourceName: 'NDMA SACHET (Gujarat-SDMA)', sourceUrl: 'https://sachet.ndma.gov.in',
        validFrom: ist('2026-10-01T17:00:00'), validTo: ist('2026-10-01T23:00:00'), targetScope: 'city',
        origin: 'sachet', originRef: 'IN-9990000000000002_20',
      },
    });
    const src = sachetSource(fixtureFetch, FEED);
    const first = await ingestSource(src, { dryRun: false, logger, at: AT });
    expect(first).toMatchObject({ created: 1, skipped: 2, failed: 0 });
    const drafts = await prisma.alert.findMany({ where: { origin: 'sachet', originRef: 'IN-9990000000000001_20' }, include: { wards: { include: { ward: true } } } });
    expect(drafts).toHaveLength(1);
    const d = drafts[0]!;
    expect(d).toMatchObject({ status: 'draft', severity: 'warning', type: 'heat', targetScope: 'wards', approvedBy: [], publishedAt: null, createdBy: null });
    expect(d.sourceUrl).toContain('identifier=9990000000000001');
    expect(d.wards.map((w) => w.ward.number).sort()).toEqual([1, 2]);
    const [{ has_area }] = await prisma.$queryRaw<{ has_area: boolean }[]>`SELECT area IS NOT NULL AS has_area FROM alerts WHERE id = ${d.id}::uuid`;
    expect(has_area).toBe(true);
    const second = await ingestSource(src, { dryRun: false, logger, at: AT });
    expect(second.created).toBe(0);
    expect(await prisma.alert.count({ where: { origin: 'sachet' } })).toBe(2);
    expect(await prisma.alert.count({ where: { status: { not: 'draft' } } })).toBe(0);
    expect(push.sent).toHaveLength(0);
    expect(await prisma.notification.count()).toBe(0);
    void fx;
  });

  it('dry run writes nothing; expired items are skipped; a failing CAP fetch is counted, not thrown', async () => {
    const dry = await ingestSource(sachetSource(fixtureFetch, FEED), { dryRun: true, logger, at: AT });
    expect(dry.drafts.map((x) => x.originRef)).toContain('IN-9990000000000001_20');
    expect(await prisma.alert.count()).toBe(0);
    const later = await ingestSource(sachetSource(fixtureFetch, FEED), { dryRun: false, logger, at: ist('2026-10-05T00:00:00') });
    expect(later.created).toBe(0);
    const flaky: FetchText = async (url) => (url === FEED ? fixtureFetch(url) : Promise.reject(new Error('timeout')));
    expect((await ingestSource(sachetSource(flaky, FEED), { dryRun: false, logger, at: AT })).failed).toBe(3);
  });
});
