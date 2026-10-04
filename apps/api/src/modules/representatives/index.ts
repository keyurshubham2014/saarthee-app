/**
 * Public representative endpoints and the message relay (TASK-09 §5.3):
 * GET /wards/{id}/representatives, GET /representatives/{id}, POST /representatives/{id}/messages,
 * GET /wards/{id}/scorecard. Public reads: 120 per IP per minute.
 */
import { Router } from 'express';
import { z } from 'zod';
import { rateLimit } from '../../middleware/rateLimit';
import { requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { registerErasureStep, registerExportSection } from '../me/privacy.registry';
import { representativeDetail, wardRepresentatives } from './representatives.service';
import { RelayRateLimited, submitRelayMessage, type RelayInput } from './relay.service';
import { wardScorecard } from './scorecard.service';

export const representativesRouter = Router();

const readLimiter = rateLimit({ windowMs: 60_000, max: 120 });
const relayIpLimiter = rateLimit({ windowMs: 60_000, max: 30 });

const idParams = z.object({ id: z.uuid() });

export const relayBody = z.strictObject({
  clientMessageId: z.uuid(),
  subject: z.string().trim().min(3).max(120),
  body: z.string().trim().min(10).max(1000),
  issueId: z.uuid().nullish().transform((v) => v ?? undefined),
  sharePhone: z.boolean().default(false),
});

representativesRouter.get('/wards/:id/representatives', readLimiter, validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.setHeader('Cache-Control', 'public, max-age=60');
  res.json(await wardRepresentatives(id));
});

representativesRouter.get('/representatives/:id', readLimiter, validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.setHeader('Cache-Control', 'public, max-age=60');
  res.json(await representativeDetail(id));
});

representativesRouter.post(
  '/representatives/:id/messages',
  relayIpLimiter,
  requireUser,
  validate({ params: idParams, body: relayBody }),
  async (req, res) => {
    const { id } = res.locals.params as z.infer<typeof idParams>;
    try {
      const out = await submitRelayMessage(req.user!.id, id, req.body as RelayInput);
      res.status(out.created ? 202 : 200).json({ messageId: out.messageId, status: out.status });
    } catch (err) {
      if (err instanceof RelayRateLimited) res.setHeader('Retry-After', String(err.retryAfter));
      throw err;
    }
  },
);

representativesRouter.get('/wards/:id/scorecard', readLimiter, validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.setHeader('Cache-Control', 'public, max-age=300');
  res.json(await wardScorecard(id));
});

// Personal data (TASK-04 registries): a citizen's relay messages are exported; on account deletion the
// message stays for the representative's record but is unlinked from the citizen (ASSUMPTION §5.6).
registerExportSection('rep_messages', (userId, tx) =>
  tx.repMessage.findMany({
    where: { citizenId: userId },
    orderBy: { createdAt: 'asc' },
    select: {
      id: true, representativeId: true, issueId: true, subject: true, body: true, sharePhone: true, status: true, sentAt: true, createdAt: true,
      representative: { select: { nameEn: true, nameGu: true, role: true } },
    },
  }),
);
registerErasureStep('rep_messages', async (userId, tx) => {
  await tx.repMessage.updateMany({ where: { citizenId: userId }, data: { citizenId: null } });
});
