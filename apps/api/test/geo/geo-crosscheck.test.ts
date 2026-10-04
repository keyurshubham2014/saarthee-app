// T-02-02 (AC-2): geo:crosscheck — passes on consistent data; a missing alias fails naming the ward; overlapping
// polygons fail; wrong total area fails; gaps are warnings only. Real committed data passes too.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { crosscheck, formatCrosscheck } from '../../src/lib/geo/crosscheck';
import { importWards } from '../../src/lib/geo/import';
import { loadGeoSources } from '../../src/lib/geo/ward-data';
import { resetDb } from '../helpers/db';
import { FIXTURE_COUNTS, fixtureSources, importFixtureWards, importRealWards } from './helpers';

beforeEach(resetDb);

// The fixture covers ~3 km², so the city-size bounds are relaxed for it.
const fixtureOpts = { minAreaKm2: 1, maxAreaKm2: 10 };

describe('geo:crosscheck', () => {
  it('passes on consistent fixture data', async () => {
    await importFixtureWards();
    const r = await crosscheck(prisma, fixtureSources(), fixtureOpts);
    expect(r.errors).toEqual([]);
    expect(r.ok).toBe(true);
    expect(r.stats).toMatchObject({ features: 3, amcWards: 3, zones: 2, dbWards: 3, gaps: 0 });
    expect(formatCrosscheck(r, 'fixture-v1')).toContain('Result: **PASS**');
  });

  it('removing an alias fails and names the unmatched KML ward and the AMC ward without polygon', async () => {
    await importFixtureWards();
    const src = fixtureSources();
    src.aliases = {};
    const r = await crosscheck(prisma, src, fixtureOpts);
    expect(r.ok).toBe(false);
    expect(r.errors).toEqual(
      expect.arrayContaining([
        expect.stringContaining('KML ward "Gama Nagar"'),
        expect.stringContaining('AMC ward 3 Gamma Nagar has no polygon'),
      ]),
    );
  });

  it('fails when two wards overlap by more than 1,000 m²', async () => {
    const src = fixtureSources();
    // Ward 2 extends 0.002° (~200 m) into ward 1 → ~0.2 km² overlap.
    src.geojson.features[1]!.geometry.coordinates = [[[[72.508, 23.0], [72.52, 23.0], [72.52, 23.01], [72.508, 23.01], [72.508, 23.0]]]];
    await importWards(prisma, src, FIXTURE_COUNTS);
    const r = await crosscheck(prisma, src, fixtureOpts);
    expect(r.ok).toBe(false);
    expect(r.errors.some((e) => /Wards 1 and 2 overlap by \d+ m²/.test(e))).toBe(true);
  });

  it('fails when the total area is outside the bounds (city defaults 400–550 km²)', async () => {
    await importFixtureWards();
    const r = await crosscheck(prisma, fixtureSources());
    expect(r.errors.some((e) => e.startsWith('Total ward area'))).toBe(true);
  });

  it('reports a gap between wards as a warning, not an error', async () => {
    const src = fixtureSources();
    // Ring of three wards around an empty middle: make ward 2 a frame around an unassigned hole.
    src.geojson.features[1]!.geometry.coordinates = [
      [
        [[72.51, 23.0], [72.52, 23.0], [72.52, 23.01], [72.51, 23.01], [72.51, 23.0]],
        [[72.513, 23.003], [72.513, 23.007], [72.517, 23.007], [72.517, 23.003], [72.513, 23.003]],
      ],
    ];
    await importWards(prisma, src, FIXTURE_COUNTS);
    const r = await crosscheck(prisma, src, fixtureOpts);
    expect(r.errors).toEqual([]);
    expect(r.warnings).toHaveLength(1);
    expect(r.warnings[0]).toMatch(/^Gap of \d+ m²/);
  });

  it('passes on the committed OpenCity/AMC data (48 wards, 7 zones)', async () => {
    await importRealWards();
    const r = await crosscheck(prisma, loadGeoSources());
    expect(r.errors).toEqual([]);
    expect(r.stats).toMatchObject({ features: 48, amcWards: 48, zones: 7, dbWards: 48 });
    expect(r.stats.totalAreaKm2).toBeGreaterThan(400);
    expect(r.stats.totalAreaKm2).toBeLessThan(550);
  }, 60_000);
});
