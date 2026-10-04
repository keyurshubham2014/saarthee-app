/**
 * Minimal KML → GeoJSON conversion for ward boundary files (V2 TASK-02 §6 step 2).
 * Supports Placemark > (MultiGeometry >) Polygon with outer and inner rings and ExtendedData SimpleData.
 * Output: MultiPolygon per placemark, Z dropped, coordinates rounded to 6 dp (WGS84).
 * No dependency: the OpenCity file is plain, machine-written KML.
 */

export type Position = [number, number];
export type MultiPolygonCoords = Position[][][];

export interface WardFeature {
  type: 'Feature';
  properties: { kmlName: string; wardNumber: number | null; lgdCode: string | null };
  geometry: { type: 'MultiPolygon'; coordinates: MultiPolygonCoords };
}

export interface WardFeatureCollection {
  type: 'FeatureCollection';
  name: string;
  features: WardFeature[];
}

const round6 = (n: number) => Math.round(n * 1e6) / 1e6;

function decodeXml(s: string): string {
  return s
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&')
    .trim();
}

function parseRing(text: string): Position[] {
  const ring: Position[] = [];
  for (const tuple of text.trim().split(/\s+/)) {
    if (!tuple) continue;
    const [lng, lat] = tuple.split(',').map(Number);
    if (!Number.isFinite(lng) || !Number.isFinite(lat)) throw new Error(`Bad coordinate tuple: ${tuple}`);
    const p: Position = [round6(lng!), round6(lat!)];
    const last = ring[ring.length - 1];
    if (!last || last[0] !== p[0] || last[1] !== p[1]) ring.push(p); // drop duplicates created by rounding
  }
  const first = ring[0];
  const last = ring[ring.length - 1];
  if (first && last && (first[0] !== last[0] || first[1] !== last[1])) ring.push([first[0], first[1]]);
  if (ring.length < 4) throw new Error('Ring has fewer than 4 positions');
  return ring;
}

function rings(xml: string, boundary: 'outerBoundaryIs' | 'innerBoundaryIs'): Position[][] {
  const re = new RegExp(`<${boundary}>[\\s\\S]*?<coordinates>([\\s\\S]*?)</coordinates>[\\s\\S]*?</${boundary}>`, 'g');
  return [...xml.matchAll(re)].map((m) => parseRing(m[1]!));
}

/** Parses a KML document into one MultiPolygon feature per Placemark. */
export function kmlToWardFeatures(kml: string, name = 'amc-wards'): WardFeatureCollection {
  const features: WardFeature[] = [];
  for (const pm of kml.matchAll(/<Placemark[\s\S]*?<\/Placemark>/g)) {
    const xml = pm[0];
    const data: Record<string, string> = {};
    for (const m of xml.matchAll(/<SimpleData name="([^"]+)">([\s\S]*?)<\/SimpleData>/g)) data[m[1]!] = decodeXml(m[2]!);
    const plainName = /<name>([\s\S]*?)<\/name>/.exec(xml)?.[1];
    const kmlName = data.sourcewardname ?? (plainName ? decodeXml(plainName) : '');
    const polygons: MultiPolygonCoords = [];
    for (const poly of xml.matchAll(/<Polygon>[\s\S]*?<\/Polygon>/g)) {
      const outer = rings(poly[0], 'outerBoundaryIs');
      if (outer.length !== 1) throw new Error(`Placemark "${kmlName}": polygon without exactly one outer ring`);
      polygons.push([outer[0]!, ...rings(poly[0], 'innerBoundaryIs')]);
    }
    if (polygons.length === 0) throw new Error(`Placemark "${kmlName}" has no polygon`);
    const code = Number(data.sourcewardcode);
    features.push({
      type: 'Feature',
      properties: { kmlName, wardNumber: Number.isInteger(code) && code > 0 ? code : null, lgdCode: data.ward_lgd_code ?? null },
      geometry: { type: 'MultiPolygon', coordinates: polygons },
    });
  }
  features.sort((a, b) => (a.properties.wardNumber ?? 999) - (b.properties.wardNumber ?? 999));
  return { type: 'FeatureCollection', name, features };
}
