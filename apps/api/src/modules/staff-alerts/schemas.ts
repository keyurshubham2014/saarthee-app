import { z } from 'zod';
import { config } from '../../config';
import { now } from '../../lib/clock';
import { ALERT_TYPES } from '../alerts/subscriptions.service';

export const SEVERITIES = ['info', 'advisory', 'warning', 'critical'] as const;
const HOUR_MS = 3_600_000;
const DAY_MS = 86_400_000;

const target = z.discriminatedUnion('scope', [
  z.strictObject({ scope: z.literal('wards'), wardIds: z.array(z.uuid()).min(1).max(48) }),
  z.strictObject({ scope: z.literal('zone'), zoneId: z.uuid() }),
  z.strictObject({ scope: z.literal('city') }),
]);

/** Field rules shared by POST (all required) and PATCH (partial). Gujarati may be empty until submit. */
const fields = {
  type: z.enum(ALERT_TYPES),
  severity: z.enum(SEVERITIES),
  titleEn: z.string().trim().min(5).max(80),
  titleGu: z.string().trim().max(80),
  bodyEn: z.string().trim().min(10).max(500),
  bodyGu: z.string().trim().max(500),
  sourceName: z.string().trim().min(2).max(80),
  sourceUrl: z
    .string()
    .trim()
    .max(500)
    .regex(/^https:\/\/[^\s]+$/, { message: 'Use a secure link starting with https://' }),
  validFrom: z.coerce.date(),
  validTo: z.coerce.date(),
  target,
};

export type WindowIssue = { field: 'validFrom' | 'validTo'; issue: string };

/** Validity window rules (§5.3): validTo > now, validTo > validFrom, span ≤ max days, validFrom ≥ now − 1 h. */
export function windowIssues(validFrom: Date, validTo: Date, at: Date = now(), checkFrom = true): WindowIssue[] {
  const out: WindowIssue[] = [];
  if (validTo <= at) out.push({ field: 'validTo', issue: 'Must be in the future.' });
  if (validTo <= validFrom) out.push({ field: 'validTo', issue: 'Must be after the start.' });
  if (validTo.getTime() - validFrom.getTime() > config.ALERT_MAX_VALIDITY_DAYS * DAY_MS) {
    out.push({ field: 'validTo', issue: `An alert can last at most ${config.ALERT_MAX_VALIDITY_DAYS} days.` });
  }
  if (checkFrom && validFrom.getTime() < at.getTime() - HOUR_MS) out.push({ field: 'validFrom', issue: 'Cannot start more than an hour ago.' });
  return out;
}

export const composerBody = z.strictObject({ ...fields, titleGu: fields.titleGu.default(''), bodyGu: fields.bodyGu.default('') }).superRefine((v, ctx) => {
  for (const i of windowIssues(v.validFrom, v.validTo)) ctx.addIssue({ code: 'custom', path: [i.field], message: i.issue });
});

export const patchBody = z.strictObject(fields).partial();

export const retractBody = z.strictObject({ reason: z.string().trim().min(5).max(200) });

export const listQuery = z.object({
  status: z.enum(['draft', 'pending_approval', 'published', 'expired', 'retracted', 'ended']).optional(),
  origin: z.enum(['manual', 'sachet', 'imd']).optional(),
  cursor: z.string().max(400).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

export type ComposerInput = z.infer<typeof composerBody>;
export type PatchInput = z.infer<typeof patchBody>;
export type TargetInput = z.infer<typeof target>;
