import type { Logger } from 'pino';
import { now as clockNow } from '../../../lib/clock';
import { prisma } from '../../../lib/db';
import type { AlertSource, DraftInput } from './sachet';

export interface IngestResult {
  created: number;
  skipped: number;
  failed: number;
  drafts: { originRef: string; severity: string; type: string; wardCount: number; scope: 'wards' | 'city' }[];
}

/** Ward ids whose geometry intersects any of the polygons. */
async function intersectingWards(polygons: string[]): Promise<string[]> {
  if (polygons.length === 0) return [];
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    SELECT w.id FROM wards w
    WHERE EXISTS (SELECT 1 FROM unnest(${polygons}::text[]) AS p(wkt) WHERE ST_Intersects(w.geom, ST_GeomFromText(p.wkt, 4326)))
    ORDER BY w.number`;
  return rows.map((r) => r.id);
}

/**
 * Feed drafts (§5.3, REQ-F-041): keeps Ahmedabad items (areaDesc or polygon ∩ wards), skips Cancel messages,
 * expired items and identifiers already stored, and creates **drafts only** — never submit/approve/publish.
 */
export async function ingestSource(source: AlertSource, opts: { dryRun: boolean; logger: Logger; at?: Date }): Promise<IngestResult> {
  const at = opts.at ?? clockNow();
  const { drafts, failed } = await source.fetchDrafts();
  const result: IngestResult = { created: 0, skipped: 0, failed, drafts: [] };
  for (const d of drafts) {
    const reason = await skipReason(d, at);
    if (reason) {
      result.skipped++;
      opts.logger.info({ source: source.name, originRef: d.originRef, reason }, 'feed item skipped');
      continue;
    }
    const wardIds = await intersectingWards(d.polygons);
    if (!d.areaMatched && wardIds.length === 0) {
      result.skipped++;
      continue;
    }
    const scope = wardIds.length > 0 ? 'wards' : 'city';
    result.drafts.push({ originRef: d.originRef, severity: d.severity, type: d.type, wardCount: wardIds.length, scope });
    if (opts.dryRun) continue;
    if (await createDraft(d, scope, wardIds)) result.created++;
    else result.skipped++;
  }
  opts.logger.info({ source: source.name, created: result.created, skipped: result.skipped, failed: result.failed, dryRun: opts.dryRun }, 'feed ingest');
  return result;
}

async function skipReason(d: DraftInput, at: Date): Promise<string | null> {
  if (d.msgType.toLowerCase() === 'cancel') return 'cancel';
  if (d.validTo <= at) return 'expired';
  const seen = await prisma.alert.findUnique({ where: { origin_originRef: { origin: d.origin, originRef: d.originRef } }, select: { id: true } });
  return seen ? 'duplicate' : null;
}

async function createDraft(d: DraftInput, scope: 'wards' | 'city', wardIds: string[]): Promise<boolean> {
  return prisma.$transaction(async (tx) => {
    const area = d.polygons.length > 0 ? d.polygons : null;
    const rows = await tx.$queryRaw<{ id: string }[]>`
      INSERT INTO alerts (type, severity, title_en, title_gu, body_en, body_gu, source_name, source_url, valid_from, valid_to,
                          target_scope, area, status, origin, origin_ref)
      VALUES (${d.type}::alert_type, ${d.severity}::alert_severity, ${d.titleEn}, ${d.titleGu}, ${d.bodyEn}, ${d.bodyGu},
              ${d.sourceName}, ${d.sourceUrl}, ${d.validFrom}, ${d.validTo}, ${scope}::alert_scope,
              CASE WHEN ${area}::text[] IS NULL THEN NULL
                   ELSE (SELECT ST_Multi(ST_CollectionExtract(ST_Union(ST_GeomFromText(p, 4326)), 3)) FROM unnest(${area}::text[]) AS p) END,
              'draft', ${d.origin}::alert_origin, ${d.originRef})
      ON CONFLICT (origin, origin_ref) DO NOTHING
      RETURNING id`;
    const id = rows[0]?.id;
    if (!id) return false;
    const targets = scope === 'wards' ? wardIds : (await tx.ward.findMany({ select: { id: true } })).map((w) => w.id);
    await tx.alertWard.createMany({ data: targets.map((wardId) => ({ alertId: id, wardId })) });
    return true;
  });
}
