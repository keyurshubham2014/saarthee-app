/**
 * Message relay (TASK-09 §5.3, REQ-F-044, REQ-S-009). Workflow: consent → representative contact →
 * idempotency → DB-backed IST-day rate limits → profanity screen → issue check → insert `queued` →
 * immediate send attempt (the `relay-send` job retries every 30 s, 3 attempts, then `failed` + ops alert).
 * Never logs subject, body, phone numbers or email addresses.
 */
import { config } from '../../config';
import { newReplyToken, replyAddress } from '../rep-messages/inbox.service';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { containsProfanity } from '../../lib/profanity';
import { sendMail } from '../../lib/mail';
import { renderRelayEmail } from './relay.email';

export interface RelayInput {
  clientMessageId: string;
  subject: string;
  body: string;
  issueId?: string;
  sharePhone: boolean;
}

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
export const MAX_ATTEMPTS = 3;
const BACKOFF_MS = [30_000, 120_000, 600_000];

/** Start of the current IST calendar day and seconds until the next IST midnight. */
export function istDay(now: Date): { start: Date; secondsToMidnight: number } {
  const ist = now.getTime() + IST_OFFSET_MS;
  const dayStartIst = Math.floor(ist / 86_400_000) * 86_400_000;
  const start = new Date(dayStartIst - IST_OFFSET_MS);
  return { start, secondsToMidnight: Math.max(1, Math.ceil((dayStartIst + 86_400_000 - ist) / 1000)) };
}

export class RelayRateLimited extends AppError {
  constructor(readonly retryAfter: number, readonly scope: 'representative' | 'daily') {
    super('RATE_LIMITED', {
      message:
        scope === 'representative'
          ? `You've sent ${config.RELAY_PER_REP_DAILY} messages to this representative today. You can send more tomorrow.`
          : "You've sent the most messages allowed today. You can send more tomorrow.",
      details: [{ field: 'scope', issue: scope }],
    });
  }
}

async function hasRelayConsent(userId: string): Promise<boolean> {
  const latest = await prisma.consent.findFirst({
    where: { userId, purpose: 'share_with_representatives' },
    orderBy: { grantedAt: 'desc' },
  });
  return latest !== null && latest.withdrawnAt === null;
}

export async function submitRelayMessage(userId: string, representativeId: string, input: RelayInput, now = new Date()) {
  const existing = await prisma.repMessage.findUnique({ where: { clientMessageId: input.clientMessageId } });
  if (existing) {
    if (existing.citizenId !== userId || existing.representativeId !== representativeId) {
      throw new AppError('VALIDATION_FAILED', { details: [{ field: 'clientMessageId', issue: 'Already used.' }] });
    }
    return { created: false, messageId: existing.id, status: existing.status };
  }
  const rep = await prisma.representative.findFirst({ where: { id: representativeId, isActive: true } });
  if (!rep) throw new AppError('NOT_FOUND');
  if (!(await hasRelayConsent(userId))) {
    throw new AppError('CONSENT_REQUIRED', { status: 403, message: 'Please agree to share your message with representatives first.' });
  }
  if (!rep.publicEmail) throw new AppError('REP_NO_CONTACT');

  const { start, secondsToMidnight } = istDay(now);
  const [toRep, total] = await Promise.all([
    prisma.repMessage.count({ where: { citizenId: userId, representativeId, createdAt: { gte: start } } }),
    prisma.repMessage.count({ where: { citizenId: userId, createdAt: { gte: start } } }),
  ]);
  if (toRep >= config.RELAY_PER_REP_DAILY) throw new RelayRateLimited(secondsToMidnight, 'representative');
  if (total >= config.RELAY_PER_USER_DAILY) throw new RelayRateLimited(secondsToMidnight, 'daily');

  if (containsProfanity(input.subject, input.body)) {
    logger.info({ event: 'relay_rejected_language', representativeId }, 'relay_rejected_language');
    throw new AppError('MESSAGE_LANGUAGE');
  }
  if (input.issueId) {
    const issue = await prisma.issue.findUnique({ where: { id: input.issueId }, select: { visibility: true } });
    if (!issue || issue.visibility !== 'public') {
      throw new AppError('VALIDATION_FAILED', { details: [{ field: 'issueId', issue: 'Choose one of your public reports.' }] });
    }
  }
  const msg = await prisma.repMessage.create({
    data: {
      clientMessageId: input.clientMessageId,
      representativeId,
      citizenId: userId,
      issueId: input.issueId ?? null,
      subject: input.subject,
      body: input.body,
      sharePhone: input.sharePhone,
    },
  });
  logger.info({ event: 'relay_queued', messageId: msg.id, representativeId }, 'relay_queued');
  await attemptSend(msg.id, now).catch(() => undefined);
  return { created: true, messageId: msg.id, status: 'queued' as const };
}

