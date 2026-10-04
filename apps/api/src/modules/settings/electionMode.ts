/**
 * Election mode (TASK-09 §5.2/§5.3, REQ-F-047). Stored in app_settings under `election_mode`.
 * Active for a ward ⇔ enabled && from ≤ now < to && (scope = 'city' || wardId ∈ wardIds).
 * Cached for 60 s; the staff PUT invalidates the cache. `assertNotElectionFrozen` guards representative-authored
 * writes (TASK-11 applies it to comments, status notes and replies).
 */
import type { RequestHandler, Request } from 'express';
import { z } from 'zod';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

export const ELECTION_MODE_KEY = 'election_mode';
const MAX_WINDOW_MS = 120 * 24 * 60 * 60 * 1000;

export const electionModeSchema = z
  .strictObject({
    enabled: z.boolean(),
    scope: z.enum(['city', 'wards']),
    wardIds: z.array(z.uuid()).max(48).default([]),
    from: z.iso.datetime({ offset: true }),
    to: z.iso.datetime({ offset: true }),
    note_en: z.string().max(200).default(''),
    note_gu: z.string().max(200).default(''),
  })
  .superRefine((v, ctx) => {
    const from = Date.parse(v.from);
    const to = Date.parse(v.to);
    if (!(to > from)) ctx.addIssue({ code: 'custom', path: ['to'], message: 'must be after from' });
    else if (to - from > MAX_WINDOW_MS) ctx.addIssue({ code: 'custom', path: ['to'], message: 'must be within 120 days of from' });
    if (v.scope === 'wards' && v.wardIds.length === 0) ctx.addIssue({ code: 'custom', path: ['wardIds'], message: 'choose at least one ward' });
  });

export type ElectionMode = z.infer<typeof electionModeSchema>;

export const ELECTION_MODE_DEFAULT: ElectionMode = {
  enabled: false,
  scope: 'city',
  wardIds: [],
  from: '1970-01-01T00:00:00.000Z',
  to: '1970-01-02T00:00:00.000Z',
  note_en: '',
  note_gu: '',
};

const TTL_MS = 60_000;
let cache: { value: ElectionMode; at: number } | undefined;

export function invalidateElectionModeCache(): void {
  cache = undefined;
}

export async function getElectionMode(): Promise<ElectionMode> {
  if (cache && Date.now() - cache.at < TTL_MS) return cache.value;
  const row = await prisma.appSetting.findUnique({ where: { key: ELECTION_MODE_KEY } });
  const parsed = row ? electionModeSchema.safeParse(row.value) : undefined;
  const value = parsed?.success ? parsed.data : ELECTION_MODE_DEFAULT;
  cache = { value, at: Date.now() };
  return value;
}

export async function setElectionMode(value: ElectionMode, updatedBy: string): Promise<ElectionMode> {
  await prisma.appSetting.upsert({
    where: { key: ELECTION_MODE_KEY },
    create: { key: ELECTION_MODE_KEY, value, updatedBy },
    update: { value, updatedBy, updatedAt: new Date() },
  });
  invalidateElectionModeCache();
  return value;
}

function inWindow(m: ElectionMode, now: Date): boolean {
  return m.enabled && Date.parse(m.from) <= now.getTime() && now.getTime() < Date.parse(m.to);
}

/** Public summary for one ward (or city-wide when wardId is omitted). */
export async function electionStatus(wardId?: string, now = new Date()) {
  const m = await getElectionMode();
  const active = inWindow(m, now) && (m.scope === 'city' || (wardId !== undefined && m.wardIds.includes(wardId)));
  return { active, until: active ? m.to : null, noteEn: active ? m.note_en : null, noteGu: active ? m.note_gu : null };
}

export async function isElectionMode(wardId: string, now = new Date()): Promise<boolean> {
  return (await electionStatus(wardId, now)).active;
}

/** `GET /settings/public` view. */
export async function publicElectionMode(now = new Date()) {
  const m = await getElectionMode();
  const active = inWindow(m, now);
  return {
    active,
    scope: active ? m.scope : null,
    wardIds: active && m.scope === 'wards' ? m.wardIds : [],
    until: active ? m.to : null,
    noteEn: active ? m.note_en : null,
    noteGu: active ? m.note_gu : null,
  };
}

/**
 * Rejects representative-role writes of representative-authored content with 409 ELECTION_MODE_FROZEN while
 * election mode is active for the ward the request targets. Staff and citizens pass through.
 */
export function assertNotElectionFrozen(resolveWardId: (req: Request) => Promise<string | null> | string | null): RequestHandler {
  return (req, _res, next) => {
    if (req.user?.role !== 'representative') return next();
    Promise.resolve(resolveWardId(req))
      .then(async (wardId) => {
        const frozen = wardId ? await isElectionMode(wardId) : (await publicElectionMode()).scope === 'city';
        next(frozen ? new AppError('ELECTION_MODE_FROZEN') : undefined);
      })
      .catch(next);
  };
}
