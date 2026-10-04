/** Geo test helpers (V2 TASK-02): load the 3-ward fixture or the committed real data into the test database. */
import path from 'node:path';
import { prisma } from '../../src/lib/db';
import { importWards } from '../../src/lib/geo/import';
import { DEFAULT_BOUNDARY_VERSION, loadGeoSources, type GeoSources } from '../../src/lib/geo/ward-data';

export const FIXTURE_DIR = path.resolve(__dirname, '../fixtures/geo');
export const FIXTURE_VERSION = 'fixture-v1';
export const FIXTURE_COUNTS = { expectedWards: 3, expectedZones: 2 };

export const fixtureSources = (): GeoSources => loadGeoSources(FIXTURE_VERSION, FIXTURE_DIR);

export async function importFixtureWards(src: GeoSources = fixtureSources()) {
  return importWards(prisma, src, FIXTURE_COUNTS);
}

/** The committed OpenCity/AMC data (48 wards, 7 zones); no network. */
export async function importRealWards() {
  return importWards(prisma, loadGeoSources(DEFAULT_BOUNDARY_VERSION));
}

/** (lat, lng) of a ward's stored point-on-surface. */
export async function wardPoint(number: number): Promise<{ lat: number; lng: number }> {
  const [r] = await prisma.$queryRaw<{ lat: number; lng: number }[]>`
    SELECT ST_Y(centroid) AS lat, ST_X(centroid) AS lng FROM wards WHERE number = ${number}`;
  if (!r) throw new Error(`ward ${number} not imported`);
  return { lat: Number(r.lat), lng: Number(r.lng) };
}
