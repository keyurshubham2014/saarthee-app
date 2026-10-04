import type { PrismaClient } from '@prisma/client';

/**
 * Legacy migration (V2 TASK-01 §5.2, Spec §6 / D11): copies every v1 complaint into `issues`.
 * Idempotent (ON CONFLICT (legacy_complaint_id) DO NOTHING), one transaction per batch, set-based SQL.
 * Phones, invite codes and source tags are never copied; imported issues are hidden and have no reporter.
 * Never logs personal data or CCRS numbers (counts only).
 */

/** v1 ccrs_categories.name → v2 categories.slug. */
export const LEGACY_CATEGORY_MAP: Readonly<Record<string, string>> = Object.freeze({
  'Pothole or damaged road': 'roads',
  'Garbage and cleanliness': 'garbage',
  Streetlight: 'streetlight',
  Drainage: 'drainage',
  'Water supply': 'water',
  Other: 'other',
});

export class LegacyMigrationError extends Error {}

export interface LegacyMigrationResult {
  complaints: number;
  imported: number;
  skipped: number;
}

const BATCH_SIZE = 200;

export async function migrateLegacyComplaints(
  prisma: PrismaClient,
  opts: { batchSize?: number } = {},
): Promise<LegacyMigrationResult> {
  const batchSize = opts.batchSize ?? BATCH_SIZE;
  const categoryCount = await prisma.category.count();
  if (categoryCount === 0) throw new LegacyMigrationError('Seed categories first (the categories table is empty).');

  const names = await prisma.$queryRaw<{ name: string }[]>`
    SELECT DISTINCT cc.name FROM complaints c JOIN ccrs_categories cc ON cc.id = c.category_id ORDER BY 1`;
  const unknown = names.map((r) => r.name).filter((n) => !(n in LEGACY_CATEGORY_MAP));
  if (unknown.length > 0) throw new LegacyMigrationError(`Unknown v1 categories: ${unknown.join(', ')}`);
  const neededSlugs = [...new Set(names.map((r) => LEGACY_CATEGORY_MAP[r.name]!))];
  const present = await prisma.category.findMany({ where: { slug: { in: neededSlugs } }, select: { slug: true } });
  const missing = neededSlugs.filter((s) => !present.some((p) => p.slug === s));
  if (missing.length > 0) throw new LegacyMigrationError(`Missing v2 categories: ${missing.join(', ')}`);

  const mapNames = Object.keys(LEGACY_CATEGORY_MAP);
  const mapSlugs = mapNames.map((n) => LEGACY_CATEGORY_MAP[n]!);

  const result: LegacyMigrationResult = { complaints: 0, imported: 0, skipped: 0 };
  let after = '00000000-0000-0000-0000-000000000000';
  for (;;) {
    const batch = await prisma.$queryRaw<{ id: string }[]>`
      SELECT id::text FROM complaints WHERE id > ${after}::uuid ORDER BY id LIMIT ${batchSize}`;
    if (batch.length === 0) break;
    after = batch[batch.length - 1]!.id;
    const ids = batch.map((b) => b.id);
    result.complaints += ids.length;

    const inserted = await prisma.$transaction(
      async (tx) => {
        const rows = await tx.$queryRaw<{ id: string }[]>`
          WITH catmap AS (
            SELECT * FROM unnest(${mapNames}::text[], ${mapSlugs}::text[]) AS m(name, slug)
          ), first_reminder AS (
            SELECT complaint_id, min(sent_at) AS sent_at FROM reminders
            WHERE complaint_id = ANY(${ids}::uuid[]) GROUP BY complaint_id
          )
          INSERT INTO issues (client_submission_id, reporter_id, category_id, title, lat, lng, gps_accuracy_m,
                              status, status_changed_at, sla_due_at, ccrs_number, ccrs_filed_at, visibility,
                              legacy_complaint_id, created_at, updated_at)
          SELECT c.client_submission_id, NULL, cat.id, cat.name_en, c.latitude, c.longitude, c.gps_accuracy_m,
                 (CASE s.status WHEN 'filed' THEN 'reported' WHEN 'reminded' THEN 'sent'
                                WHEN 'verified_fixed' THEN 'verified' ELSE 'reopened' END)::issue_status,
                 GREATEST(c.created_at, fr.sent_at, s.latest_verified_at),
                 c.created_at + make_interval(days => cat.sla_days::int),
                 c.ccrs_number_raw, c.created_at, 'hidden'::issue_visibility,
                 c.id, c.created_at, now()
          FROM complaints c
          JOIN complaint_status_v s ON s.complaint_id = c.id
          JOIN ccrs_categories cc ON cc.id = c.category_id
          JOIN catmap m ON m.name = cc.name
          JOIN categories cat ON cat.slug = m.slug
          LEFT JOIN first_reminder fr ON fr.complaint_id = c.id
          WHERE c.id = ANY(${ids}::uuid[])
          ON CONFLICT (legacy_complaint_id) DO NOTHING
          RETURNING id::text`;
        if (rows.length === 0) return 0;
        const issueIds = rows.map((r) => r.id);

        // Report photo at position 0; verification photos in time order. Privacy: never link a deleted photo or
        // any photo of an anonymized complaint (anonymize deletes them; the import must not resurrect them).
        await tx.$executeRaw`
          INSERT INTO issue_photos (issue_id, photo_id, kind, position)
          SELECT i.id, c.photo_id, 'report', 0
          FROM issues i JOIN complaints c ON c.id = i.legacy_complaint_id JOIN photos p ON p.id = c.photo_id
          WHERE i.id = ANY(${issueIds}::uuid[]) AND c.anonymized_at IS NULL AND p.deleted_at IS NULL`;
        await tx.$executeRaw`
          INSERT INTO issue_photos (issue_id, photo_id, kind, position)
          SELECT i.id, v.photo_id, 'verification',
                 (row_number() OVER (PARTITION BY i.id ORDER BY v.created_at, v.id) - 1)::smallint
          FROM issues i JOIN complaints c ON c.id = i.legacy_complaint_id
          JOIN verifications v ON v.complaint_id = c.id JOIN photos p ON p.id = v.photo_id
          WHERE i.id = ANY(${issueIds}::uuid[]) AND c.anonymized_at IS NULL AND p.deleted_at IS NULL`;

        // Status history: reported at creation → sent at the first reminder → verified/reopened per verification.
        await tx.$executeRaw`
          WITH ev AS (
            SELECT i.id AS issue_id, c.created_at AS at, 0 AS ord, 'reported'::issue_status AS to_status,
                   NULL::uuid AS photo_id, c.id AS tiebreak
            FROM issues i JOIN complaints c ON c.id = i.legacy_complaint_id
            WHERE i.id = ANY(${issueIds}::uuid[])
            UNION ALL
            SELECT i.id, r.sent_at, 1, 'sent'::issue_status, NULL::uuid, r.id
            FROM issues i
            JOIN LATERAL (SELECT id, sent_at FROM reminders WHERE complaint_id = i.legacy_complaint_id
                          ORDER BY sent_at, id LIMIT 1) r ON true
            WHERE i.id = ANY(${issueIds}::uuid[])
            UNION ALL
            SELECT i.id, v.created_at, 2,
                   (CASE v.result WHEN 'fixed' THEN 'verified' ELSE 'reopened' END)::issue_status,
                   (CASE WHEN c.anonymized_at IS NULL AND p.deleted_at IS NULL THEN v.photo_id END), v.id
            FROM issues i JOIN complaints c ON c.id = i.legacy_complaint_id
            JOIN verifications v ON v.complaint_id = c.id JOIN photos p ON p.id = v.photo_id
            WHERE i.id = ANY(${issueIds}::uuid[])
          ), ordered AS (
            SELECT ev.*, lag(to_status) OVER (PARTITION BY issue_id ORDER BY at, ord, tiebreak) AS from_status
            FROM ev
          )
          INSERT INTO issue_events (issue_id, actor_id, actor_role, type, from_status, to_status, photo_id, created_at)
          SELECT issue_id, NULL, 'system', 'status_change', from_status, to_status, photo_id, at FROM ordered`;
        return rows.length;
      },
      { timeout: 60_000 },
    );
    result.imported += inserted;
    result.skipped += ids.length - inserted;
  }
  return result;
}

export const formatLegacyResult = (r: LegacyMigrationResult) =>
  `complaints=${r.complaints} imported=${r.imported} skipped=${r.skipped}`;
