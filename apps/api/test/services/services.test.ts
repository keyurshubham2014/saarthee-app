// T-12-02, T-12-03, T-12-12, T-12-14: public services directory, detail with ward office, tips, seed.
import { beforeEach, describe, expect, it } from 'vitest';
import { SERVICES } from '../../prisma/seed-data/services';
import { prisma } from '../../src/lib/db';
import { seedServices } from '../../src/modules/services/seed';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { importFixtureWards } from '../geo/helpers';
import { makeService } from './helpers';

beforeEach(resetDb);

describe('T-12-02 GET /services', () => {
  it('filters by category, searches en/gu text, hides inactive and keeps sort order', async () => {
    await seedServices(prisma);
    const all = await api().get('/api/v1/services');
    expect(all.status).toBe(200);
    expect(all.body.items).toHaveLength(17);
    expect(all.body.items.some((s: { slug: string }) => s.slug === 'amc-schools')).toBe(false);

    const tax = await api().get('/api/v1/services').query({ category: 'tax', q: 'property' });
    expect(tax.body.items.map((s: { slug: string }) => s.slug)).toEqual(['property-tax-pay', 'property-tax-bill', 'property-name-transfer']);
    expect(tax.body.items[0]).toEqual({
      slug: 'property-tax-pay',
      category: 'tax',
      nameEn: 'Pay property tax',
      nameGu: 'મિલકત વેરો ભરો',
      summaryEn: expect.any(String),
      summaryGu: expect.any(String),
      online: true,
      visitWardOffice: false,
      linkOk: null,
    });

    const gu = await api().get('/api/v1/services').query({ q: 'મિલકત' });
    expect(gu.body.items.length).toBeGreaterThanOrEqual(3);
    expect(gu.body.items.every((s: { category: string }) => s.category === 'tax')).toBe(true);

    const upper = await api().get('/api/v1/services').query({ q: 'PROPERTY TAX' });
    expect(upper.body.items.length).toBeGreaterThanOrEqual(2);
    expect((await api().get('/api/v1/services').query({ q: 'zzz-nothing' })).body.items).toEqual([]);
  });

  it('rejects an unknown category and a long query', async () => {
    expect((await api().get('/api/v1/services').query({ category: 'parking' })).status).toBe(400);
    expect((await api().get('/api/v1/services').query({ q: 'x'.repeat(51) })).status).toBe(400);
  });
});

describe('T-12-03 GET /services/{slug}', () => {
  it('returns detail with the ward office when ?ward is given, without it otherwise; 404 unknown/inactive', async () => {
    await seedServices(prisma);
    await importFixtureWards();
    const ward = await prisma.ward.findFirstOrThrow({ where: { number: 1 } });
    const res = await api().get('/api/v1/services/rti').query({ ward: ward.id });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      slug: 'rti',
      visitWardOffice: true,
      department: 'RTI Cell',
      url: 'https://ahmedabadcity.gov.in/StaticPage/RTI',
      source: { name: 'Amdavad Municipal Corporation website', url: 'https://ahmedabadcity.gov.in/StaticPage/RTI' },
      wardOffice: { wardId: ward.id, number: 1, officeAddress: 'Alpha Ward Office, Test Road' },
    });
    expect(res.body.howToEn.split('\n')[0]).toMatch(/^1\. /);
    expect(res.body.verifiedAt).toBe('2026-10-02T18:30:00.000Z');

    expect((await api().get('/api/v1/services/rti')).body.wardOffice).toBeNull();
    expect((await api().get('/api/v1/services/no-such-service')).status).toBe(404);
    expect((await api().get('/api/v1/services/amc-schools')).status).toBe(404);
  });
});

describe('T-12-12 GET /services/tips', () => {
  it('returns at most 3 tips active on the date, ward-specific first', async () => {
    await importFixtureWards();
    const w12 = await prisma.ward.findFirstOrThrow({ where: { number: 1 } });
    const other = await prisma.ward.findFirstOrThrow({ where: { number: 2 } });
    const svc = await makeService({ slug: 'property-tax-pay' });
    const tip = (titleEn: string, from: string, to: string, extra: Record<string, unknown> = {}) =>
      prisma.serviceTip.create({
        data: { titleEn, titleGu: titleEn, bodyEn: 'b', bodyGu: 'b', activeFrom: new Date(from), activeTo: new Date(to), ...extra },
      });
    await tip('city-1', '2027-04-01', '2027-05-31', { serviceId: svc.id });
    await tip('city-2', '2027-04-10', '2027-04-30');
    await tip('city-3', '2027-03-01', '2027-06-30');
    await tip('ward-12', '2027-04-01', '2027-04-30', { wardId: w12.id });
    await tip('other-ward', '2027-04-01', '2027-04-30', { wardId: other.id });
    await tip('inactive', '2027-04-01', '2027-04-30', { isActive: false });

    const april = await api().get('/api/v1/services/tips').query({ ward: w12.id, date: '2027-04-15' });
    expect(april.status).toBe(200);
    expect(april.body.items).toHaveLength(3);
    expect(april.body.items[0].titleEn).toBe('ward-12');
    const titles = april.body.items.map((t: { titleEn: string }) => t.titleEn);
    expect(titles).not.toContain('other-ward');
    expect(titles).not.toContain('inactive');
    const all = await api().get('/api/v1/services/tips').query({ date: '2027-04-15' });
    expect(all.body.items.find((t: { titleEn: string }) => t.titleEn === 'city-1')?.serviceSlug).toBe('property-tax-pay');

    const nov = await api().get('/api/v1/services/tips').query({ ward: w12.id, date: '2027-11-15' });
    expect(nov.body.items).toEqual([]);
    expect((await api().get('/api/v1/services/tips').query({ date: '15-04-2027' })).status).toBe(400);
  });
});

describe('T-12-14 services:seed', () => {
  it('is idempotent and keeps staff edits unless --force', async () => {
    expect(await seedServices(prisma)).toEqual({ inserted: SERVICES.length, updated: 0, unchanged: 0 });
    expect(SERVICES).toHaveLength(18);
    await prisma.service.update({ where: { slug: 'rti' }, data: { summaryEn: 'Edited by staff' } });
    expect(await seedServices(prisma)).toEqual({ inserted: 0, updated: 0, unchanged: 18 });
    expect((await prisma.service.findUniqueOrThrow({ where: { slug: 'rti' } })).summaryEn).toBe('Edited by staff');
    expect(await seedServices(prisma, { force: true })).toEqual({ inserted: 0, updated: 18, unchanged: 0 });
    expect((await prisma.service.findUniqueOrThrow({ where: { slug: 'rti' } })).summaryEn).not.toBe('Edited by staff');
    for (const s of SERVICES) {
      expect(s.url).toMatch(/^https:\/\//);
      expect(s.howToEn.split('\n').every((l, i) => l.startsWith(`${i + 1}. `))).toBe(true);
      expect(s.howToGu.split('\n').length).toBe(s.howToEn.split('\n').length);
    }
  });
});
