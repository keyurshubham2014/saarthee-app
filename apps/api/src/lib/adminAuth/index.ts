import { prisma } from '../db';

export interface AuthenticatedAdmin {
  id: string;
  email: string;
  displayName: string;
}

declare module 'express-serve-static-core' {
  interface Request {
    admin?: AuthenticatedAdmin;
  }
}

/** Loads the admin for a verified token; null when missing, disabled or token_version differs (→ TOKEN_REVOKED). */
export async function loadAdminForToken(adminId: string, tokenVersion: number): Promise<AuthenticatedAdmin | null> {
  const admin = await prisma.adminUser.findUnique({
    where: { id: adminId },
    select: { id: true, email: true, displayName: true, isActive: true, tokenVersion: true },
  });
  if (!admin || !admin.isActive || admin.tokenVersion !== tokenVersion) return null;
  return { id: admin.id, email: admin.email, displayName: admin.displayName };
}
