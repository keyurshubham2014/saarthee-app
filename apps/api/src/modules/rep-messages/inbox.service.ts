/**
 * TASK-11 relayed-message inbox (REQ-F-056, P2). A representative sees only messages addressed to their own
 * (verified, in-term) representative records; the citizen appears as "A resident of {ward}" and the phone only
 * when they opted to share it. In-app replies are frozen in election mode; email replies are tracked through
 * the signed inbound webhook. Bodies and replies are never logged.
 */
import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import type { Prisma } from '@prisma/client';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { notifyUser } from '../../lib/push';
import { getRepScope } from '../rep-claims/scope';
import { isElectionMode } from '../settings/electionMode';

const msgSelect = {
  id: true, subject: true, body: true, issueId: true, sharePhone: true, createdAt: true, status: true, repliedAt: true,
  readByRepAt: true, replyChannel: true, replyBody: true, representativeId: true,
  citizen: { select: { phoneE164: true, homeWard: { select: { id: true, number: true, nameEn: true, nameGu: true } } } },
} satisfies Prisma.RepMessageSelect;
type MsgRow = Prisma.RepMessageGetPayload<{ select: typeof msgSelect }>;

export const newReplyToken = () => randomBytes(16).toString('hex');
export const replyAddress = (token: string) => `reply+${token}@${config.MAIL_REPLY_DOMAIN}`;

function citizenLabel(m: MsgRow) {
  const w = m.citizen?.homeWard;
  return { en: w ? `A resident of ward ${w.number} ${w.nameEn}` : 'A resident', gu: w ? `વોર્ડ ${w.number} ${w.nameGu}ના રહેવાસી` : 'એક રહેવાસી' };
}

function card(m: MsgRow) {
  return {
    id: m.id, subject: m.subject, bodyPreview: m.body.slice(0, 120), issueId: m.issueId, citizenLabel: citizenLabel(m),
    ...(m.sharePhone && m.citizen?.phoneE164 ? { sharedPhone: m.citizen.phoneE164 } : {}),
    createdAt: m.createdAt.toISOString(), status: m.status, repliedAt: m.repliedAt?.toISOString() ?? null,
    replyChannel: m.replyChannel, readByRepAt: m.readByRepAt?.toISOString() ?? null,
  };
}

const VISIBLE = { status: { in: ['sent', 'replied'] } } satisfies Prisma.RepMessageWhereInput;

