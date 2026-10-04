/**
 * npm run geo:convert [-- --version <boundaryVersion>] [--in <kml>] [--out-dir <dir>]
 * KML → normalised GeoJSON (V2 TASK-02 §6 step 2): MultiPolygon per ward, Z dropped, 6 dp, WGS84.
 * Writes prisma/data/geo/amc-wards.<version>.geojson and prints the feature count.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { kmlToWardFeatures } from '../../src/lib/geo/kml';
import { DEFAULT_BOUNDARY_VERSION, GEO_DATA_DIR, argValue } from './common';

function main() {
  const version = argValue('--version') ?? DEFAULT_BOUNDARY_VERSION;
  const input = argValue('--in') ?? path.join(GEO_DATA_DIR, 'raw', 'amc-wards.kml');
  const outDir = argValue('--out-dir') ?? GEO_DATA_DIR;
  const fc = kmlToWardFeatures(readFileSync(input, 'utf8'), version);
  const out = path.join(outDir, `amc-wards.${version}.geojson`);
  // One feature per line keeps diffs reviewable when a new boundary version lands.
  const body = fc.features.map((f) => JSON.stringify(f)).join(',\n');
  writeFileSync(out, `{"type":"FeatureCollection","name":${JSON.stringify(fc.name)},"features":[\n${body}\n]}\n`);
  console.log(`geo:convert features=${fc.features.length} out=${path.relative(process.cwd(), out)}`);
}

try {
  main();
} catch (err) {
  console.error('geo:convert failed:', err instanceof Error ? err.message : err);
  process.exitCode = 1;
}
