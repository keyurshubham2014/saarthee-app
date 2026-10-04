import type { ConsentPurpose } from '@prisma/client';
import { config } from '../../config';
import { userAudit } from '../../lib/audit';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { firebaseGateway, FirebaseTokenError, FirebaseUnavailableError, type VerifiedPhoneIdentity } from '../../lib/firebase';
import { logger } from '../../lib/logger';
import { signUserToken } from '../../lib/tokens';
import { findWard, loadMe, type Me } from '../me/profile.service';

export interface SignInInput {
  idToken: string;
  ageConfirmed: boolean;
  consents: { purpose: ConsentPurpose; textVersion: string }[];
  language: 'gu' | 'en';
  homeWardId?: string | null;
  installId?: string;
}

export interface SignInResult {
  accessToken: string;
  expiresAt: string;
  user: Me;
  isNew: boolean;
}

async function verify(idToken: string, requestId: string): Promise<VerifiedPhoneIdentity> {
  try {
    return await firebaseGateway().verifyIdToken(idToken);
  } catch (err) {
    if (err instanceof FirebaseUnavailableError) {
      logger.warn({ requestId, firebaseCode: err.code }, 'firebase unavailable');
      throw new AppError('FIREBASE_UNAVAILABLE');
    }
    // Cause logged as a code only — never the token (REQ-S-015).
    logger.warn({ requestId, firebaseCode: err instanceof FirebaseTokenError ? err.code : 'unknown' }, 'firebase token rejected');
    throw new AppError('FIREBASE_TOKEN_INVALID');
  }
}

/** POST /auth/firebase workflow (TASK-04 §5.3). */
export async function signInWithFirebase(input: SignInInput, requestId: string): Promise<SignInResult> {
  const core = input.consents.find((c) => c.purpose === 'core_service');
  if (!core) throw new AppError('CONSENT_REQUIRED');
  if (input.consents.some((c) => !config.CONSENT_TEXT_VERSIONS_V2.includes(c.textVersion))) {
    throw new AppError('CONSENT_REQUIRED', { details: [{ field: 'consents.textVersion', issue: 'Unknown consent text version.' }] });
  }

  const identity = await verify(input.idToken, requestId);
  const existing =
    (await prisma.user.findUnique({ where: { firebaseUid: identity.uid } })) ??
    (await prisma.user.findUnique({ where: { phoneE164: identity.phoneE164 } }));

  if (existing?.status === 'suspended') throw new AppError('ACCOUNT_SUSPENDED');
  if ((!existing || !existing.ageConfirmedAt) && input.ageConfirmed !== true) throw new AppError('AGE_CONFIRMATION_REQUIRED');
  if (input.homeWardId) await findWard(prisma, input.homeWardId);

  const now = new Date();
  const user = await prisma.$transaction(async (tx) => {
    const u = existing
      ? await tx.user.update({
          where: { id: existing.id },
          data: {
            firebaseUid: identity.uid,
            phoneE164: identity.phoneE164,
            ...(existing.ageConfirmedAt ? {} : { ageConfirmedAt: now }),
            ...(!existing.homeWardId && input.homeWardId ? { homeWardId: input.homeWardId } : {}),
            lastSeenAt: now,
          },
        })
      : await tx.user.create({
          data: {
            firebaseUid: identity.uid,
            phoneE164: identity.phoneE164,
            language: input.language,
            homeWardId: input.homeWardId ?? null,
            ageConfirmedAt: now,
            lastSeenAt: now,
          },
        });
    const active = await tx.consent.findMany({ where: { userId: u.id, withdrawnAt: null }, select: { purpose: true } });
    const activePurposes = new Set(active.map((c) => c.purpose));
    for (const c of input.consents) {
      if (activePurposes.has(c.purpose)) continue;
      activePurposes.add(c.purpose);
      await tx.consent.create({ data: { userId: u.id, purpose: c.purpose, textVersion: c.textVersion, grantedAt: now } });
    }
    if (input.installId) await tx.device.updateMany({ where: { installId: input.installId }, data: { userId: u.id } });
    return u;
  });

  const { accessToken, expiresAt } = signUserToken({ id: user.id, tokenVersion: user.tokenVersion, role: user.role });
  userAudit(requestId, 'user.signed_in', user.id);
  return { accessToken, expiresAt: expiresAt.toISOString(), user: await loadMe(user.id), isNew: !existing };
}

/** POST /auth/logout: token_version + 1 signs out every device; the install is unlinked from the user. */
export async function logout(userId: string, installId?: string): Promise<void> {
  await prisma.$transaction([
    prisma.user.update({ where: { id: userId }, data: { tokenVersion: { increment: 1 } } }),
    prisma.device.updateMany({ where: { userId, ...(installId ? { installId } : { id: '00000000-0000-0000-0000-000000000000' }) }, data: { userId: null } }),
  ]);
}