export async function inbox(userId: string, status: 'sent' | 'replied' | undefined, cursor: { k: string; id: string } | null, limit: number) {
  const { representativeIds } = await getRepScope(userId);
  const base: Prisma.RepMessageWhereInput = { representativeId: { in: representativeIds }, ...VISIBLE };
  const rows = await prisma.repMessage.findMany({
    where: {
      ...base, ...(status ? { status } : {}),
      ...(cursor ? { OR: [{ createdAt: { lt: new Date(cursor.k) } }, { createdAt: new Date(cursor.k), id: { lt: cursor.id } }] } : {}),
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: limit + 1, select: msgSelect,
  });
  const unread = await prisma.repMessage.count({ where: { ...base, readByRepAt: null } });
  const page = rows.slice(0, limit);
  return { items: page.map(card), last: page[page.length - 1], more: rows.length > limit, unread };
}

async function own(userId: string, id: string): Promise<MsgRow> {
  const m = await prisma.repMessage.findFirst({ where: { id, ...VISIBLE }, select: msgSelect });
  if (!m) throw new AppError('NOT_FOUND');
  const { representativeIds } = await getRepScope(userId);
  if (!representativeIds.includes(m.representativeId)) throw new AppError('FORBIDDEN');
  return m;
}

export async function readMessage(userId: string, id: string) {
  const m = await own(userId, id);
  if (!m.readByRepAt) await prisma.repMessage.update({ where: { id }, data: { readByRepAt: clockNow() } });
  return { ...card(m), body: m.body, reply: m.replyBody, readByRepAt: (m.readByRepAt ?? clockNow()).toISOString() };
}

export async function replyInApp(userId: string, id: string, body: string) {
  const m = await own(userId, id);
  const wardId = m.citizen?.homeWard?.id;
  const frozen = wardId ? await isElectionMode(wardId) : false;
  if (frozen) throw new AppError('ELECTION_MODE_FROZEN');
  return recordReply(m.id, body, 'in_app');
}

/** Sets the reply once (409 ALREADY_REPLIED otherwise) and notifies the citizen (push + inbox). */
export async function recordReply(id: string, body: string, channel: 'email' | 'in_app') {
  const at = clockNow();
  const n = await prisma.repMessage.updateMany({
    where: { id, repliedAt: null },
    data: { status: 'replied', repliedAt: at, replyChannel: channel, replyBody: body.slice(0, 2000) },
  });
  if (n.count !== 1) throw new AppError('ALREADY_REPLIED');
  const m = await prisma.repMessage.findUniqueOrThrow({ where: { id }, select: { citizenId: true, representative: { select: { nameEn: true, nameGu: true } } } });
  if (m.citizenId) {
    try {
      await notifyUser(m.citizenId, {
        kind: 'system', refId: id, route: '/me/messages', channel: 'updates',
        title: { en: clip(`${m.representative.nameEn} replied`), gu: clip(`${m.representative.nameGu} તરફથી જવાબ આવ્યો`) },
        body: { en: 'Open Saarthee to read the reply.', gu: 'જવાબ વાંચવા સારથી ખોલો.' },
      });
    } catch (err) {
      logger.error({ messageId: id, reason: err instanceof Error ? err.message : 'unknown' }, 'reply notification failed');
    }
  }
  return { status: 'replied' as const, repliedAt: at.toISOString() };
}

/** Push titles are capped at 120 characters (TASK-04); representative names can be up to 120 on their own. */
const clip = (s: string) => (s.length <= 120 ? s : `${s.slice(0, 119)}…`);

/** Removes quoted history: everything from the first line starting with '>' or "On … wrote:". */
export function stripQuoted(text: string): string {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  const cut = lines.findIndex((l) => /^\s*>/.test(l) || /^\s*On .+wrote:\s*$/i.test(l));
  return (cut === -1 ? lines : lines.slice(0, cut)).join('\n').trim();
}

export function signInbound(raw: Buffer | string, secret: string): string {
  return createHmac('sha256', secret).update(raw).digest('hex');
}

/** Constant-time HMAC check of `X-Saarthee-Signature` (hex sha256). */
export function signatureOk(raw: Buffer | undefined, header: string | undefined): boolean {
  const secret = config.MAIL_INBOUND_SECRET;
  if (!secret || !raw || !header || !/^[0-9a-f]{64}$/i.test(header)) return false;
  const want = Buffer.from(signInbound(raw, secret), 'hex');
  const got = Buffer.from(header.toLowerCase(), 'hex');
  return want.length === got.length && timingSafeEqual(want, got);
}

/** Inbound email → reply. Unknown or already-replied tokens are ignored without detail. */
export async function handleInbound(to: string, text: string): Promise<'recorded' | 'ignored'> {
  const token = /reply\+([0-9a-f]{32})@/i.exec(to)?.[1]?.toLowerCase();
  if (!token) return 'ignored';
  const m = await prisma.repMessage.findUnique({ where: { replyToken: token }, select: { id: true, repliedAt: true } });
  if (!m || m.repliedAt) return 'ignored';
  const body = stripQuoted(text);
  if (!body) return 'ignored';
  await recordReply(m.id, body, 'email');
  return 'recorded';
}

export async function citizenMessages(userId: string) {
  const rows = await prisma.repMessage.findMany({
    where: { citizenId: userId }, orderBy: { createdAt: 'desc' }, take: 100,
    select: { id: true, subject: true, status: true, createdAt: true, sentAt: true, repliedAt: true, replyBody: true, replyChannel: true, representative: { select: { id: true, nameEn: true, nameGu: true, role: true } } },
  });
  return {
    items: rows.map((r) => ({
      id: r.id, representative: r.representative, subject: r.subject, status: r.status, sentAt: (r.sentAt ?? r.createdAt).toISOString(),
      repliedAt: r.repliedAt?.toISOString() ?? null, replyChannel: r.replyChannel, reply: r.replyBody,
    })),
  };
}
