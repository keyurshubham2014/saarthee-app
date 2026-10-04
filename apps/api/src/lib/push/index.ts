import type { Notification, Prisma } from '@prisma/client';
import { config } from '../../config';
import { prisma } from '../db';
import { logger } from '../logger';
import { DEAD_TOKEN_CODES, LogPushDriver, MemoryPushDriver, type PushChannel, type PushDriver, type SendResult } from './drivers';
import { FcmPushDriver } from './fcm';

export * from './drivers';

/** TASK-04 §5.3 push contract; later tasks (alerts, issue updates, initiatives) call notifyTopic/notifyUser. */
export interface PushMessage {
  kind: 'alert' | 'issue_update' | 'initiative' | 'system';
  refId?: string;
  route?: string;
  title: { en: string; gu: string };
  body: { en: string; gu: string };
  channel: PushChannel;
  sendAfter?: Date;
}

export type NotificationRow = Notification;
type Db = Prisma.TransactionClient | typeof prisma;
type Lang = 'gu' | 'en';

export const BASE_TOPIC = /^[a-z0-9_]{1,60}$/;
export const LANGS: readonly Lang[] = ['gu', 'en'];

let driver: PushDriver | undefined;

/** Driver chosen by PUSH_DRIVER (fcm | log | memory). */
export function pushDriver(): PushDriver {
  driver ??= config.PUSH_DRIVER === 'fcm' ? new FcmPushDriver() : config.PUSH_DRIVER === 'memory' ? new MemoryPushDriver() : new LogPushDriver();
  return driver;
}

/** Tests only. */
export function setPushDriver(next: PushDriver | undefined): void {
  driver = next;
}

function payloadFor(row: Notification, lang: Lang) {
  return {
    title: lang === 'gu' ? row.titleGu : row.titleEn,
    body: lang === 'gu' ? row.bodyGu : row.bodyEn,
    channel: row.channel as PushChannel,
    data: { kind: row.kind, refId: row.refId ?? '', route: row.route ?? '', notificationId: row.id },
  };
}

function rowData(msg: PushMessage, now: Date) {
  if (msg.title.en.length > 120 || msg.title.gu.length > 120 || msg.body.en.length > 400 || msg.body.gu.length > 400) {
    throw new Error('push message too long (title ≤ 120, body ≤ 400)');
  }
  return {
    kind: msg.kind,
    refId: msg.refId ?? null,
    route: msg.route ?? null,
    channel: msg.channel,
    titleEn: msg.title.en,
    titleGu: msg.title.gu,
    bodyEn: msg.body.en,
    bodyGu: msg.body.gu,
    sendAfter: msg.sendAfter ?? null,
    status: msg.sendAfter && msg.sendAfter > now ? 'queued' : 'sent',
  };
}

/** Sends one stored row and records the outcome. Never logs title, body or tokens. */
async function deliver(db: Db, row: Notification): Promise<Notification> {
  let results: SendResult[] = [];
  let noDevice = false;
  if (row.topic) {
    results = await Promise.all(LANGS.map((lang) => pushDriver().sendToTopic(`${row.topic}__${lang}`, payloadFor(row, lang))));
  } else {
    const where = row.deviceId ? { id: row.deviceId } : { userId: row.userId ?? '00000000-0000-0000-0000-000000000000' };
    const devices = await db.device.findMany({ where: { ...where, fcmToken: { not: null } }, select: { id: true, fcmToken: true } });
    const user = row.userId ? await db.user.findUnique({ where: { id: row.userId }, select: { language: true } }) : null;
    const lang: Lang = user?.language ?? 'gu';
    if (devices.length === 0) noDevice = true;
    else {
      results = await pushDriver().sendToTokens(devices.map((d) => d.fcmToken!), payloadFor(row, lang));
      const dead = devices.filter((_, i) => {
        const r = results[i];
        return r && !r.ok && DEAD_TOKEN_CODES.has(r.errorCode);
      });
      if (dead.length > 0) await db.device.updateMany({ where: { id: { in: dead.map((d) => d.id) } }, data: { fcmToken: null } });
    }
  }
  const ok = results.filter((r): r is { ok: true; messageId: string } => r.ok);
  const failed = results.filter((r): r is { ok: false; errorCode: string } => !r.ok);
  const status = noDevice ? 'no_device' : failed.length === 0 ? 'sent' : ok.length === 0 ? 'failed' : 'partial';
  const updated = await db.notification.update({
    where: { id: row.id },
    data: {
      status,
      sentAt: ok.length > 0 ? new Date() : null,
      providerMessageIds: ok.map((r) => r.messageId),
      errorCode: failed[0]?.errorCode ?? null,
    },
  });
  logger.info(
    {
      notificationId: row.id,
      kind: row.kind,
      ...(row.topic ? { topic: row.topic } : { userId: row.userId }),
      status,
      okCount: ok.length,
      failCount: failed.length,
    },
    'push',
  );
  return updated;
}

/** Topic send: one row, delivered to `<base>__gu` (Gujarati text) and `<base>__en` (English text). */
export async function notifyTopic(baseTopic: string, msg: PushMessage): Promise<NotificationRow> {
  if (!BASE_TOPIC.test(baseTopic)) throw new Error('invalid base topic');
  const data = rowData(msg, new Date());
  const row = await prisma.notification.create({ data: { ...data, topic: baseTopic, status: data.status === 'queued' ? 'queued' : 'failed' } });
  return data.status === 'queued' ? row : deliver(prisma, row);
}

/** User send: every device of the user with an FCM token, in the user's language; no token → `no_device`. */
export async function notifyUser(userId: string, msg: PushMessage): Promise<NotificationRow> {
  const data = rowData(msg, new Date());
  const row = await prisma.notification.create({ data: { ...data, userId, status: data.status === 'queued' ? 'queued' : 'failed' } });
  return data.status === 'queued' ? row : deliver(prisma, row);
}

/** Sends queued rows whose send_after has passed, each exactly once (row lock, SKIP LOCKED). Returns the count. */
export async function flushQueued(now: Date = new Date(), batch = 100): Promise<number> {
  return prisma.$transaction(
    async (tx) => {
      const due = await tx.$queryRaw<{ id: string }[]>`
        SELECT id FROM notifications WHERE status = 'queued' AND (send_after IS NULL OR send_after <= ${now})
        ORDER BY send_after NULLS FIRST LIMIT ${batch} FOR UPDATE SKIP LOCKED`;
      for (const { id } of due) {
        const row = await tx.notification.findUniqueOrThrow({ where: { id } });
        await deliver(tx, row);
      }
      return due.length;
    },
    { timeout: 120_000 },
  );
}
