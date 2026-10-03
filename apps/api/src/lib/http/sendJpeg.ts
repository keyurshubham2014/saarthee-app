import type { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import type { Response } from 'express';
import { logger } from '../logger';

/** Streams a stored JPEG through the API (03 §8.3: never a public URL). */
export async function sendJpeg(res: Response, stream: Readable): Promise<void> {
  res.setHeader('Content-Type', 'image/jpeg');
  res.setHeader('Cache-Control', 'private, no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  try {
    await pipeline(stream, res);
  } catch (err) {
    logger.warn({ err: err instanceof Error ? err.message : 'stream error' }, 'photo stream interrupted');
    if (!res.headersSent) res.status(500).end();
  }
}
