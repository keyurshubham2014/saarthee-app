import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { verifyAgainstDummy, verifyPassword } from '../../lib/password';
import { emailHash, signAdminToken } from '../../lib/tokens';

export interface LoginResult {
  accessToken: string;
  expiresAt: string;
  admin: { id: string; email: string; displayName: string };
}

/** Login (03 §3.1): generic error for unknown email and wrong password; disabled → ADMIN_DISABLED. */
export async function login(emailInput: string, password: string, requestId: string): Promise<LoginResult> {
  const email = emailInput.trim().toLowerCase();
  const admin = await prisma.adminUser.findUnique({
    where: { email },
    select: { id: true, email: true, displayName: true, passwordHash: true, isActive: true, tokenVersion: true },
  });
  const valid = admin ? await verifyPassword(admin.passwordHash, password) : await verifyAgainstDummy(password);
  if (!admin || !valid) {
    logger.warn({ requestId, emailHash: emailHash(email) }, 'admin login failed: bad credentials');
    throw new AppError('INVALID_CREDENTIALS');
  }
  if (!admin.isActive) throw new AppError('ADMIN_DISABLED');
  await prisma.adminUser.update({ where: { id: admin.id }, data: { lastLoginAt: new Date() } });
  const { accessToken, expiresAt } = signAdminToken(admin);
  return {
    accessToken,
    expiresAt: expiresAt.toISOString(),
    admin: { id: admin.id, email: admin.email, displayName: admin.displayName },
  };
}

/** "Log out everywhere": token_version += 1 invalidates every issued token. */
export async function logoutAll(adminId: string): Promise<void> {
  await prisma.adminUser.update({ where: { id: adminId }, data: { tokenVersion: { increment: 1 } } });
}
