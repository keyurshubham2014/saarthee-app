import { prisma } from '../../src/lib/db';
import { hashPassword } from '../../src/lib/password';
import { signAdminToken } from '../../src/lib/tokens';

export const ADMIN_PASSWORD = 'Test-Admin-Password-1!';

/** Creates a v1 admin (argon2 hash of ADMIN_PASSWORD) and returns it with a valid bearer token. */
export async function createAdmin(opts: { email?: string; isActive?: boolean } = {}) {
  const admin = await prisma.adminUser.create({
    data: {
      email: opts.email ?? `admin-${Math.random().toString(36).slice(2, 10)}@test.local`,
      passwordHash: await hashPassword(ADMIN_PASSWORD),
      displayName: 'Test Admin',
      isActive: opts.isActive ?? true,
    },
  });
  const { accessToken } = signAdminToken(admin);
  return { admin, token: accessToken, auth: { Authorization: `Bearer ${accessToken}` } };
}
