/**
 * Cross-check (V2 TASK-02 §5.2 "Cross-check"): source matching (KML ↔ AMC list ↔ aliases) plus geometry checks on
 * the imported `wards`. Errors fail the run (exit 1); gaps between wards are warnings only.
 */
import type { PrismaClient } from '@prisma/client';
import { locatePoint } from './locate';
import { matchFeatures, type GeoSources } from './ward-data';

export interface CrosscheckOptions {
  minAreaKm2?: number;
  maxAreaKm2?: number;
  maxOverlapM2?: number;
  gapWarnM2?: number;
  maxNearestM?: number;
}
export interface CrosscheckReport {
  ok: boolean;
  errors: string[];
  warnings: string[];
  stats: { features: number; amcWards: number; zones: number; dbWards: number; totalAreaKm2: number; gaps: number };
}

export async function crosscheck(prisma: PrismaClient, src: GeoSources, opts: CrosscheckOptions = {}): Promise<CrosscheckReport> {
  const { minAreaKm2 = 400, maxAreaKm2 = 550, maxOverlapM2 = 1_000, gapWarnM2 = 10_000, maxNearestM = 3_000 } = opts;
  const { matched, problems } = matchFeatures(src);
  const errors = [...problems];
  const warnings: string[] = [];

  const db = await prisma.$queryRaw<{ number: number; valid: boolean; multi: boolean; version: string }[]>`
    SELECT number, ST_IsValid(geom) AS valid, ST_GeometryType(geom) = 'ST_MultiPolygon' AND NOT ST_IsEmpty(geom) AS multi,
           boundary_version AS version
    FROM wards ORDER BY number`;
  const dbNumbers = new Set(db.map((r) => Number(r.number)));
  for (const m of matched) {
    if (!dbNumbers.has(m.ward.number)) errors.push(`Ward ${m.ward.number} ${m.ward.nameEn} is not imported (run geo:import)`);
  }
  for (const r of db) {
    if (!matched.some((m) => m.ward.number === Number(r.number))) errors.push(`Imported ward ${r.number} is not in the sources`);
    if (!r.valid || !r.multi) errors.push(`Ward ${r.number}: polygon invalid or empty after ST_MakeValid`);
    if (r.version !== src.version) errors.push(`Ward ${r.number}: boundary_version ${r.version} ≠ ${src.version}`);
  }

  const overlaps = await prisma.$queryRaw<{ a: number; b: number; m2: number }[]>`
    SELECT a.number AS a, b.number AS b, ST_Area(ST_Intersection(a.geom, b.geom)::geography) AS m2
    FROM wards a JOIN wards b ON a.number < b.number AND ST_Intersects(a.geom, b.geom)`;
  for (const o of overlaps) {
    if (Number(o.m2) > maxOverlapM2) errors.push(`Wards ${o.a} and ${o.b} overlap by ${Math.round(Number(o.m2))} m²`);
  }

  const [area] = await prisma.$queryRaw<{ km2: number | null }[]>`
    SELECT sum(ST_Area(geom::geography)) / 1e6 AS km2 FROM wards`;
  const totalAreaKm2 = Math.round(Number(area?.km2 ?? 0) * 10) / 10;
  if (totalAreaKm2 < minAreaKm2 || totalAreaKm2 > maxAreaKm2) {
    errors.push(`Total ward area ${totalAreaKm2} km² is outside ${minAreaKm2}–${maxAreaKm2} km²`);
  }

  const centroids = await prisma.$queryRaw<{ number: number; lat: number; lng: number }[]>`
    SELECT number, ST_Y(centroid) AS lat, ST_X(centroid) AS lng FROM wards ORDER BY number`;
  for (const c of centroids) {
    const hit = await locatePoint(prisma, Number(c.lat), Number(c.lng), maxNearestM);
    if (!hit || hit.ward.number !== Number(c.number) || hit.match !== 'inside') {
      errors.push(`Ward ${c.number}: its point on surface resolves to ${hit ? `ward ${hit.ward.number} (${hit.match})` : 'no ward'}`);
    }
  }

  const gaps = await prisma.$queryRaw<{ m2: number; lat: number; lng: number }[]>`
    WITH u AS (SELECT (ST_Dump(ST_Union(geom))).geom AS g FROM wards),
    holes AS (SELECT ST_MakePolygon(ST_InteriorRingN(g, n)) AS h FROM u, generate_series(1, ST_NumInteriorRings(g)) n)
    SELECT ST_Area(h::geography) AS m2, ST_Y(ST_PointOnSurface(h)) AS lat, ST_X(ST_PointOnSurface(h)) AS lng
    FROM holes WHERE ST_Area(h::geography) > ${gapWarnM2} ORDER BY 1 DESC`;
  for (const g of gaps) {
    warnings.push(`Gap of ${Math.round(Number(g.m2))} m² between wards near ${Number(g.lat).toFixed(4)}, ${Number(g.lng).toFixed(4)}`);
  }

  return {
    ok: errors.length === 0,
    errors,
    warnings,
    stats: {
      features: src.geojson.features.length,
      amcWards: src.list.wards.length,
      zones: src.list.zones.length,
      dbWards: db.length,
      totalAreaKm2,
      gaps: gaps.length,
    },
  };
}

export function formatCrosscheck(r: CrosscheckReport, version: string): string {
  const s = r.stats;
  return [
    `# Ward cross-check — ${version}`,
    '',
    `Result: **${r.ok ? 'PASS' : 'FAIL'}**`,
    '',
    `| Check | Value |`,
    `|---|---|`,
    `| KML features | ${s.features} |`,
    `| AMC wards / zones | ${s.amcWards} / ${s.zones} |`,
    `| Imported wards | ${s.dbWards} |`,
    `| Total ward area | ${s.totalAreaKm2} km² (bounds 400–550) |`,
    `| Gaps > 10,000 m² (warning) | ${s.gaps} |`,
    '',
    `## Errors (${r.errors.length})`,
    ...(r.errors.length ? r.errors.map((e) => `- ${e}`) : ['- none']),
    '',
    `## Warnings (${r.warnings.length})`,
    ...(r.warnings.length ? r.warnings.map((w) => `- ${w}`) : ['- none']),
    '',
  ].join('\n');
}
