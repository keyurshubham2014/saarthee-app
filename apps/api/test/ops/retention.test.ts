/** T-13-04…06 (V2 TASK-13 AC-9): retention job rules, dry run, idempotency, audit line, 410 after deletion. */
import { mkdtemp, rm, utimes, writeFile, readdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import type { IssueStatus } from '@prisma/client';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { prisma } from '../../src/lib/db';
import { logger } from '../../src/lib/logger';
import { LocalPhotoStorage, setStorageForTesting, storageFor, type PhotoStorage } from '../../src/lib/storage';
import { openPhoto } from '../../src/modules/photos/read.service';
import { runRetention } from '../../src/modules/retention/retention.service';
import { resetDb } from '../helpers/db';
import { makeCategory, makeCcrsCategory, makeComplaint, makeIssue, makePhoto } from '../helpers/factories';

const DAY = 86_400_000;
const NOW = new Date('2028-06-01T00:00:00Z');
const ago = (days: number) => new Date(NOW.getTime() - days * DAY);
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);

let local: LocalPhotoStorage;
let categoryId: string;

async function issueWithPhoto(status: IssueStatus, daysAgo: number, opts: { legacy?: boolean } = {}) {
  let legacyComplaintId: string | undefined;
  if (opts.legacy) legacyComplaintId = (await makeComplaint({ categoryId: (await makeCcrsCategory(`c${Math.random()}`)).id })).id;
  const mergedIntoId = status === 'merged' ? (await makeIssue({ categoryId })).id : undefined;
  const issue = await makeIssue({ categoryId, status, statusChangedAt: ago(daysAgo), mergedIntoId, legacyComplaintId });
  const key = await local.save(JPEG);
  const photo = await makePhoto({ storageKey: key, storageDriver: 'local' });
  await prisma.issuePhoto.create({ data: { issueId: issue.id, photoId: photo.id, kind: 'report' } });
  return { label: `${status}-${daysAgo}${opts.legacy ? '-legacy' : ''}`, photoId: photo.id, key };
}

async function fixtures() {
  // One category for all issues (makeCategory slugs can collide after ~10 calls in one file).
  categoryId = (await makeCategory()).id;
  return [
    await issueWithPhoto('verified', 731),
    await issueWithPhoto('rejected', 731),
    await issueWithPhoto('merged', 731),
    await issueWithPhoto('marked_fixed', 738),
    await issueWithPhoto('marked_fixed', 735), // still inside 730 + 7-day reopen window
    await issueWithPhoto('verified', 700),
    await issueWithPhoto('reopened', 800),
    await issueWithPhoto('verified', 731, { legacy: true }),
  ];
}
const EXPECTED_DELETED = ['verified-731', 'rejected-731', 'merged-731', 'marked_fixed-738', 'verified-731-legacy'];

async function deletedLabels(items: { label: string; photoId: string }[]) {
  const out: string[] = [];
  for (const i of items) {
    const p = await prisma.photo.findUniqueOrThrow({ where: { id: i.photoId } });
    if (p.deletedAt) out.push(i.label);
  }
  return out.sort();
}

beforeEach(async () => {
  await resetDb();
  local = storageFor('local') as LocalPhotoStorage;
});
afterEach(() => {
  setStorageForTesting('local', undefined);
  vi.restoreAllMocks();
});

describe('retention › photos (T-13-04)', () => {
  it('deletes only photos of issues closed > 730 days (marked_fixed > 737), legacy included', async () => {
    const items = await fixtures();
    const results = await runRetention({ now: NOW, rules: ['photos.closed_issues', 'photos.legacy'] });
    expect(results.map((r) => [r.rule, r.selected, r.done, r.failed])).toEqual([
      ['photos.closed_issues', 4, 4, 0],
      ['photos.legacy', 1, 1, 0],
    ]);
    expect(await deletedLabels(items)).toEqual([...EXPECTED_DELETED].sort());
    for (const i of items) {
      expect(await local.exists(i.key)).toBe(!EXPECTED_DELETED.includes(i.label));
    }
  });

  it('counts storage failures, leaves those rows untouched and reports failed > 0 (exit 1)', async () => {
    const items = await fixtures();
    const failing: PhotoStorage = { ...local, driver: 'local', save: local.save.bind(local), open: local.open.bind(local),
      exists: local.exists.bind(local), delete: () => Promise.reject(new Error('disk gone')) };
    setStorageForTesting('local', failing);
    const [r] = await runRetention({ now: NOW, rules: ['photos.closed_issues'] });
    expect(r).toMatchObject({ selected: 4, done: 0, failed: 4 });
    expect(await deletedLabels(items)).toEqual([]);
  });
});

