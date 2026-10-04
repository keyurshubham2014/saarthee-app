// T-10-01 (AC-2): every registered /staff/* route × visitor, citizen, representative, moderator, admin,
// suspended moderator (+ v1 admin JWT on TASK-10 routes) matches STAFF_MATRIX; unknown routes fail.
// T-10-03 (AC-3): assertWardScope on a test-only route.
import { randomUUID } from 'node:crypto';
import express from 'express';
import request from 'supertest';
import { beforeAll, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { errorHandler } from '../../src/middleware/errorHandler';
import { requireStaff } from '../../src/middleware/requireStaff';
import { listRoutes } from '../../src/middleware/routeList';
import { STAFF_MATRIX } from '../../src/middleware/staffMatrix';
import { assertWardScope } from '../../src/middleware/wardScope';
import { apiRouter } from '../../src/routes';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { as, identities, PREFIX, wards } from './helpers';

const TASK10 = /^(GET|POST|PUT|PATCH|DELETE) \/staff\/(me|summary|moderation|issues|comments|flags|users|categories|settings(\/:key)?$|export)/;

function concrete(route: string): [string, string] {
  const [method, path] = route.split(' ') as [string, string];
  return [method.toLowerCase(), path.replace(/:id/g, randomUUID()).replace(':key', 'relay_enabled')];
}

describe('authorisation matrix (T-10-01)', () => {
  let ids: Awaited<ReturnType<typeof identities>>;
  beforeAll(async () => {
    await resetDb();
    ids = await identities();
  });

  const routes = listRoutes(apiRouter).filter((r) => r.split(' ')[1]!.startsWith('/staff'));

  it('lists every registered /staff route in STAFF_MATRIX (and nothing stale)', () => {
    const missing = routes.filter((r) => !(r in STAFF_MATRIX));
    expect(missing).toEqual([]);
    const stale = Object.keys(STAFF_MATRIX).filter((r) => !routes.includes(r));
    expect(stale).toEqual([]);
    expect(routes.length).toBeGreaterThan(40);
  });

  it('answers every route per the matrix for each identity', async () => {
    const failures: string[] = [];
    for (const route of routes) {
      const allowed = STAFF_MATRIX[route] ?? [];
      const [method, path] = concrete(route);
      const call = (auth?: Record<string, string>) => {
        const r = (api() as unknown as Record<string, (p: string) => request.Test>)[method]!(`${PREFIX}${path}`);
        return (auth ? r.set(auth) : r).send({});
      };
      const check = (who: string, status: number, ok: boolean) => {
        const pass = ok ? status !== 401 && status !== 403 : status === 403;
        if (!pass) failures.push(`${route} ${who} → ${status}`);
      };
      const visitor = await call();
      if (visitor.status !== 401) failures.push(`${route} visitor → ${visitor.status}`);
      check('citizen', (await call(ids.citizen.auth)).status, false);
      check('representative', (await call(ids.representative.auth)).status, allowed.includes('representative'));
      check('moderator', (await call(ids.moderator.auth)).status, allowed.includes('moderator'));
      check('admin', (await call(ids.admin.auth)).status, allowed.includes('admin'));
      check('suspended', (await call(ids.suspended.auth)).status, false);
      if (TASK10.test(route)) check('v1-admin', (await call(ids.v1.auth)).status, allowed.includes('admin'));
    }
    expect(failures).toEqual([]);
  }, 120_000);
});

describe('assertWardScope (T-10-03)', () => {
  const app = express();
  app.get('/ward/:wardId', requireStaff('admin', 'moderator', 'representative'), (req, res) => {
    assertWardScope(req.staff, req.params.wardId as string);
    res.json({ ok: true });
  });
  app.use(errorHandler);

  it('lets a representative into their own ward only; moderators everywhere', async () => {
    await resetDb();
    const w = await wards();
    const rep = await as('representative');
    const record = await prisma.representative.create({
      data: {
        nameEn: 'Rep', nameGu: 'પ્રતિનિધિ', role: 'corporator', termStart: new Date('2023-01-01'), sourceUrl: 'https://ahmedabadcity.gov.in',
        lastVerifiedAt: new Date('2026-01-01'), userId: rep.user.id, verifiedAt: new Date(),
      },
    });
    await prisma.representativeArea.create({ data: { representativeId: record.id, wardId: w.byNumber(1).id } });
    const own = await request(app).get(`/ward/${w.byNumber(1).id}`).set(rep.auth);
    expect(own.status).toBe(200);
    const other = await request(app).get(`/ward/${w.byNumber(2).id}`).set(rep.auth);
    expect(other.status).toBe(403);
    expect(other.body.error.code).toBe('WARD_OUT_OF_SCOPE');
    const mod = await as('moderator');
    expect((await request(app).get(`/ward/${w.byNumber(2).id}`).set(mod.auth)).status).toBe(200);
  });
});
