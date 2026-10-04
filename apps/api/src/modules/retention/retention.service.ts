import { readdir, stat, unlink } from 'node:fs/promises';
import path from 'node:path';
import type { StorageDriver } from '@prisma/client';
import { config } from '../../config';
import { auditLog } from '../../lib/audit';
import { prisma } from '../../lib/db';
import { logger } from '../../lib/logger';
import { storageFor } from '../../lib/storage';
import { cleanupPhotos } from '../photos/cleanup.service';

/** Retention rules (V2 TASK-13 §5.2, Spec §11, REQ-S-014). Order = run order. */
export const RETENTION_RULES = ['photos.closed_issues', 'photos.legacy', 'notifications', 'logs.files', 'photos.unattached'] as const;
export type RetentionRule = (typeof RETENTION_RULES)[number];

export interface RuleResult {
  rule: RetentionRule;
  selected: number;
  done: number;
  failed: number;
  skipped?: string;
}

export interface RetentionOptions {
  dryRun?: boolean;
  rules?: RetentionRule[];
  now?: Date;
  logDir?: string;
}

const DAY_MS = 86_400_000;
const BATCH = 1000;

/**
 * Photos of closed issues: verified/rejected/merged for RETENTION_CLOSED_PHOTO_DAYS since the last status
 * change, or marked_fixed for that plus the reopen window. A reopened issue is not closed, so its clock
 * restarts when it closes again. `legacy` selects imported v1 issues (legacy_complaint_id set).
 */
async function selectClosedIssuePhotos(now: Date, legacy: boolean) {
  const closedBefore = new Date(now.getTime() - config.RETENTION_CLOSED_PHOTO_DAYS * DAY_MS);
  const fixedBefore = new Date(closedBefore.getTime() - config.REOPEN_WINDOW_DAYS * DAY_MS);
  return prisma.$queryRaw<{ id: string; storage_key: string; storage_driver: StorageDriver }[]>`
    SELECT p.id, p.storage_key, p.storage_driver
    FROM photos p
    JOIN issue_photos ip ON ip.photo_id = p.id
    JOIN issues i ON i.id = ip.issue_id
    WHERE p.deleted_at IS NULL
      AND (i.legacy_complaint_id IS NOT NULL) = ${legacy}
      AND (
        (i.status IN ('verified', 'rejected', 'merged') AND i.status_changed_at < ${closedBefore})
        OR (i.status = 'marked_fixed' AND i.status_changed_at < ${fixedBefore})
      )
    ORDER BY p.id`;
}

async function runPhotoRule(rule: RetentionRule, legacy: boolean, o: Required<Pick<RetentionOptions, 'dryRun' | 'now'>>) {
  const rows = await selectClosedIssuePhotos(o.now, legacy);
  const r: RuleResult = { rule, selected: rows.length, done: 0, failed: 0 };
  if (o.dryRun) return r;
  for (const p of rows) {
    try {
      await storageFor(p.storage_driver).delete(p.storage_key);
      await prisma.photo.update({ where: { id: p.id }, data: { deletedAt: o.now } });
      r.done += 1;
    } catch (err) {
      r.failed += 1;
      logger.error({ rule, photoId: p.id, reason: err instanceof Error ? err.name : 'unknown' }, 'retention: photo failed');
    }
  }
  return r;
}

async function runNotifications(o: Required<Pick<RetentionOptions, 'dryRun' | 'now'>>): Promise<RuleResult> {
  const r: RuleResult = { rule: 'notifications', selected: 0, done: 0, failed: 0 };
  const [reg] = await prisma.$queryRaw<{ exists: boolean }[]>`
    SELECT to_regclass('public.notifications') IS NOT NULL AS exists`;
  if (!reg?.exists) {
    logger.info({ rule: r.rule }, 'retention: notifications table not present yet; skipped');
    return { ...r, skipped: 'table_absent' };
  }
  const before = new Date(o.now.getTime() - config.RETENTION_NOTIFICATION_DAYS * DAY_MS);
  const [cnt] = await prisma.$queryRaw<{ n: bigint }[]>`
    SELECT count(*)::bigint AS n FROM notifications WHERE created_at < ${before}`;
  r.selected = Number(cnt?.n ?? 0);
  if (o.dryRun) return r;
  for (;;) {
    const deleted = await prisma.$executeRaw`
      DELETE FROM notifications WHERE ctid IN (
        SELECT ctid FROM notifications WHERE created_at < ${before} LIMIT ${BATCH})`;
    r.done += deleted;
    if (deleted < BATCH) break;
  }
  return r;
}

