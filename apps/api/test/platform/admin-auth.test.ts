// T-01-08 (AC-10): v1 admin login and session revocation.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { ADMIN_PASSWORD, createAdmin } from '../helpers/auth';
import { resetDb } from '../helpers/db';

beforeEach(resetDb);

describe('admin auth', () => {
  it('logs in with the right password and the token works', async () => {
    const { admin } = await createAdmin({ email: 'ok@test.local' });
    const res = await api().post('/api/v1/admin/auth/login').send({ email: 'OK@test.local', password: ADMIN_PASSWORD });
    expect(res.status).toBe(200);
    expect(res.body.admin).toMatchObject({ id: admin.id, email: 'ok@test.local' });
    const me = await api().get('/api/v1/admin/me').set('Authorization', `Bearer ${res.body.accessToken}`);
    expect(me.status).toBe(200);
  });

  it('rejects a wrong password with 401 INVALID_CREDENTIALS', async () => {
    await createAdmin({ email: 'ok@test.local' });
    const res = await api().post('/api/v1/admin/auth/login').send({ email: 'ok@test.local', password: 'wrong' });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('rejects a disabled admin with 403 ADMIN_DISABLED', async () => {
    await createAdmin({ email: 'off@test.local', isActive: false });
    const res = await api().post('/api/v1/admin/auth/login').send({ email: 'off@test.local', password: ADMIN_PASSWORD });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ADMIN_DISABLED');
  });

  it('revokes tokens when token_version is bumped (401 TOKEN_REVOKED)', async () => {
    const { admin, auth } = await createAdmin();
    expect((await api().get('/api/v1/admin/me').set(auth)).status).toBe(200);
    await prisma.adminUser.update({ where: { id: admin.id }, data: { tokenVersion: { increment: 1 } } });
    const res = await api().get('/api/v1/admin/me').set(auth);
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('TOKEN_REVOKED');
  });

  it('rejects /admin/* without a token (401)', async () => {
    const res = await api().get('/api/v1/admin/me');
    expect(res.status).toBe(401);
  });
});
