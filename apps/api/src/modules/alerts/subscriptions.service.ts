import type { AlertType, Prisma } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

export const MAX_EXTRA_WARDS = 5;
export const ALERT_TYPES = ['water_cut', 'water_timing', 'road_closure', 'heat', 'rain_flood', 'health', 'initiative', 'other'] as const;

/** FCM base topic names (D9): `ward_<number>`, `zone_<code>`, `city_all`. */
export const wardTopic = (n: number) => `ward_${n}`;
export const zoneTopic = (code: string) => `zone_${code.toLowerCase().replace(/[^a-z0-9_]/g, '_')}`;

const distinct = <T>(arr: T[]) => new Set(arr).size === arr.length;

export const subscriptionsBody = z.strictObject({
  extraWardIds: z
    .array(z.uuid())
    .max(MAX_EXTRA_WARDS, { message: 'You can add up to 5 extra wards.' })
    .refine(distinct, { message: 'Wards must be different.' }),
  mutedTypes: z.array(z.enum(ALERT_TYPES)).max(ALERT_TYPES.length).refine(distinct, { message: 'Types must be different.' }),
  criticalOnly: z.boolean(),
});

export const deviceSubscriptionsBody = subscriptionsBody.extend({ homeWardId: z.uuid().nullable() });

export type SubscriptionsInput = z.infer<typeof subscriptionsBody>;

type Owner = { userId: string } | { deviceId: string };

const ownerWhere = (o: Owner): Prisma.SubscriptionWhereInput => ('userId' in o ? { userId: o.userId } : { deviceId: o.deviceId });

/** Base topics (without the `__<lang>` suffix) the phone should hold; empty when preferences are custom. */
async function topicsFor(homeWardId: string | null, extraWardIds: string[], custom: boolean): Promise<string[]> {
  if (custom) return [];
  const ids = [...(homeWardId ? [homeWardId] : []), ...extraWardIds];
  const wards = await prisma.ward.findMany({ where: { id: { in: ids } }, select: { number: true, zone: { select: { code: true } } } });
  const topics = new Set<string>();
  for (const w of wards.sort((a, b) => a.number - b.number)) topics.add(wardTopic(w.number));
  for (const w of wards) topics.add(zoneTopic(w.zone.code));
  topics.add('city_all');
  return [...topics];
}

async function read(owner: Owner, homeWardId: string | null) {
  const rows = await prisma.subscription.findMany({ where: ownerWhere(owner), orderBy: { createdAt: 'asc' } });
  const extraWardIds = rows.filter((r) => r.scope === 'ward' && r.scopeId && r.scopeId !== homeWardId).map((r) => r.scopeId!);
  const city = rows.find((r) => r.scope === 'city');
  const mutedTypes = (city?.mutedTypes ?? []) as AlertType[];
  const criticalOnly = city?.criticalOnly ?? false;
  const customPreferences = mutedTypes.length > 0 || criticalOnly;
  return {
    homeWardId,
    extraWardIds,
    mutedTypes,
    criticalOnly,
    customPreferences,
    topics: await topicsFor(homeWardId, extraWardIds, customPreferences),
  };
}

async function write(owner: Owner, homeWardId: string | null, input: SubscriptionsInput): Promise<void> {
  if (homeWardId && input.extraWardIds.includes(homeWardId)) {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'extraWardIds', issue: 'Your home ward is already included.' }] });
  }
  const known = await prisma.ward.count({ where: { id: { in: input.extraWardIds } } });
  if (known !== input.extraWardIds.length) {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'extraWardIds', issue: 'Unknown ward.' }] });
  }
  const base = 'userId' in owner ? { userId: owner.userId } : { deviceId: owner.deviceId };
  await prisma.$transaction([
    prisma.subscription.deleteMany({ where: ownerWhere(owner) }),
    prisma.subscription.createMany({
      data: [
        ...input.extraWardIds.map((wardId) => ({ ...base, scope: 'ward' as const, scopeId: wardId })),
        { ...base, scope: 'city' as const, scopeId: null, mutedTypes: input.mutedTypes, criticalOnly: input.criticalOnly },
      ],
    }),
  ]);
}

export async function getUserSubscriptions(userId: string, homeWardId: string | null) {
  return read({ userId }, homeWardId);
}

export async function putUserSubscriptions(userId: string, homeWardId: string | null, input: SubscriptionsInput) {
  await write({ userId }, homeWardId, input);
  return read({ userId }, homeWardId);
}

async function deviceByInstall(installId: string) {
  const device = await prisma.device.findUnique({ where: { installId }, select: { id: true, homeWardId: true } });
  if (!device) throw new AppError('NOT_FOUND');
  return device;
}

export async function getDeviceSubscriptions(installId: string) {
  const device = await deviceByInstall(installId);
  return read({ deviceId: device.id }, device.homeWardId);
}

export async function putDeviceSubscriptions(installId: string, input: z.infer<typeof deviceSubscriptionsBody>) {
  const device = await deviceByInstall(installId);
  if (input.homeWardId && !(await prisma.ward.findUnique({ where: { id: input.homeWardId }, select: { id: true } }))) {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'homeWardId', issue: 'Unknown ward.' }] });
  }
  await prisma.device.update({ where: { id: device.id }, data: { homeWardId: input.homeWardId } });
  await write({ deviceId: device.id }, input.homeWardId, input);
  return read({ deviceId: device.id }, input.homeWardId);
}
