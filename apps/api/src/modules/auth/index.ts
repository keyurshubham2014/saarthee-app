import { Router, type Request } from 'express';
import { z } from 'zod';
import { rateLimit } from '../../middleware/rateLimit';
import { requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { CONSENT_PURPOSES } from '../me/profile.service';
import { logout, signInWithFirebase, type SignInInput } from './auth.service';

/** Citizen sign-in (TASK-04 §5.3). v1 admin login (/admin/auth/login) is unchanged. */
export const authRouter = Router();

// 10/IP/min and 30/IP/h on the exchange (Firebase does the SMS rate limiting itself).
const exchangeMinute = rateLimit({ windowMs: 60_000, max: 10 });
const exchangeHour = rateLimit({ windowMs: 3_600_000, max: 30 });
const logoutLimiter = rateLimit({ windowMs: 3_600_000, max: 30, keyGenerator: (req: Request) => `user:${req.user?.id ?? 'none'}` });

const purpose = z.enum(CONSENT_PURPOSES as [string, ...string[]]);

const signInBody = z.strictObject({
  idToken: z.string().min(1).max(4096),
  ageConfirmed: z.boolean(),
  consents: z.array(z.strictObject({ purpose, textVersion: z.string().min(1).max(20) })).max(4),
  language: z.enum(['gu', 'en']),
  homeWardId: z.uuid().nullable().optional(),
  installId: z.uuid().optional(),
});

const logoutBody = z.strictObject({ installId: z.uuid().optional() });

authRouter.post('/auth/firebase', exchangeMinute, exchangeHour, validate({ body: signInBody }), async (req, res) => {
  const result = await signInWithFirebase(req.body as SignInInput, req.id);
  res.status(result.isNew ? 201 : 200).json(result);
});

authRouter.post('/auth/logout', requireUser, logoutLimiter, validate({ body: logoutBody }), async (req, res) => {
  await logout(req.user!.id, (req.body as z.infer<typeof logoutBody>).installId);
  res.status(204).end();
});
