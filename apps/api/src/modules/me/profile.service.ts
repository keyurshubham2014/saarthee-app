import type { ConsentPurpose, Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

type Db = Prisma.TransactionClient | typeof prisma;

export interface WardRef {
  id: string;
  number: number | null;
  nameEn: string | null;
  nameGu: string | null;
}

export interface MeConsent {
  purpose: ConsentPurpose;
  granted: boolean;
  textVersion: string;
  grantedAt: string;
  withdrawnAt: string | null;
}

export interface Me {
  id: string;
  displayName: string | null;
  phoneMasked: string | null;
  language: 'gu' | 'en';
  role: string;
  homeWard: WardRef | null;
  consents: MeConsent[];
  createdAt: string;
}

export const CONSENT_PURPOSES: ConsentPurpose[] = ['core_service', 'share_with_representatives', 'share_with_amc_handoff', 'notifications'];

/** "+91 ••••• ••210" — the phone is never returned unmasked (TASK-04 §5.3). */
export function maskPhone(phone: string | null): string | null {
  if (!phone) return null;
  const m = /^\+91(\d{10})$/.exec(phone);
  if (m) return `+91 ••••• ••${m[1]!.slice(-3)}`;
  return `${phone.slice(0, 3)} ••••• ••${phone.slice(-3)}`;
}

let wardsTable: boolean | undefined;

/** True once TASK-02's `wards` table exists (checked until found, then cached). */
async function hasWardsTable(db: Db): Promise<boolean> {
  if (wardsTable) return true;
  const rows = await db.$queryRaw<{ exists: boolean }[]>`SELECT to_regclass('public.wards') IS NOT NULL AS "exists"`;
  wardsTable = rows[0]?.exists === true;
  return wardsTable;
}

/**
 * Looks a ward up in TASK-02's `wards` table. Before that table exists any UUID is accepted and returned
 * with null details (ASSUMPTION in TASK-04 §5.6); afterwards an unknown id → 422 WARD_NOT_FOUND.
 */
export async function findWard(db: Db, id: string): Promise<WardRef> {
  if (!(await hasWardsTable(db))) return { id, number: null, nameEn: null, nameGu: null };
  const rows = await db.$queryRaw<{ id: string; number: number; name_en: string; name_gu: string }[]>`
    SELECT id::text AS id, number::int AS number, name_en, name_gu FROM wards WHERE id = ${id}::uuid`;
  const w = rows[0];
  if (!w) throw new AppError('WARD_NOT_FOUND');
  return { id: w.id, number: w.number, nameEn: w.name_en, nameGu: w.name_gu };
}

/** Latest consent row per purpose (history stays in the table). */
export async function currentConsents(db: Db, userId: string): Promise<MeConsent[]> {
  const rows = await db.consent.findMany({ where: { userId }, orderBy: { grantedAt: 'desc' } });
  const seen = new Set<ConsentPurpose>();
  const out: MeConsent[] = [];
  for (const r of rows) {
    if (seen.has(r.purpose)) continue;
    seen.add(r.purpose);
    out.push({
      purpose: r.purpose,
      granted: r.withdrawnAt === null,
      textVersion: r.textVersion,
      grantedAt: r.grantedAt.toISOString(),
      withdrawnAt: r.withdrawnAt?.toISOString() ?? null,
    });
  }
  return out.sort((a, b) => CONSENT_PURPOSES.indexOf(a.purpose) - CONSENT_PURPOSES.indexOf(b.purpose));
}

export async function loadMe(userId: string, db: Db = prisma): Promise<Me> {
  const user = await db.user.findUniqueOrThrow({ where: { id: userId } });
  let homeWard: WardRef | null = null;
  if (user.homeWardId) {
    homeWard = await findWard(db, user.homeWardId).catch(() => ({ id: user.homeWardId!, number: null, nameEn: null, nameGu: null }));
  }
  return {
    id: user.id,
    displayName: user.displayName,
    phoneMasked: maskPhone(user.phoneE164),
    language: user.language,
    role: user.role,
    homeWard,
    consents: await currentConsents(db, user.id),
    createdAt: user.createdAt.toISOString(),
  };
}

export async function updateMe(
  userId: string,
  patch: { displayName?: string | null; language?: 'gu' | 'en'; homeWardId?: string | null },
): Promise<Me> {
  if (patch.homeWardId) await findWard(prisma, patch.homeWardId);
  await prisma.user.update({
    where: { id: userId },
    data: {
      ...(patch.displayName !== undefined ? { displayName: patch.displayName?.trim() || null } : {}),
      ...(patch.language ? { language: patch.language } : {}),
      ...(patch.homeWardId !== undefined ? { homeWardId: patch.homeWardId } : {}),
      lastSeenAt: new Date(),
    },
  });
  return loadMe(userId);
}

/** POST /me/consents rules: withdrawing core → 409; withdrawing notifications clears the user's FCM tokens. */
export async function setConsent(userId: string, purpose: ConsentPurpose, granted: boolean, textVersion: string): Promise<MeConsent[]> {
  if (!granted && purpose === 'core_service') throw new AppError('CORE_CONSENT_REQUIRED');
  await prisma.$transaction(async (tx) => {
    const active = await tx.consent.findFirst({ where: { userId, purpose, withdrawnAt: null } });
    if (granted && !active) await tx.consent.create({ data: { userId, purpose, textVersion } });
    if (!granted && active) {
      await tx.consent.update({ where: { id: active.id }, data: { withdrawnAt: new Date() } });
      if (purpose === 'notifications') await tx.device.updateMany({ where: { userId }, data: { fcmToken: null } });
    }
  });
  return currentConsents(prisma, userId);
}
