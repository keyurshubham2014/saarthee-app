/**
 * Distances for verification (V2 TASK-06 §6 step 2). PostGIS `ST_Distance` on geography is authoritative;
 * `haversineM` (moved from the v1 verify service) is the unit-tested fallback and must agree within 0.5 m
 * at city scale (T-06-15).
 */
import { distanceMetres } from './index';

/** Great-circle distance in metres (haversine, mean Earth radius). */
export function haversineM(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6_371_008.8;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
}

/** Metres from the issue's stored location to (lat, lng); null when the issue does not exist. */
export async function distanceToIssueM(issueId: string, lat: number, lng: number): Promise<number | null> {
  return distanceMetres(issueId, lat, lng);
}
