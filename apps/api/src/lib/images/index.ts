import { createHash } from 'node:crypto';
import sharp, { type OutputInfo } from 'sharp';
import { config } from '../../config';
import { AppError } from '../errors';

export interface CleanJpeg {
  bytes: Buffer;
  width: number;
  height: number;
  sha256: string;
}

// Decompression-bomb guard: refuse images above ~50 megapixels before decoding.
const MAX_INPUT_PIXELS = 50_000_000;

/** JPEG magic bytes (FF D8 FF). File names and declared content types are ignored (03 §8.2). */
export function looksLikeJpeg(buf: Buffer): boolean {
  return buf.length > 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff;
}

/**
 * Photo pipeline (03 §8.2): type check from content → decode → apply EXIF orientation →
 * downscale to PHOTO_MAX_EDGE_PX → re-encode as JPEG with **no metadata** (sharp drops EXIF/XMP/ICC/GPS
 * unless keepMetadata/withMetadata is called, which we never do) → SHA-256 of the stored bytes.
 */
export async function cleanJpeg(input: Buffer): Promise<CleanJpeg> {
  if (!looksLikeJpeg(input)) throw new AppError('PHOTO_TYPE_UNSUPPORTED');
  let out: { data: Buffer; info: OutputInfo };
  try {
    const meta = await sharp(input, { limitInputPixels: MAX_INPUT_PIXELS }).metadata();
    if (meta.format !== 'jpeg') throw new AppError('PHOTO_TYPE_UNSUPPORTED');
    out = await sharp(input, { limitInputPixels: MAX_INPUT_PIXELS, failOn: 'error' })
      .rotate()
      .resize({
        width: config.PHOTO_MAX_EDGE_PX,
        height: config.PHOTO_MAX_EDGE_PX,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .jpeg({ quality: 85 })
      .toBuffer({ resolveWithObject: true });
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw new AppError('PHOTO_TYPE_UNSUPPORTED');
  }
  return {
    bytes: out.data,
    width: out.info.width,
    height: out.info.height,
    sha256: createHash('sha256').update(out.data).digest('hex'),
  };
}
