import type { Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import type { ClientMeta } from '../../middleware/clientMeta';

export interface IncomingEvent {
  name: string;
  occurredAt: string;
  properties?: Record<string, unknown>;
}

const REASON = /^[a-z0-9_]{1,40}$/;

/**
 * App-sent event allow-list with a per-event property filter (03 §11). Server-only names
 * (report_submitted, reminder_sent, verify_opened, verify_submitted, record_flagged) are ignored here.
 * Each filter returns only the allowed, well-typed properties; anything else is dropped silently.
 */
const APP_EVENTS: Record<string, (p: Record<string, unknown>) => Prisma.InputJsonObject> = {
  invite_code_entered: (p) => (typeof p.valid === 'boolean' ? { valid: p.valid } : {}),
  report_opened: () => ({}),
  ccrs_handoff_clicked: (p) =>
    p.target === 'web' || p.target === 'whatsapp' || p.target === 'call' ? { target: p.target } : {},
  deep_link_failed: (p) => (typeof p.reason === 'string' && REASON.test(p.reason) ? { reason: p.reason } : {}),
};

/** Stores the allow-listed events; returns how many were actually stored. */
export async function ingestEvents(events: IncomingEvent[], meta: ClientMeta): Promise<number> {
  const rows: Prisma.EventCreateManyInput[] = [];
  for (const e of events) {
    const filter = Object.hasOwn(APP_EVENTS, e.name) ? APP_EVENTS[e.name] : undefined;
    if (!filter) continue;
    rows.push({
      name: e.name,
      installId: meta.installId,
      platform: meta.platform,
      appVersion: meta.appVersion,
      properties: filter(e.properties ?? {}),
      occurredAt: new Date(e.occurredAt),
    });
  }
  if (rows.length === 0) return 0;
  const result = await prisma.event.createMany({ data: rows });
  return result.count;
}