describe('retention › notifications and logs (T-13-05)', () => {
  let logDir: string;
  beforeEach(async () => {
    logDir = await mkdtemp(path.join(tmpdir(), 'saarthee-logs-'));
    // TASK-04 now creates the real notifications table; these cases use their own minimal one
    // (this file runs in its own database copy, so dropping it here is safe).
    await prisma.$executeRawUnsafe('DROP TABLE IF EXISTS notifications CASCADE');
  });
  afterEach(async () => {
    await rm(logDir, { recursive: true, force: true });
    await prisma.$executeRawUnsafe('DROP TABLE IF EXISTS notifications CASCADE');
  });

  it('skips notifications while the table does not exist', async () => {
    const [r] = await runRetention({ now: NOW, rules: ['notifications'] });
    expect(r).toMatchObject({ selected: 0, done: 0, skipped: 'table_absent' });
  });

  it('deletes only notifications older than 90 days', async () => {
    await prisma.$executeRawUnsafe(
      'CREATE TABLE notifications (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), created_at timestamptz NOT NULL)',
    );
    await prisma.$executeRaw`INSERT INTO notifications (created_at) VALUES (${ago(91)}), (${ago(91)}), (${ago(89)})`;
    const [r] = await runRetention({ now: NOW, rules: ['notifications'] });
    expect(r).toMatchObject({ selected: 2, done: 2, failed: 0 });
    const left = await prisma.$queryRaw<{ n: bigint }[]>`SELECT count(*)::bigint AS n FROM notifications`;
    expect(Number(left[0]?.n)).toBe(1);
  });

  it('removes only log files older than 14 days', async () => {
    for (const [name, days] of [['api.1.log', 15], ['api.2.log', 13]] as const) {
      const f = path.join(logDir, name);
      await writeFile(f, 'x');
      await utimes(f, ago(days), ago(days));
    }
    const [r] = await runRetention({ now: NOW, rules: ['logs.files'], logDir });
    expect(r).toMatchObject({ selected: 1, done: 1, failed: 0 });
    expect(await readdir(logDir)).toEqual(['api.2.log']);
  });
});

describe('retention › dry run, idempotency, audit, 410 (T-13-06)', () => {
  it('dry run changes nothing; real run once; second run selects 0; one audit line per real run', async () => {
    const items = await fixtures();
    const info = vi.spyOn(logger, 'info');
    const dry = await runRetention({ now: NOW, dryRun: true, rules: ['photos.closed_issues', 'photos.legacy'] });
    expect(dry.map((r) => [r.selected, r.done])).toEqual([[4, 0], [1, 0]]);
    expect(await deletedLabels(items)).toEqual([]);
    const audits = () => info.mock.calls.filter((c) => c[1] === 'admin_action');
    expect(audits()).toHaveLength(0);

    await runRetention({ now: NOW, rules: ['photos.closed_issues', 'photos.legacy'] });
    expect(audits()).toHaveLength(1);
    expect(audits()[0]?.[0]).toMatchObject({ action: 'retention_run', actor: 'system', 'photos.closed_issues.done': 4 });
    expect(JSON.stringify(audits()[0]?.[0])).not.toMatch(/photos\/\d{4}/);

    const again = await runRetention({ now: NOW, rules: ['photos.closed_issues', 'photos.legacy'] });
    expect(again.map((r) => r.selected)).toEqual([0, 0]);

    const gone = items.find((i) => i.label === 'verified-731')!;
    await expect(openPhoto(gone.photoId)).rejects.toMatchObject({ code: 'PHOTO_DELETED', status: 410 });
  });
});
