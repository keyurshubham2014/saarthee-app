/**
 * Per-user daily quotas (V2 TASK-05 §5.3, REQ-S-008). Rolling 24 h counts of database rows, so limits survive
 * restarts and multiple API instances. Exported for TASK-06 (verifications) and TASK-09 (messages).
 *
 *   await assertDailyQuota(req.user.id, 'issues', { res });
 *
 * Over the limit → 429 RATE_LIMITED, details [{field:'quota', issue:'<key>_per_day'}], Retry-After = seconds
 * until the oldest counted row is 24 h old.
 */
import type { Response } from 'express';
import { Prisma } from '@prisma/client';
import { config } from '../../config';
import { prisma } from '../db';
import { AppError } from '../errors';

export type QuotaKey = 'issues' | 'me_too' | 'verifications' | 'messages' | 'photos';

const DAY_MS = 86_400_000;

export function quotaLimit(key: QuotaKey): number {
  switch (key) {
    case 'issues': return config.QUOTA_ISSUES_PER_DAY;
    case 'me_too': return config.QUOTA_ME_TOO_PER_DAY;
    case 'verifications': return config.QUOTA_VERIFICATIONS_PER_DAY;
    case 'messages': return config.QUOTA_MESSAGES_PER_REP_PER_DAY;
    case 'photos': return config.QUOTA_PHOTOS_PER_DAY;
  }
}

/** Source table + user column (+ time column) per key; identifiers are constants, never input. */
const SOURCES: Record<QuotaKey, { table: string; user: string; at: string }> = {
  issues: { table: 'issues', user: 'reporter_id', at: 'created_at' },
  me_too: { table: 'me_toos', user: 'user_id', at: 'created_at' },
  verifications: { table: 'issue_verifications', user: 'user_id', at: 'created_at' },
  messages: { table: 'rep_messages', user: 'citizen_id', at: 'created_at' },
  photos: { table: 'photos', user: 'uploaded_by_user_id', at: 'uploaded_at' },
};

export interface QuotaUsage {
  count: number;
  oldest: Date | null;
}

export interface QuotaOptions {
  /** messages: the per-representative limit (`rep_messages.representative_id`). */
  representativeId?: string;
  /** Sets Retry-After on this response when the quota is exceeded. */
  res?: Response;
  now?: Date;
}

async function tableExists(table: string): Promise<boolean> {
  const [r] = await prisma.$queryRaw<{ ok: boolean }[]>`SELECT to_regclass(${'public.' + table}) IS NOT NULL AS ok`;
  return Boolean(r?.ok);
}

/** Rows of `key` for `userId` in the rolling 24 h before `now`. A source table that does not exist yet counts 0. */
export async function quotaUsage(userId: string, key: QuotaKey, opts: QuotaOptions = {}): Promise<QuotaUsage> {
  const src = SOURCES[key];
  if (key === 'messages' && !(await tableExists(src.table))) return { count: 0, oldest: null };
  const since = new Date((opts.now ?? new Date()).getTime() - DAY_MS);
  const rep = key === 'messages' && opts.representativeId
    ? Prisma.sql`AND representative_id = ${opts.representativeId}::uuid`
    : Prisma.empty;
  const [r] = await prisma.$queryRaw<{ n: bigint; oldest: Date | null }[]>`
    SELECT count(*) AS n, min(${Prisma.raw(`"${src.at}"`)}) AS oldest
    FROM ${Prisma.raw(`"${src.table}"`)}
    WHERE ${Prisma.raw(`"${src.user}"`)} = ${userId}::uuid AND ${Prisma.raw(`"${src.at}"`)} > ${since} ${rep}`;
  return { count: Number(r?.n ?? 0), oldest: r?.oldest ?? null };
}

/** Pure decision: seconds to wait (Retry-After) when `count >= limit`, else null. */
export function quotaRetryAfter(usage: QuotaUsage, limit: number, now = new Date()): number | null {
  if (usage.count < limit) return null;
  const freeAt = (usage.oldest?.getTime() ?? now.getTime()) + DAY_MS;
  return Math.max(1, Math.ceil((freeAt - now.getTime()) / 1000));
}

/** Throws 429 RATE_LIMITED when one more `key` action would exceed the user's daily limit. */
export async function assertDailyQuota(userId: string, key: QuotaKey, opts: QuotaOptions = {}): Promise<void> {
  const now = opts.now ?? new Date();
  const usage = await quotaUsage(userId, key, { ...opts, now });
  const retryAfter = quotaRetryAfter(usage, quotaLimit(key), now);
  if (retryAfter === null) return;
  opts.res?.setHeader('Retry-After', String(retryAfter));
  throw new AppError('RATE_LIMITED', {
    message: 'You have reached the daily limit. Please try again later.',
    details: [{ field: 'quota', issue: `${key}_per_day` }],
  });
}
