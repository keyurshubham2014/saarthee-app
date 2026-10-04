/**
 * Ward source data (V2 TASK-02 §5.2): the converted GeoJSON, AMC's ward list and the alias file, and the
 * matching of KML features to AMC wards shared by geo:import, geo:crosscheck and the `wards` seed module.
 */
import { readFileSync } from 'node:fs';
import path from 'node:path';
import type { WardFeature, WardFeatureCollection } from './kml';

export const GEO_DATA_DIR = path.resolve(__dirname, '../../../prisma/data/geo');
export const DEFAULT_BOUNDARY_VERSION = 'opencity-amc-wards-2025-11';
export const EXPECTED_WARDS = 48;
export const EXPECTED_ZONES = 7;

export interface AmcZone {
  code: string;
  nameEn: string;
  nameGu: string;
}
export interface AmcWard {
  number: number;
  nameEn: string;
  nameGu: string;
  amcListName: string;
  zoneCode: string;
  officeAddressEn: string | null;
  officeAddressGu: string | null;
  officePhone: string | null;
  sourceUrl: string;
}
export interface AmcWardList {
  fetchedAt: string;
  sourceUrl: string;
  zones: AmcZone[];
  wards: AmcWard[];
}
export type WardAliases = Record<string, number>;

export interface GeoSources {
  version: string;
  geojson: WardFeatureCollection;
  list: AmcWardList;
  aliases: WardAliases;
}

/** Loads the committed source files (or a fixture directory with the same layout). */
export function loadGeoSources(version = DEFAULT_BOUNDARY_VERSION, dir = GEO_DATA_DIR): GeoSources {
  const read = <T>(file: string) => JSON.parse(readFileSync(path.join(dir, file), 'utf8')) as T;
  return {
    version,
    geojson: read<WardFeatureCollection>(`amc-wards.${version}.geojson`),
    list: read<AmcWardList>('amc-ward-list.json'),
    aliases: read<WardAliases>('ward-aliases.json'),
  };
}

/** Normalises a ward name for matching: case, spaces, punctuation and a trailing/leading "ward". */
export function normaliseWardName(name: string): string {
  return name
    .toLowerCase()
    .normalize('NFKC')
    .replace(/\bward\b/g, '')
    .replace(/[^\p{L}\p{N}]+/gu, '');
}

export interface MatchedWard {
  ward: AmcWard;
  feature: WardFeature;
}
export interface MatchResult {
  matched: MatchedWard[];
  problems: string[];
}

/**
 * Matches every KML feature to exactly one AMC ward: by normalised AMC list name or English name, else by
 * `ward-aliases.json`. Reports unmatched features, AMC wards without a polygon, two features on one ward, and
 * features whose KML ward code disagrees with the matched AMC ward number.
 */
export function matchFeatures(src: Pick<GeoSources, 'geojson' | 'list' | 'aliases'>): MatchResult {
  const problems: string[] = [];
  const byName = new Map<string, AmcWard>();
  for (const w of src.list.wards) {
    byName.set(normaliseWardName(w.amcListName), w);
    byName.set(normaliseWardName(w.nameEn), w);
  }
  const byNumber = new Map(src.list.wards.map((w) => [w.number, w]));
  const aliases = new Map(Object.entries(src.aliases).map(([k, v]) => [normaliseWardName(k), v]));
  const used = new Map<number, string>();
  const matched: MatchedWard[] = [];
  for (const f of src.geojson.features) {
    const key = normaliseWardName(f.properties.kmlName);
    const aliased = aliases.get(key);
    const ward = byName.get(key) ?? (aliased !== undefined ? byNumber.get(aliased) : undefined);
    if (!ward) {
      problems.push(`KML ward "${f.properties.kmlName}" (code ${f.properties.wardNumber ?? '?'}) matches no AMC ward`);
      continue;
    }
    if (f.properties.wardNumber !== null && f.properties.wardNumber !== ward.number) {
      problems.push(`KML ward "${f.properties.kmlName}" has code ${f.properties.wardNumber} but matches AMC ward ${ward.number} ${ward.nameEn}`);
    }
    const prev = used.get(ward.number);
    if (prev) {
      problems.push(`KML wards "${prev}" and "${f.properties.kmlName}" both match AMC ward ${ward.number} ${ward.nameEn}`);
      continue;
    }
    used.set(ward.number, f.properties.kmlName);
    matched.push({ ward, feature: f });
  }
  for (const w of src.list.wards) {
    if (!used.has(w.number)) problems.push(`AMC ward ${w.number} ${w.nameEn} has no polygon`);
  }
  const zoneCodes = new Set(src.list.zones.map((z) => z.code));
  for (const w of src.list.wards) {
    if (!zoneCodes.has(w.zoneCode)) problems.push(`AMC ward ${w.number} ${w.nameEn} has unknown zone "${w.zoneCode}"`);
  }
  matched.sort((a, b) => a.ward.number - b.ward.number);
  return { matched, problems };
}
