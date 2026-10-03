import { AppError } from '../errors';

export interface Cursor {
  /** Sort key as ISO timestamp. */
  k: string;
  /** Record id (tie-breaker). */
  id: string;
}

export function encodeCursor(c: Cursor): string {
  return Buffer.from(JSON.stringify([c.k, c.id]), 'utf8').toString('base64url');
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Opaque base64url cursor of (sortKey, id); anything malformed → 400 VALIDATION_FAILED. */
export function decodeCursor(raw: string): Cursor {
  try {
    const parsed: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (Array.isArray(parsed) && parsed.length === 2) {
      const [k, id] = parsed as unknown[];
      if (typeof k === 'string' && typeof id === 'string' && UUID.test(id) && !Number.isNaN(Date.parse(k))) {
        return { k, id };
      }
    }
  } catch {
    // fall through
  }
  throw new AppError('VALIDATION_FAILED', { details: [{ field: 'cursor', issue: 'Invalid cursor.' }] });
}
