// /staff/me nav by role (AC-1 API side) and CORS for STAFF_WEB_ORIGINS (step 12).
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';
import { resetDb } from '../helpers/db';
import { createAdmin } from '../helpers/auth';
import { as, get } from './helpers';

describe('/staff/me', () => {
  it('returns role and nav keys per role; v1 admin is an admin_user', async () => {
    await resetDb();
    const admin = await as('admin');
    const mod = await as('moderator');
    const rep = await as('representative');
    expect((await get(admin.auth, '/staff/me')).body).toMatchObject({ role: 'admin', actorKind: 'user', nav: expect.arrayContaining(['users', 'exports', 'services']) });
    expect((await get(mod.auth, '/staff/me')).body.nav).toEqual(['dashboard', 'moderation', 'alerts']);
    expect((await get(rep.auth, '/staff/me')).body).toMatchObject({ role: 'representative', wardIds: [] });
    const v1 = await createAdmin();
    expect((await get(v1.auth, '/staff/me')).body).toMatchObject({ role: 'admin', actorKind: 'admin_user', displayName: 'Test Admin' });
    const citizen = await as('citizen');
    expect((await get(citizen.auth, '/staff/me')).status).toBe(403);
  });
});

describe('CORS for the staff web origin', () => {
  it('answers preflight for listed origins only, allowing Authorization', async () => {
    vi.resetModules();
    process.env.STAFF_WEB_ORIGINS = 'http://localhost:5050';
    try {
      const { createApp } = await import('../../src/app');
      const app = createApp();
      const ok = await request(app)
        .options('/api/v1/staff/me')
        .set('Origin', 'http://localhost:5050')
        .set('Access-Control-Request-Method', 'GET')
        .set('Access-Control-Request-Headers', 'authorization');
      expect(ok.status).toBe(204);
      expect(ok.headers['access-control-allow-origin']).toBe('http://localhost:5050');
      expect(ok.headers['access-control-allow-headers']).toContain('Authorization');
      // The app's client headers (api_client.dart) must pass preflight or every web call fails.
      for (const h of ['X-Install-Id', 'X-App-Version', 'X-Platform', 'X-Request-Id']) expect(ok.headers['access-control-allow-headers']).toContain(h);
      expect(ok.headers['access-control-allow-credentials']).toBeUndefined();
      const bad = await request(app).options('/api/v1/staff/me').set('Origin', 'https://evil.example');
      expect(bad.headers['access-control-allow-origin']).toBeUndefined();
    } finally {
      delete process.env.STAFF_WEB_ORIGINS;
      vi.resetModules();
    }
  });
});
