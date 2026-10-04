/**
 * Ward/zone import (V2 TASK-02 §5.2 "Import"): one transaction; upsert zones by code and wards by number
 * (new rows get a stable name-based UUIDv5 from "ward:<number>" / "zone:<code>", so ids are
 * the same in every environment and in the app fixture);
 * zone geometry = union of its wards. Rows change only when a value differs, so re-running the same version
 * leaves `updated_at` untouched. Refuses unless the expected ward/zone counts resolve.
 */
import type { PrismaClient } from '@prisma/client';
import { EXPECTED_WARDS, EXPECTED_ZONES, matchFeatures, type GeoSources } from './ward-data';
import { stableUuid } from './stable-id';

export class GeoImportError extends Error {}

export interface ImportOptions {
  expectedWards?: number;
  expectedZones?: number;
}
export interface ImportResult {
  version: string;
  zones: number;
  wards: number;
  zonesChanged: number;
  wardsChanged: number;
  areaChanges: { number: number; pct: number }[];
}

export async function importWards(prisma: PrismaClient, src: GeoSources, opts: ImportOptions = {}): Promise<ImportResult> {
  const expectedWards = opts.expectedWards ?? EXPECTED_WARDS;
  const expectedZones = opts.expectedZones ?? EXPECTED_ZONES;
  const { matched, problems } = matchFeatures(src);
  if (problems.length) throw new GeoImportError(`Source data does not match:\n- ${problems.join('\n- ')}`);
  if (matched.length !== expectedWards || src.list.zones.length !== expectedZones) {
    throw new GeoImportError(
      `Refusing import: ${matched.length} wards and ${src.list.zones.length} zones resolved (expected ${expectedWards} and ${expectedZones}).`,
    );
  }
  const verifiedAt = new Date(src.list.fetchedAt);

  return prisma.$transaction(
    async (tx) => {
      let zonesChanged = 0;
      for (const [i, z] of src.list.zones.entries()) {
        zonesChanged += await tx.$executeRaw`
          INSERT INTO zones (id, code, name_en, name_gu, sort_order)
          VALUES (${stableUuid(`zone:${z.code}`)}::uuid, ${z.code}, ${z.nameEn}, ${z.nameGu}, ${i})
          ON CONFLICT (code) DO UPDATE SET name_en = EXCLUDED.name_en, name_gu = EXCLUDED.name_gu,
            sort_order = EXCLUDED.sort_order, updated_at = now()
          WHERE (zones.name_en, zones.name_gu, zones.sort_order)
            IS DISTINCT FROM (EXCLUDED.name_en, EXCLUDED.name_gu, EXCLUDED.sort_order)`;
      }

      const before = await tx.$queryRaw<{ number: number; area: number }[]>`
        SELECT number, ST_Area(geom::geography) AS area FROM wards WHERE boundary_version <> ${src.version}`;
      const oldArea = new Map(before.map((r) => [Number(r.number), Number(r.area)]));

      let wardsChanged = 0;
      for (const { ward: w, feature } of matched) {
        const geojson = JSON.stringify(feature.geometry);
        wardsChanged += await tx.$executeRaw`
          WITH g AS (
            SELECT ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_SetSRID(ST_GeomFromGeoJSON(${geojson}), 4326)), 3)) AS geom
          )
          INSERT INTO wards (id, number, name_en, name_gu, zone_id, geom, centroid, boundary_version, office_address_en,
                             office_address_gu, office_phone, source_url, last_verified_at)
          SELECT ${stableUuid(`ward:${w.number}`)}::uuid, ${w.number}, ${w.nameEn}, ${w.nameGu}, (SELECT id FROM zones WHERE code = ${w.zoneCode}),
                 g.geom, ST_PointOnSurface(g.geom), ${src.version}, ${w.officeAddressEn}, ${w.officeAddressGu},
                 ${w.officePhone}, ${w.sourceUrl}, ${verifiedAt}
          FROM g
          ON CONFLICT (number) DO UPDATE SET
            name_en = EXCLUDED.name_en, name_gu = EXCLUDED.name_gu, zone_id = EXCLUDED.zone_id,
            geom = EXCLUDED.geom, centroid = EXCLUDED.centroid, boundary_version = EXCLUDED.boundary_version,
            office_address_en = EXCLUDED.office_address_en, office_address_gu = EXCLUDED.office_address_gu,
            office_phone = EXCLUDED.office_phone, source_url = EXCLUDED.source_url,
            last_verified_at = EXCLUDED.last_verified_at, updated_at = now()
          WHERE (wards.name_en, wards.name_gu, wards.zone_id, wards.boundary_version, wards.office_address_en,
                 wards.office_address_gu, wards.office_phone, wards.source_url, wards.last_verified_at)
                IS DISTINCT FROM
                (EXCLUDED.name_en, EXCLUDED.name_gu, EXCLUDED.zone_id, EXCLUDED.boundary_version,
                 EXCLUDED.office_address_en, EXCLUDED.office_address_gu, EXCLUDED.office_phone,
                 EXCLUDED.source_url, EXCLUDED.last_verified_at)
             OR NOT ST_Equals(wards.geom, EXCLUDED.geom)`;
      }

      zonesChanged += await tx.$executeRaw`
        UPDATE zones z SET geom = u.geom, updated_at = now()
        FROM (SELECT zone_id, ST_Multi(ST_Union(geom)) AS geom FROM wards GROUP BY zone_id) u
        WHERE z.id = u.zone_id AND (z.geom IS NULL OR NOT ST_Equals(z.geom, u.geom))`;

      const after = await tx.$queryRaw<{ number: number; area: number }[]>`
        SELECT number, ST_Area(geom::geography) AS area FROM wards`;
      const areaChanges = after
        .filter((r) => oldArea.has(Number(r.number)))
        .map((r) => {
          const old = oldArea.get(Number(r.number))!;
          return { number: Number(r.number), pct: old ? Math.round(((Number(r.area) - old) / old) * 10_000) / 100 : 0 };
        });
      const [counts] = await tx.$queryRaw<{ zones: bigint; wards: bigint }[]>`
        SELECT (SELECT count(*) FROM zones) AS zones, (SELECT count(*) FROM wards) AS wards`;
      return {
        version: src.version,
        zones: Number(counts!.zones),
        wards: Number(counts!.wards),
        zonesChanged,
        wardsChanged,
        areaChanges,
      };
    },
    { timeout: 120_000 },
  );
}

export const formatImportResult = (r: ImportResult) =>
  `geo:import version=${r.version} zones=${r.zones} wards=${r.wards} zonesChanged=${r.zonesChanged} wardsChanged=${r.wardsChanged}` +
  (r.areaChanges.length ? `\n${r.areaChanges.map((a) => `  ward ${a.number}: area ${a.pct >= 0 ? '+' : ''}${a.pct}%`).join('\n')}` : '');
