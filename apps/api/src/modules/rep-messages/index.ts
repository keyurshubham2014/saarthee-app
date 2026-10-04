/**
 * TASK-11 messages (REQ-F-056, P2): representative inbox/detail/in-app reply, citizen `/me/messages`, and the
 * signed inbound-mail webhook that records replies sent by email to `reply+<token>@MAIL_REPLY_DOMAIN`.
 */
import type { Request } from 'express';
import { Router } from 'express';
import { z } from 'zod';
import { auditStaff } from '../../lib/audit';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { decodeCursor, encodeCursor } from '../../lib/pagination';
import { rateLimit } from '../../middleware/rateLimit';
import { requireStaff } from '../../middleware/requireStaff';
import { requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { citizenMessages, handleInbound, inbox, readMessage, replyInApp, signatureOk } from './inbox.service';

export const repMessagesRouter = Router();

const key = (p: string) => (req: Request) => `${p}:${req.staff?.actorId ?? 'none'}`;
const reps = requireStaff('representative');
const readLimiter = rateLimit({ windowMs: 60_000, max: 120, keyGenerator: key('rep-msg-read') });
const replyLimiter = rateLimit({ windowMs: 24 * 60 * 60_000, max: 20, keyGenerator: key('rep-msg-reply') });
const webhookLimiter = rateLimit({ windowMs: 60_000, max: 60 });

const idParams = z.object({ id: z.uuid() });
const listQuery = z.object({
  status: z.enum(['sent', 'replied']).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(25),
});
const replyBody = z.strictObject({ body: z.string().trim().min(1).max(2000) });
const inboundBody = z.object({ to: z.string().max(320), from: z.string().max(320).optional(), text: z.string().max(100_000), receivedAt: z.string().optional() });

repMessagesRouter.get('/staff/rep-messages', reps, readLimiter, validate({ query: listQuery }), async (req, res) => {
  const q = res.locals.query as z.infer<typeof listQuery>;
  const page = await inbox(req.staff!.actorId, q.status, q.cursor ? decodeCursor(q.cursor) : null, q.limit);
  res.setHeader('Cache-Control', 'no-store');
  res.json({ items: page.items, nextCursor: page.more && page.last ? encodeCursor({ k: page.last.createdAt.toISOString(), id: page.last.id }) : null, unread: page.unread });
});

repMessagesRouter.get('/staff/rep-messages/:id', reps, readLimiter, validate({ params: idParams }), async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.json(await readMessage(req.staff!.actorId, (res.locals.params as z.infer<typeof idParams>).id));
});

repMessagesRouter.post('/staff/rep-messages/:id/reply', reps, replyLimiter, validate({ params: idParams, body: replyBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const out = await replyInApp(req.staff!.actorId, id, (req.body as z.infer<typeof replyBody>).body);
  auditStaff(req, 'rep_message_replied', { targetType: 'rep_message', targetId: id, extra: { channel: 'in_app' } });
  res.json(out);
});

repMessagesRouter.get('/me/messages', requireUser, async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.json(await citizenMessages(req.user!.id));
});

repMessagesRouter.post('/webhooks/mail-inbound', webhookLimiter, async (req, res) => {
  if (!signatureOk((req as { rawBody?: Buffer }).rawBody, req.header('x-saarthee-signature'))) throw new AppError('BAD_SIGNATURE');
  const parsed = inboundBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(200).json({ status: 'ignored' });
    return;
  }
  const outcome = await handleInbound(parsed.data.to, parsed.data.text);
  if (outcome === 'recorded') logger.info({ requestId: req.id, action: 'rep_message_replied', channel: 'email' }, 'mail_inbound');
  res.status(outcome === 'recorded' ? 202 : 200).json({ status: outcome });
});