/**
 * Claims one due message (atomic UPDATE … RETURNING so two workers never send the same row) and sends it.
 * Returns the resulting status, or null when nothing was due.
 */
export async function attemptSend(messageId: string, now = new Date()): Promise<'sent' | 'queued' | 'failed' | null> {
  const lease = new Date(now.getTime() + 5 * 60_000);
  const claimed = await prisma.$queryRaw<{ id: string; attempts: number }[]>`
    UPDATE rep_messages SET attempts = attempts + 1, next_attempt_at = ${lease}
    WHERE id = ${messageId}::uuid AND status = 'queued' AND attempts < ${MAX_ATTEMPTS}
      AND (next_attempt_at IS NULL OR next_attempt_at <= ${now})
    RETURNING id, attempts`;
  const row = claimed[0];
  if (!row) return null;
  const msg = await prisma.repMessage.findUniqueOrThrow({
    where: { id: messageId },
    include: {
      representative: { include: { user: { select: { language: true } } } },
      citizen: { select: { displayName: true, phoneE164: true, homeWard: { select: { number: true, nameEn: true, nameGu: true } } } },
    },
  });
  try {
    if (!msg.representative.publicEmail) throw Object.assign(new Error('no contact'), { code: 'REP_NO_CONTACT' });
    // A representative with a linked account reads their app language; an official inbox gets both languages.
    const mail = renderRelayEmail(msg, msg.representative.user?.language ?? 'both');
    // TASK-11: per-message Reply-To so replies sent by email are tracked (inbound webhook).
    const replyToken = msg.replyToken ?? newReplyToken();
    if (!msg.replyToken) await prisma.repMessage.update({ where: { id: messageId }, data: { replyToken } });
    const { providerMessageId } = await sendMail({
      from: `Saarthee Relay <${config.SES_FROM}>`,
      to: msg.representative.publicEmail,
      replyTo: replyAddress(replyToken),
      ...mail,
      tag: 'relay',
    });
    await prisma.repMessage.update({ where: { id: messageId }, data: { status: 'sent', sentAt: new Date(), providerMessageId, nextAttemptAt: null } });
    logger.info({ event: 'relay_sent', messageId, attempts: row.attempts }, 'relay_sent');
    return 'sent';
  } catch (err) {
    const code = (err as { code?: string }).code ?? (err as Error).name;
    if (row.attempts >= MAX_ATTEMPTS) {
      await prisma.repMessage.update({ where: { id: messageId }, data: { status: 'failed', nextAttemptAt: null } });
      logger.error({ event: 'relay_send_failed', alert: 'ops', messageId, attempts: row.attempts, code }, 'relay_send_failed');
      return 'failed';
    }
    const next = new Date(now.getTime() + BACKOFF_MS[row.attempts - 1]!);
    await prisma.repMessage.update({ where: { id: messageId }, data: { nextAttemptAt: next } });
    logger.warn({ event: 'relay_send_retry', messageId, attempts: row.attempts, code }, 'relay_send_retry');
    return 'queued';
  }
}

/** Outbox job body (`relay-send`, every 30 s): attempts every due queued message. */
export async function flushRelayOutbox(now = new Date()): Promise<{ sent: number; failed: number; retried: number }> {
  const due = await prisma.repMessage.findMany({
    where: { status: 'queued', attempts: { lt: MAX_ATTEMPTS }, OR: [{ nextAttemptAt: null }, { nextAttemptAt: { lte: now } }] },
    select: { id: true },
    orderBy: { createdAt: 'asc' },
    take: 100,
  });
  const out = { sent: 0, failed: 0, retried: 0 };
  for (const { id } of due) {
    const r = await attemptSend(id, now);
    if (r === 'sent') out.sent += 1;
    else if (r === 'failed') out.failed += 1;
    else if (r === 'queued') out.retried += 1;
  }
  return out;
}
