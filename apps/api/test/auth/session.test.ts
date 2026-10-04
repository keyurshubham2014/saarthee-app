// T-04-05, T-04-06 (AC-5): citizen session JWT, logout/token version, admin/user token separation, requireRole.
import express from 'express';
import jwt from 'jsonwebtoken';
import request from 'supertest';
import { beforeEach, describe, expect, it } from 'vitest';
import { config } from '../../src/config';
import { prisma } from '../../src/lib/db';
import { errorHandler } from '../../src/middleware/errorHandler';
import { requestId } from '../../src/middleware/requestId';
import { optionalUser, requireRole, requireUser } from '../../src/middleware/requireUser';
import { api } from '../helpers/app';
import { createAdmin } from '../helpers/auth';
import { resetDb } from '../helpers/db';
import { signIn, useFakeFirebase } from './helpers';

const gw = useFakeFirebase();
beforeEach(resetDb);

describe('citizen session', () => {
  it('T-04-05: logout → 204, token_version + 1, old token 401 TOKEN_REVOKED, install unlinked', async () => {
    const a = await signIn(gw);
    const installId = '0b1f4a8e-5d2c-4f3a-9e7b-1c2d3e4f5a6b';
    await prisma.device.create({ data: { installId, userId: a.user.id, platform: 'android', appVersion: '2.0.0' } });
    expect((await api().get('/api/v1/me').set(a.auth)).status).toBe(200);
    expect((await api().post('/api/v1/auth/logout').set(a.auth).send({ installId })).status).toBe(204);
    expect((await prisma.user.findUniqueOrThrow({ where: { id: a.user.id } })).tokenVersion).toBe(1);
    expect((await prisma.device.findUniqueOrThrow({ where: { installId } })).userId).toBeNull();
    const res = await api().get('/api/v1/me').set(a.auth);
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('TOKEN_REVOKED');
  });

  it('T-04-05: expired token → 401 TOKEN_EXPIRED; missing → AUTH_REQUIRED; garbage → TOKEN_REVOKED', async () => {
    const a = await signIn(gw);
    const expired = jwt.sign({ tv: 0, role: 'citizen', typ: 'user', exp: Math.floor(Date.now() / 1000) - 60 }, config.JWT_SECRET, {
      algorithm: 'HS256',
      subject: a.user.id,
      issuer: config.JWT_ISSUER,
      audience: config.USER_JWT_AUDIENCE,
    });
    const r1 = await api().get('/api/v1/me').set('Authorization', `Bearer ${expired}`);
    expect(r1.status).toBe(401);
    expect(r1.body.error.code).toBe('TOKEN_EXPIRED');
    const r2 = await api().get('/api/v1/me');
    expect(r2.status).toBe(401);
    expect(r2.body.error.code).toBe('AUTH_REQUIRED');
    const r3 = await api().get('/api/v1/me').set('Authorization', 'Bearer abc.def.ghi');
    expect(r3.body.error.code).toBe('TOKEN_REVOKED');
  });

  it('suspended after sign-in → 403 ACCOUNT_SUSPENDED', async () => {
    const a = await signIn(gw);
    await prisma.user.update({ where: { id: a.user.id }, data: { status: 'suspended' } });
    const res = await api().get('/api/v1/me').set(a.auth);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ACCOUNT_SUSPENDED');
  });

  it('T-04-06: admin token on /me and user token on /admin/complaints are rejected with 401', async () => {
    const { auth: adminAuth } = await createAdmin();
    const a = await signIn(gw);
    expect((await api().get('/api/v1/me').set(adminAuth)).status).toBe(401);
    expect((await api().get('/api/v1/admin/complaints').set(a.auth)).status).toBe(401);
    expect((await api().get('/api/v1/admin/complaints').set(adminAuth)).status).toBe(200);
    // A user token re-signed with the admin audience is still refused (typ check).
    const forged = jwt.sign({ tv: 0, typ: 'user' }, config.JWT_SECRET, {
      algorithm: 'HS256',
      subject: a.user.id,
      issuer: config.JWT_ISSUER,
      audience: config.JWT_AUDIENCE,
      expiresIn: '1h',
    });
    expect((await api().get('/api/v1/admin/complaints').set('Authorization', `Bearer ${forged}`)).status).toBe(401);
  });

  it('T-04-06: requireRole → 403 FORBIDDEN for other roles; optionalUser ignores a missing token', async () => {
    const app = express();
    app.use(requestId);
    app.get('/staff', requireUser, requireRole('moderator', 'admin'), (_req, res) => res.json({ ok: true }));
    app.get('/maybe', optionalUser, (req, res) => res.json({ user: req.user?.id ?? null }));
    app.use(errorHandler);
    const citizen = await signIn(gw);
    const res = await request(app).get('/staff').set(citizen.auth);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
    await prisma.user.update({ where: { id: citizen.user.id }, data: { role: 'moderator' } });
    expect((await request(app).get('/staff').set(citizen.auth)).status).toBe(200);
    expect((await request(app).get('/maybe')).body.user).toBeNull();
    expect((await request(app).get('/maybe').set(citizen.auth)).body.user).toBe(citizen.user.id);
    expect((await request(app).get('/maybe').set('Authorization', 'Bearer x.y.z')).status).toBe(401);
  });
});
