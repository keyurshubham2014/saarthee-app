/**
 * App settings (feature flags) API (TASK-10 §5.2/§5.3, REQ-D-011). Keys are an allow-list with a Zod schema
 * each; a missing row means the default. `election_mode` is delegated to TASK-09's handler.
 */
import { Router } from 'express';
import { z } from 'zod';
import { auditStaff } from '../../lib/audit';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { validate } from '../../middleware/validate';
import { ELECTION_MODE_DEFAULT, ELECTION_MODE_KEY, electionModeSchema, setElectionMode } from '../settings/electionMode';
import { admins, moderators } from './common';

export const settingsRouter = Router();

export const APP_SETTING_KEYS = {
  election_mode: { schema: electionModeSchema, default: ELECTION_MODE_DEFAULT as unknown },
  relay_enabled: { schema: z.boolean(), default: true as unknown },
  alerts_feed_drafts_enabled: { schema: z.boolean(), default: false as unknown },
  scorecard_public: { schema: z.boolean(), default: true as unknown },
  moderation_sensitive_review: { schema: z.boolean(), default: true as unknown },
} as const;

export type AppSettingKey = keyof typeof APP_SETTING_KEYS;
const isKey = (k: string): k is AppSettingKey => Object.hasOwn(APP_SETTING_KEYS, k);

/** Reads one setting (default when missing or invalid). */
export async function getAppSetting<T = unknown>(key: AppSettingKey): Promise<T> {
  const row = await prisma.appSetting.findUnique({ where: { key } });
  const parsed = row ? APP_SETTING_KEYS[key].schema.safeParse(row.value) : undefined;
  return (parsed?.success ? parsed.data : APP_SETTING_KEYS[key].default) as T;
}

settingsRouter.get('/staff/settings', ...moderators, async (_req, res) => {
  const rows = await prisma.appSetting.findMany();
  const byKey = new Map(rows.map((r) => [r.key, r]));
  res.json({
    items: (Object.keys(APP_SETTING_KEYS) as AppSettingKey[]).map((key) => {
      const row = byKey.get(key);
      const parsed = row ? APP_SETTING_KEYS[key].schema.safeParse(row.value) : undefined;
      return { key, value: parsed?.success ? parsed.data : APP_SETTING_KEYS[key].default, updatedAt: row?.updatedAt ?? null, isDefault: !parsed?.success };
    }),
  });
});

const keyParams = z.object({ key: z.string().max(64) });
const valueBody = z.strictObject({ value: z.unknown() });

settingsRouter.put('/staff/settings/:key', ...admins, validate({ params: keyParams, body: valueBody }), async (req, res) => {
  const { key } = res.locals.params as z.infer<typeof keyParams>;
  if (!isKey(key)) throw new AppError('SETTING_UNKNOWN');
  const parsed = APP_SETTING_KEYS[key].schema.safeParse((req.body as { value: unknown }).value);
  if (!parsed.success) {
    throw new AppError('VALIDATION_FAILED', {
      details: parsed.error.issues.map((i) => ({ field: ['value', ...i.path].join('.'), issue: i.message })),
    });
  }
  const actorId = req.staff!.actorId;
  let value: unknown = parsed.data;
  if (key === ELECTION_MODE_KEY) {
    value = await setElectionMode(parsed.data as z.infer<typeof electionModeSchema>, actorId);
  } else {
    await prisma.appSetting.upsert({
      where: { key },
      create: { key, value: parsed.data as boolean, updatedBy: actorId },
      update: { value: parsed.data as boolean, updatedBy: actorId, updatedAt: new Date() },
    });
  }
  auditStaff(req, 'setting_changed', { targetType: 'setting', targetId: key, extra: typeof value === 'boolean' ? { value } : undefined });
  const row = await prisma.appSetting.findUnique({ where: { key } });
  res.json({ key, value, updatedAt: row?.updatedAt ?? null });
});
