import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../lib/db';
import { rateLimit } from '../../middleware/rateLimit';
import { optionalUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';

/** POST /devices (TASK-04 §5.3, REQ-F-010): one row per install, latest FCM token, user linked when signed in. */
export const devicesRouter = Router();

const limiter = rateLimit({ windowMs: 3_600_000, max: 30 });

const topic = z.string().regex(/^[a-z0-9_]{1,60}__(gu|en)$/);

const deviceBody = z.strictObject({
  installId: z.uuid(),
  fcmToken: z.string().min(1).max(4096).nullable().optional(),
  platform: z.enum(['android', 'ios']),
  appVersion: z.string().min(1).max(20),
  language: z.enum(['gu', 'en']),
  topics: z.array(topic).max(50).optional(),
});

type DeviceBody = z.infer<typeof deviceBody>;

/** Upsert by install_id. The same FCM token on another install is cleared first (token moved). */
export async function registerDevice(body: DeviceBody, userId: string | undefined): Promise<string> {
  return prisma.$transaction(async (tx) => {
    let fcmToken = body.fcmToken ?? null;
    if (userId && fcmToken) {
      // A user who withdrew the notifications consent keeps no push token server-side.
      const withdrawn = await tx.consent.findFirst({ where: { userId, purpose: 'notifications' }, orderBy: { grantedAt: 'desc' } });
      if (withdrawn?.withdrawnAt) fcmToken = null;
    }
    if (fcmToken) await tx.device.updateMany({ where: { fcmToken, installId: { not: body.installId } }, data: { fcmToken: null } });
    const common = {
      fcmToken,
      platform: body.platform,
      appVersion: body.appVersion,
      language: body.language,
      ...(body.topics ? { topics: body.topics } : {}),
      lastSeenAt: new Date(),
    };
    const device = await tx.device.upsert({
      where: { installId: body.installId },
      create: { installId: body.installId, userId: userId ?? null, ...common },
      update: { ...common, ...(userId ? { userId } : {}) },
      select: { id: true },
    });
    return device.id;
  });
}

devicesRouter.post('/devices', limiter, optionalUser, validate({ body: deviceBody }), async (req, res) => {
  res.json({ deviceId: await registerDevice(req.body as DeviceBody, req.user?.id) });
});
