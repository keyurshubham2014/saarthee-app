import { createHash, randomUUID } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';

/** Writes a small generated placeholder JPEG at photos/<yyyy>/<mm>/<uuid>.jpg (03 §8 layout). */
export async function makePlaceholderJpeg(rootDir: string, hue: number, reuse?: Buffer) {
  const now = new Date();
  const key = `photos/${now.getUTCFullYear()}/${String(now.getUTCMonth() + 1).padStart(2, '0')}/${randomUUID()}.jpg`;
  const buf =
    reuse ??
    (await sharp({
      create: { width: 640, height: 480, channels: 3, background: { r: (hue * 37) % 256, g: (hue * 83) % 256, b: 120 } },
    })
      .jpeg({ quality: 70 })
      .toBuffer());
  const full = path.join(rootDir, key);
  await mkdir(path.dirname(full), { recursive: true });
  await writeFile(full, buf);
  return {
    key,
    buf,
    byteSize: buf.length,
    width: 640,
    height: 480,
    sha256: createHash('sha256').update(buf).digest('hex'),
  };
}
