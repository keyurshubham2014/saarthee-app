import type { Prisma, Platform, SourceTag } from '@prisma/client';
import { prisma } from '../db';
import { logger } from '../logger';

/** Server-recorded event names (03 §11). App-sent names are handled by modules/events. */
export type ServerEventName = 'report_submitted' | 'reminder_sent' | 'verify_opened' | 'verify_submitted' | 'record_flagged';

export interface ServerEvent {
  name: ServerEventName;
  complaintId?: string | null;
  adminUserId?: string | null;
  installId?: string | null;
  sourceTag?: SourceTag | null;
  platform?: Platform | null;
  appVersion?: string | null;
  /** Only non-personal values (03 §11): never phone, token, invite code, coordinates or notes. */
  properties?: Prisma.InputJsonObject;
}

type Tx = Prisma.TransactionClient;

/** Records a server-side analytics event. Failures are logged and never break the caller's request. */
export async function recordServerEvent(event: ServerEvent, tx: Tx = prisma): Promise<void> {
  try {
    await tx.event.create({
      data: {
        name: event.name,
        complaintId: event.complaintId ?? null,
        adminUserId: event.adminUserId ?? null,
        installId: event.installId ?? null,
        sourceTag: event.sourceTag ?? null,
        platform: event.platform ?? null,
        appVersion: event.appVersion ?? null,
        properties: event.properties ?? {},
        occurredAt: new Date(),
      },
    });
  } catch (err) {
    logger.error({ event: event.name, err }, 'failed to record server event');
  }
}
