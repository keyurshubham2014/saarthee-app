import { createHash } from 'node:crypto';

/** Fixed namespace for Saarthee reference rows (wards, zones). Never change: ids would change everywhere. */
const NAMESPACE = 'b1f2a3c4-5d6e-4f70-8a91-0b2c3d4e5f60';

/**
 * RFC 9562 UUIDv5 (SHA-1, name-based) of `name` in the Saarthee namespace — the same id in every environment,
 * so ward/zone ids are stable across resets, the app fixture and caches.
 */
export function stableUuid(name: string): string {
  const ns = Buffer.from(NAMESPACE.replace(/-/g, ''), 'hex');
  const h = createHash('sha1').update(ns).update(name, 'utf8').digest();
  h[6] = (h[6]! & 0x0f) | 0x50; // version 5
  h[8] = (h[8]! & 0x3f) | 0x80; // RFC variant
  const x = h.subarray(0, 16).toString('hex');
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20, 32)}`;
}
