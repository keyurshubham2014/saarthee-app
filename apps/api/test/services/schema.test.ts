// T-12-01 (AC-1): services / initiatives / rsvps / service_tips constraints.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { dbError, resetDb } from '../helpers/db';
import { makeUser } from '../helpers/factories';
import { HOUR, inHours, makeInitiative, makeService } from './helpers';

beforeEach(resetDb);

describe('T-12-01 migration constraints', () => {
  it('rejects end before start, AMC without a source, duplicate slug, http URL and a bad RSVP status', async () => {
    const start = inHours(10);
    expect(await dbError(makeInitiative({ startsAt: start, endsAt: new Date(start.getTime() - HOUR) }))).toContain('ck_initiatives_time');
    expect(await dbError(makeInitiative({ organiser: 'AMC', sourceUrl: null }))).toContain('ck_initiatives_amc_source');
    await makeService({ slug: 'dup-slug' });
    expect(await dbError(makeService({ slug: 'dup-slug' }))).toMatch(/slug|uq_services_slug/);
    expect(await dbError(makeService({ url: 'http://insecure.test/' }))).toContain('ck_services_url');
    expect(await dbError(makeService({ category: 'parking' }))).toContain('ck_services_category');
    const i = await makeInitiative();
    const u = await makeUser();
    expect(await dbError(prisma.rsvp.create({ data: { initiativeId: i.id, userId: u.id, status: 'maybe' } }))).toContain('ck_rsvps_status');
    expect(await dbError(makeInitiative({ capacity: 0 }))).toContain('ck_initiatives_capacity');
    expect(
      await dbError(prisma.serviceTip.create({ data: { titleEn: 't', titleGu: 't', bodyEn: 'b', bodyGu: 'b', activeFrom: new Date('2027-05-01'), activeTo: new Date('2027-04-01') } })),
    ).toContain('ck_service_tips_window');
  });

  it('accepts valid rows and fills location from lat/lng', async () => {
    const i = await makeInitiative({ organiser: 'AMC', sourceUrl: 'https://ahmedabadcity.gov.in/', lat: 23.0105, lng: 72.5605 });
    const [row] = await prisma.$queryRaw<{ lat: number; lng: number }[]>`
      SELECT ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng FROM initiatives WHERE id = ${i.id}::uuid`;
    expect(Number(row!.lat)).toBeCloseTo(23.0105, 4);
    expect(Number(row!.lng)).toBeCloseTo(72.5605, 4);
    const u = await makeUser();
    await prisma.rsvp.create({ data: { initiativeId: i.id, userId: u.id, status: 'going' } });
    expect(await prisma.rsvp.count()).toBe(1);
    expect(await dbError(makeInitiative({ lat: 23, lng: null }))).toContain('ck_initiatives_latlng');
  });
});