async function runLogFiles(o: Required<Pick<RetentionOptions, 'dryRun' | 'now'>> & { logDir?: string }) {
  const r: RuleResult = { rule: 'logs.files', selected: 0, done: 0, failed: 0 };
  if (!o.logDir) return { ...r, skipped: 'no_log_dir' };
  const before = o.now.getTime() - config.RETENTION_LOG_DAYS * DAY_MS;
  let names: string[];
  try {
    names = await readdir(o.logDir);
  } catch {
    return { ...r, skipped: 'log_dir_missing' };
  }
  for (const name of names) {
    const full = path.join(o.logDir, name);
    const s = await stat(full).catch(() => undefined);
    if (!s?.isFile() || s.mtimeMs >= before) continue;
    r.selected += 1;
    if (o.dryRun) continue;
    try {
      await unlink(full);
      r.done += 1;
    } catch {
      r.failed += 1;
      logger.error({ rule: r.rule }, 'retention: log file could not be removed');
    }
  }
  return r;
}

async function runUnattached(dryRun: boolean): Promise<RuleResult> {
  if (dryRun) return { rule: 'photos.unattached', selected: 0, done: 0, failed: 0, skipped: 'dry_run' };
  const c = await cleanupPhotos();
  const done = c.orphansDeleted + c.anonymizedFilesDeleted;
  return { rule: 'photos.unattached', selected: done + c.failures, done, failed: c.failures };
}

/** Runs the selected rules; never logs keys, phones or coordinates. One audit line per real run. */
export async function runRetention(opts: RetentionOptions = {}): Promise<RuleResult[]> {
  const o = { dryRun: opts.dryRun ?? false, now: opts.now ?? new Date() };
  const rules = opts.rules ?? [...RETENTION_RULES];
  const results: RuleResult[] = [];
  for (const rule of rules) {
    if (rule === 'photos.closed_issues') results.push(await runPhotoRule(rule, false, o));
    else if (rule === 'photos.legacy') results.push(await runPhotoRule(rule, true, o));
    else if (rule === 'notifications') results.push(await runNotifications(o));
    else if (rule === 'logs.files') results.push(await runLogFiles({ ...o, logDir: opts.logDir ?? config.LOG_FILE_DIR }));
    else results.push(await runUnattached(o.dryRun));
  }
  if (!o.dryRun) {
    const counts: Record<string, number> = {};
    for (const r of results) {
      counts[`${r.rule}.done`] = r.done;
      counts[`${r.rule}.failed`] = r.failed;
    }
    auditLog(null, 'retention_run', null, { actor: 'system', ...counts });
  }
  return results;
}

export function formatResult(r: RuleResult): string {
  return `rule=${r.rule} selected=${r.selected} done=${r.done} failed=${r.failed}${r.skipped ? ` skipped=${r.skipped}` : ''}`;
}

/** CLI flags: `--dry-run`, `--rule <name>` (repeatable). Unknown rule → throws. */
export function parseRetentionArgs(argv: string[]): { dryRun: boolean; rules?: RetentionRule[] } {
  const rules: RetentionRule[] = [];
  argv.forEach((a, i) => {
    if (a !== '--rule') return;
    const name = argv[i + 1];
    if (!name || !(RETENTION_RULES as readonly string[]).includes(name)) {
      throw new Error(`unknown rule; expected one of ${RETENTION_RULES.join(', ')}`);
    }
    rules.push(name as RetentionRule);
  });
  return { dryRun: argv.includes('--dry-run'), rules: rules.length > 0 ? rules : undefined };
}
