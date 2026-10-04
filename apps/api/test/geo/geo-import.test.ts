// T-02-01 (AC-1): geo:import — counts, validity, centroid inside, idempotent re-run, wrong count refused,
// new boundary version updates geometry. Plus the KML converter on a tiny KML.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { GeoImportError, importWards } from '../../src/lib/geo/import';
import { kmlToWardFeatures } from '../../src/lib/geo/kml';
import { resetDb } from '../helpers/db';
import { FIXTURE_COUNTS, fixtureSources, importFixtureWards } from './helpers';

beforeEach(resetDb);

describe('geo:import', () => {
  it('loads wards and zones with valid geometry, centroid inside, version and zone; zone geom = union', async () => {
    const r = await importFixtureWards();
    expect(r).toMatchObject({ version: 'fixture-v1', zones: 2, wards: 3, wardsChanged: 3 });
    const rows = await prisma.$queryRaw<{ number: number; valid: boolean; inside: boolean; v: string; zone: string }[]>`
      SELECT w.number, ST_IsValid(w.geom) AS valid, ST_Covers(w.geom, w.centroid) AS inside,
             w.boundary_version AS v, z.code AS zone
      FROM wards w JOIN zones z ON z.id = w.zone_id ORDER BY w.number`;
    expect(rows).toEqual([
      { number: 1, valid: true, inside: true, v: 'fixture-v1', zone: 'west' },
      { number: 2, valid: true, inside: true, v: 'fixture-v1', zone: 'west' },
      { number: 3, valid: true, inside: true, v: 'fixture-v1', zone: 'east' },
    ]);
    const [z] = await prisma.$queryRaw<{ eq: boolean }[]>`
      SELECT ST_Equals(z.geom, (SELECT ST_Union(geom) FROM wards w WHERE w.zone_id = z.id)) AS eq
      FROM zones z WHERE code = 'west'`;
    expect(z!.eq).toBe(true);
  });

  it('second run with the same version changes no row (updated_at unchanged)', async () => {
    await importFixtureWards();
    const before = await prisma.ward.findMany({ select: { number: true, updatedAt: true }, orderBy: { number: 'asc' } });
    const zBefore = await prisma.zone.findMany({ select: { code: true, updatedAt: true }, orderBy: { code: 'asc' } });
    const r = await importFixtureWards();
    expect(r).toMatchObject({ wardsChanged: 0, zonesChanged: 0 });
    expect(await prisma.ward.findMany({ select: { number: true, updatedAt: true }, orderBy: { number: 'asc' } })).toEqual(before);
    expect(await prisma.zone.findMany({ select: { code: true, updatedAt: true }, orderBy: { code: 'asc' } })).toEqual(zBefore);
  });

  it('refuses (and writes nothing) when the expected counts do not resolve', async () => {
    await expect(importWards(prisma, fixtureSources(), { expectedWards: 48, expectedZones: 7 })).rejects.toThrow(GeoImportError);
    const src = fixtureSources();
    src.aliases = {}; // "Gama Nagar" no longer matches
    await expect(importWards(prisma, src, FIXTURE_COUNTS)).rejects.toThrow(/Gama Nagar/);
    expect(await prisma.ward.count()).toBe(0);
    expect(await prisma.zone.count()).toBe(0);
  });

  it('a new boundary version updates geometry and version and reports the area change', async () => {
    await importFixtureWards();
    const src = fixtureSources();
    src.version = 'fixture-v2';
    // Ward 3 grows east by 50% (72.52–72.535).
    src.geojson.features[2]!.geometry.coordinates = [[[[72.52, 23.0], [72.535, 23.0], [72.535, 23.01], [72.52, 23.01], [72.52, 23.0]]]];
    const r = await importWards(prisma, src, FIXTURE_COUNTS);
    expect(r.wardsChanged).toBe(3);
    expect(r.areaChanges.find((a) => a.number === 3)!.pct).toBeCloseTo(50, 0);
    expect(r.areaChanges.find((a) => a.number === 1)!.pct).toBeCloseTo(0, 1);
    expect(new Set((await prisma.ward.findMany()).map((w) => w.boundaryVersion))).toEqual(new Set(['fixture-v2']));
  });
});

describe('geo:convert (KML → GeoJSON)', () => {
  const kml = `<kml><Document><Placemark>
    <ExtendedData><SchemaData><SimpleData name="sourcewardname">Paldi</SimpleData>
    <SimpleData name="sourcewardcode">30</SimpleData></SchemaData></ExtendedData>
    <MultiGeometry><Polygon><outerBoundaryIs><LinearRing><coordinates>
      72.1234567,23.1234567,0 72.2,23.1 72.2,23.2 72.1234567,23.1234567,0
    </coordinates></LinearRing></outerBoundaryIs>
    <innerBoundaryIs><LinearRing><coordinates>72.15,23.13 72.16,23.13 72.16,23.14 72.15,23.13</coordinates></LinearRing></innerBoundaryIs>
    </Polygon></MultiGeometry></Placemark></Document></kml>`;

  it('makes a MultiPolygon per placemark, drops Z, rounds to 6 dp, keeps name and ward code, keeps holes', () => {
    const fc = kmlToWardFeatures(kml, 'v');
    expect(fc.features).toHaveLength(1);
    const f = fc.features[0]!;
    expect(f.properties).toEqual({ kmlName: 'Paldi', wardNumber: 30, lgdCode: null });
    expect(f.geometry.type).toBe('MultiPolygon');
    expect(f.geometry.coordinates[0]![0]![0]).toEqual([72.123457, 23.123457]);
    expect(f.geometry.coordinates[0]).toHaveLength(2);
  });

  it('rejects a placemark without a polygon', () => {
    expect(() => kmlToWardFeatures('<kml><Placemark><name>x</name></Placemark></kml>')).toThrow(/no polygon/);
  });
});
