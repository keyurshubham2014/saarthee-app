import { Router, type Request } from 'express';
import { z } from 'zod';
import { config } from '../../config';
import { rateLimit } from '../../middleware/rateLimit';
import { requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { CONSENT_PURPOSES, loadMe, setConsent, updateMe } from './profile.service';
import { deleteAccount, exportData } from './privacy.service';

export { registerErasureStep, registerExportSection } from './privacy.registry';

/** Citizen profile and privacy (TASK-04 §5.3). No user id in any path: a user can only reach their own data. */
export const meRouter = Router();

const userKey = (req: Request) => `user:${req.user?.id ?? 'none'}`;
const MIN = 60_000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;
const readLimiter = rateLimit({ windowMs: MIN, max: 120, keyGenerator: userKey });
const patchLimiter = rateLimit({ windowMs: HOUR, max: 30, keyGenerator: userKey });
const consentLimiter = rateLimit({ windowMs: HOUR, max: 30, keyGenerator: userKey });
const exportLimiter = rateLimit({ windowMs: DAY, max: 3, keyGenerator: userKey });
const deleteLimiter = rateLimit({ windowMs: DAY, max: 3, keyGenerator: userKey });

export const patchMeBody = z
  .strictObject({
    displayName: z.string().trim().min(1).max(40).nullable().optional(),
    language: z.enum(['gu', 'en']).optional(),
    homeWardId: z.uuid().nullable().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'Send at least one field.' });

const consentBody = z.strictObject({
  purpose: z.enum(CONSENT_PURPOSES as [string, ...string[]]),
  granted: z.boolean(),
  textVersion: z.string().refine((v) => config.CONSENT_TEXT_VERSIONS_V2.includes(v), 'Unknown consent text version.'),
});

const deleteBody = z.strictObject({ confirm: z.literal('DELETE') });

meRouter.get('/me', requireUser, readLimiter, async (req, res) => {
  res.json(await loadMe(req.user!.id));
});

meRouter.patch('/me', requireUser, patchLimiter, validate({ body: patchMeBody }), async (req, res) => {
  res.json(await updateMe(req.user!.id, req.body as z.infer<typeof patchMeBody>));
});

meRouter.post('/me/consents', requireUser, consentLimiter, validate({ body: consentBody }), async (req, res) => {
  const { purpose, granted, textVersion } = req.body as z.infer<typeof consentBody>;
  res.json({ consents: await setConsent(req.user!.id, purpose as (typeof CONSENT_PURPOSES)[number], granted, textVersion) });
});

meRouter.get('/me/export', requireUser, exportLimiter, async (req, res) => {
  const data = await exportData(req.user!.id);
  const day = new Date().toISOString().slice(0, 10);
  res.setHeader('Content-Disposition', `attachment; filename="saarthee-my-data-${day}.json"`);
  res.setHeader('Cache-Control', 'no-store');
  res.json(data);
});

meRouter.delete('/me', requireUser, deleteLimiter, validate({ body: deleteBody }), async (req, res) => {
  await deleteAccount(req.user!.id, req.id);
  res.status(204).end();
});
