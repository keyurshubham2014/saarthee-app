/**
 * Geo service (V2 TASK-02 §5.3): locate, ward/zone lists, ward detail. Geometry is read only via $queryRaw.
 */
import { config } from '../../config';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { locatePoint, type LocatedWard, type ZoneRef } from '../../lib/geo/locate';
import { parseWardQuery, toAsciiDigits, wardMatches } from './ward-search';

export type { LocatedWard } from '../../lib/geo/locate';

export interface WardSummary {
  id: string;
  number: number;
  nameEn: string;
  nameGu: string;
  zone: ZoneRef;
}
export interface WardDetail extends WardSummary {
  office: { addressEn: string | null; addressGu: string | null; phone: string | null };
  centroid: { lat: number; lng: number };
  bbox: [number, number, number, number];
  boundaryVersion: string;
  source: { name: 'AMC ward list'; url: string; lastVerifiedAt: string };
  geometry?: unknown;
}

/** For TASK-05 (POST /issues) and others: ward + zone for a point, or null when outside the service area. */
export function resolveWard(lat: number, lng: number): Promise<LocatedWard | null> {
  return locatePoint(prisma, lat, lng, config.GEO_NEAREST_MAX_M);
}

/** GET /geo/locate: 422 OUTSIDE_SERVICE_AREA when no ward can be assigned. */
export async function locate(lat: number, lng: number): Promise<LocatedWard> {
  const hit = await resolveWard(lat, lng);
  if (!hit) throw new AppError('OUTSIDE_SERVICE_AREA');
  return hit;
}

/** Cache validator for the list/detail endpoints: W/"<boundaryVersion>-<max(updated_at) of wards and zones>". */
export async function geoEtag(): Promise<string> {
  const [r] = await prisma.$queryRaw<{ version: string | null; ts: Date | null }[]>`
    SELECT (SELECT max(boundary_version) FROM wards) AS version,
           GREATEST((SELECT max(updated_at) FROM wards), (SELECT max(updated_at) FROM zones)) AS ts`;
  return `W/"${r?.version ?? 'none'}-${r?.ts ? r.ts.getTime() : 0}"`;
}

const wardSelect = {
  id: true,
  number: true,
  nameEn: true,
  nameGu: true,
  zone: { select: { id: true, code: true, nameEn: true, nameGu: true } },
} as const;

export async function listWards(q?: string, zone?: string): Promise<{ items: WardSummary[]; boundaryVersion: string | null }> {
  const rows = await prisma.ward.findMany({
    where: zone ? { zone: { code: zone } } : undefined,
    select: { ...wardSelect, boundaryVersion: true, zone: { select: { ...wardSelect.zone.select, sortOrder: true } } },
    orderBy: [{ zone: { sortOrder: 'asc' } }, { number: 'asc' }],
  });
  const query = parseWardQuery(q);
  const items = rows
    .filter((w) => wardMatches(w, query))
    .map(({ zone: { sortOrder: _s, ...z }, boundaryVersion: _v, ...w }) => ({ ...w, zone: z }));
  return { items, boundaryVersion: rows[0]?.boundaryVersion ?? null };
}

export async function listZones() {
  const zones = await prisma.zone.findMany({
    select: { id: true, code: true, nameEn: true, nameGu: true, _count: { select: { wards: true } } },
    orderBy: { sortOrder: 'asc' },
  });
  return { items: zones.map(({ _count, ...z }) => ({ ...z, wardCount: _count.wards })) };
}

interface DetailRow {
  lat: number;
  lng: number;
  xmin: number;
  ymin: number;
  xmax: number;
  ymax: number;
  geometry: string | null;
}

export async function getWard(idOrNumber: string, includeGeometry: boolean): Promise<WardDetail> {
  const isNumber = /^[0-9૦-૯]+$/.test(idOrNumber);
  const number = isNumber ? Number(toAsciiDigits(idOrNumber)) : null;
  if (number !== null && (number < 1 || number > 99)) throw new AppError('NOT_FOUND');
  const w = await prisma.ward.findUnique({
    where: number !== null ? { number } : { id: idOrNumber.toLowerCase() },
    select: {
      ...wardSelect,
      boundaryVersion: true,
      officeAddressEn: true,
      officeAddressGu: true,
      officePhone: true,
      sourceUrl: true,
      lastVerifiedAt: true,
    },
  });
  if (!w) throw new AppError('NOT_FOUND');
  const [g] = await prisma.$queryRaw<DetailRow[]>`
    SELECT ST_Y(centroid) AS lat, ST_X(centroid) AS lng,
           ST_XMin(geom) AS xmin, ST_YMin(geom) AS ymin, ST_XMax(geom) AS xmax, ST_YMax(geom) AS ymax,
           CASE WHEN ${includeGeometry} THEN ST_AsGeoJSON(ST_Multi(ST_SimplifyPreserveTopology(geom, 0.00005)), 6) END AS geometry
    FROM wards WHERE id = ${w.id}::uuid`;
  const r6 = (n: number) => Math.round(Number(n) * 1e6) / 1e6;
  const detail: WardDetail = {
    id: w.id,
    number: w.number,
    nameEn: w.nameEn,
    nameGu: w.nameGu,
    zone: w.zone,
    office: { addressEn: w.officeAddressEn, addressGu: w.officeAddressGu, phone: w.officePhone },
    centroid: { lat: r6(g!.lat), lng: r6(g!.lng) },
    bbox: [r6(g!.xmin), r6(g!.ymin), r6(g!.xmax), r6(g!.ymax)],
    boundaryVersion: w.boundaryVersion,
    source: { name: 'AMC ward list', url: w.sourceUrl, lastVerifiedAt: w.lastVerifiedAt.toISOString() },
  };
  if (includeGeometry && g!.geometry) detail.geometry = JSON.parse(g!.geometry);
  return detail;
}
