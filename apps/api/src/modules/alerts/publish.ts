import type { Alert, Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import { notifyDevices, notifyTopic, withdrawQueued, type PushMessage } from '../../lib/push';
import { holdUntil } from './quietHours';
import { wardTopic, zoneTopic } from './subscriptions.service';

type Tx = Prisma.TransactionClient;

const trim = (s: string, n: number) => (s.length <= n ? s : `${s.slice(0, n - 1)}…`);

/**
 * Inbox fan-out (§5.3 step 2): one set-based insert of an inbox row for every active user whose home ward
 * or extra-ward subscription is in alert_wards (city alerts list every ward). Written regardless of mute
 * settings; the partial unique index makes a second publish of the same alert insert nothing.
 */
export async function fanOutInbox(tx: Tx, alert: Alert, at: Date): Promise<number> {
  const channel = alert.severity === 'critical' ? 'critical_alerts' : 'alerts';
  return tx.$executeRaw`
    INSERT INTO notifications (user_id, kind, ref_id, route, channel, title_en, title_gu, body_en, body_gu, status, sent_at, created_at)
    SELECT u.id, 'alert', ${alert.id}, ${`/alerts/${alert.id}`}, ${channel},
           left(${alert.titleEn}, 120), left(${alert.titleGu}, 120), left(${alert.bodyEn}, 400), left(${alert.bodyGu}, 400),
           'sent', ${at}, ${at}
    FROM users u
    WHERE u.status = 'active' AND (
      u.home_ward_id IN (SELECT ward_id FROM alert_wards WHERE alert_id = ${alert.id}::uuid)
      OR EXISTS (
        SELECT 1 FROM subscriptions s
        WHERE s.user_id = u.id AND s.scope = 'ward'
          AND s.scope_id IN (SELECT ward_id FROM alert_wards WHERE alert_id = ${alert.id}::uuid)))
    ON CONFLICT DO NOTHING`;
}

/** Base topics for the alert's target (D9). */
export async function alertTopics(alert: Alert): Promise<string[]> {
  if (alert.targetScope === 'city') return ['city_all'];
  if (alert.targetScope === 'zone') {
    const zone = await prisma.zone.findUniqueOrThrow({ where: { id: alert.targetZoneId! }, select: { code: true } });
    return [zoneTopic(zone.code)];
  }
  const wards = await prisma.alertWard.findMany({ where: { alertId: alert.id }, select: { ward: { select: { number: true } } } });
  return wards.map((w) => w.ward.number).sort((a, b) => a - b).map(wardTopic);
}

/**
 * Devices with custom preferences (left the alert topics) whose area matches and whose preferences allow
 * this alert: type not muted and (not critical-only or severity critical) — §5.3 step 5.
 */
export async function filteredDeviceIds(alert: Alert): Promise<string[]> {
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    WITH aw AS (SELECT ward_id FROM alert_wards WHERE alert_id = ${alert.id}::uuid),
    prefs AS (
      SELECT d.id, d.user_id, COALESCE(u.home_ward_id, d.home_ward_id) AS home, s.muted_types, s.critical_only
      FROM devices d
      LEFT JOIN users u ON u.id = d.user_id
      JOIN subscriptions s ON s.scope = 'city'
        AND ((d.user_id IS NOT NULL AND s.user_id = d.user_id) OR (d.user_id IS NULL AND s.device_id = d.id))
      WHERE d.fcm_token IS NOT NULL
        AND (d.user_id IS NULL OR u.status = 'active')
        AND (cardinality(s.muted_types) > 0 OR s.critical_only))
    SELECT p.id FROM prefs p
    WHERE NOT (${alert.type}::alert_type = ANY (p.muted_types))
      AND (NOT p.critical_only OR ${alert.severity}::alert_severity = 'critical')
      AND (p.home IN (SELECT ward_id FROM aw)
        OR EXISTS (
          SELECT 1 FROM subscriptions x
          WHERE x.scope = 'ward' AND x.scope_id IN (SELECT ward_id FROM aw)
            AND ((p.user_id IS NOT NULL AND x.user_id = p.user_id) OR (p.user_id IS NULL AND x.device_id = p.id))))`;
  return rows.map((r) => r.id);
}

function message(alert: Alert, cancel: { reasonEn: string; reasonGu: string } | null, sendAfter: Date | undefined): PushMessage {
  return {
    kind: 'alert',
    refId: alert.id,
    route: `/alerts/${alert.id}`,
    channel: alert.severity === 'critical' ? 'critical_alerts' : 'alerts',
    title: cancel
      ? { en: trim(`Cancelled: ${alert.titleEn}`, 120), gu: trim(`રદ: ${alert.titleGu || alert.titleEn}`, 120) }
      : { en: alert.titleEn, gu: alert.titleGu },
    body: cancel
      ? { en: trim(cancel.reasonEn, 150), gu: trim(cancel.reasonGu, 150) }
      : { en: trim(alert.bodyEn, 150), gu: trim(alert.bodyGu, 150) },
    sendAfter,
  };
}

export interface Delivery {
  held: boolean;
  sendAfter?: string;
  topics: string[];
  deviceCount: number;
}

/** Topic sends + filtered device sends after commit (§5.3 steps 3–5). Quiet hours hold non-critical sends. */
export async function pushAlert(alert: Alert, at: Date, cancel: { reasonEn: string; reasonGu: string } | null = null): Promise<Delivery> {
  const sendAfter = holdUntil(at, alert.severity);
  const msg = message(alert, cancel, sendAfter);
  const topics = await alertTopics(alert);
  for (const t of topics) await notifyTopic(t, msg);
  const devices = await filteredDeviceIds(alert);
  if (devices.length > 0) await notifyDevices(devices, msg);
  if (!cancel) await prisma.alert.update({ where: { id: alert.id }, data: { pushedAt: at } });
  return { held: !!sendAfter, ...(sendAfter ? { sendAfter: sendAfter.toISOString() } : {}), topics, deviceCount: devices.length };
}

/**
 * Retraction (§5.3 step 6): withdraws held sends; if anything had already gone out, the same audiences get
 * "Cancelled: <title>" with the reason. Returns whether a cancel push was sent.
 */
export async function pushRetraction(alert: Alert, at: Date, reason: string): Promise<boolean> {
  await withdrawQueued('alert', alert.id);
  const delivered = await prisma.notification.count({
    where: { kind: 'alert', refId: alert.id, userId: null, status: { in: ['sent', 'partial'] } },
  });
  if (delivered === 0) return false;
  await pushAlert(alert, at, { reasonEn: reason, reasonGu: reason });
  return true;
}
