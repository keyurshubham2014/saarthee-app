/**
 * T-13-01 (V2 TASK-13 AC-1): one contract suite for every PhotoStorage driver.
 * Local always runs. R2 runs against MinIO when R2_TEST_ENDPOINT is set (CI starts `minio/minio`;
 * locally: `docker run -d -p 9010:9000 minio/minio server /data` and R2_TEST_ENDPOINT=http://127.0.0.1:9010).
 */
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { CreateBucketCommand, S3Client } from '@aws-sdk/client-s3';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LocalPhotoStorage, R2PhotoStorage, StorageKeyError, StorageNotFoundError, type PhotoStorage } from '../../src/lib/storage';
import { r2ClientConfig, type R2Options } from '../../src/lib/storage/r2';

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 0xff, 0xd9]);

async function readAll(s: PhotoStorage, key: string): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const c of await s.open(key)) chunks.push(Buffer.from(c as Buffer));
  return Buffer.concat(chunks);
}

function contract(name: string, make: () => Promise<PhotoStorage>) {
  describe(`PhotoStorage contract › ${name}`, () => {
    let s: PhotoStorage;
    beforeAll(async () => {
      s = await make();
    });

    it('saves under photos/<yyyy>/<mm>/<uuid>.jpg and reads back the same bytes', async () => {
      const key = await s.save(JPEG);
      expect(key).toMatch(/^photos\/\d{4}\/\d{2}\/[0-9a-f-]{36}\.jpg$/);
      expect(await s.exists(key)).toBe(true);
      expect((await readAll(s, key)).equals(JPEG)).toBe(true);
    });

    it('exists is false after delete, and deleting a missing key succeeds', async () => {
      const key = await s.save(JPEG);
      await s.delete(key);
      expect(await s.exists(key)).toBe(false);
      await expect(s.delete(key)).resolves.toBeUndefined();
    });

    it('opening a missing key throws StorageNotFoundError', async () => {
      await expect(s.open('photos/2026/01/00000000-0000-4000-8000-000000000000.jpg')).rejects.toBeInstanceOf(
        StorageNotFoundError,
      );
    });

    it('refuses traversal and malformed keys', async () => {
      for (const k of ['../x.jpg', 'photos/../../x.jpg', '/etc/passwd', 'photos/2026/10/../../../../x.jpg']) {
        await expect(s.exists(k)).rejects.toBeInstanceOf(StorageKeyError);
        await expect(s.open(k)).rejects.toBeInstanceOf(StorageKeyError);
        await expect(s.delete(k)).rejects.toBeInstanceOf(StorageKeyError);
      }
    });
  });
}

let tmp: string | undefined;
contract('local', async () => {
  tmp = await mkdtemp(path.join(tmpdir(), 'saarthee-storage-'));
  return new LocalPhotoStorage(tmp);
});
afterAll(async () => {
  if (tmp) await rm(tmp, { recursive: true, force: true });
});

const endpoint = process.env.R2_TEST_ENDPOINT;
if (endpoint) {
  contract('cloudflare_r2 (MinIO)', async () => {
    const opts: R2Options = {
      accountId: 'minio',
      accessKeyId: process.env.R2_TEST_ACCESS_KEY_ID ?? 'minioadmin',
      secretAccessKey: process.env.R2_TEST_SECRET_ACCESS_KEY ?? 'minioadmin',
      bucket: `saarthee-test-${Date.now()}`,
      endpoint,
    };
    const admin = new S3Client(r2ClientConfig(opts));
    await admin.send(new CreateBucketCommand({ Bucket: opts.bucket }));
    admin.destroy();
    return new R2PhotoStorage(opts);
  });
} else {
  describe.skip('PhotoStorage contract › cloudflare_r2 (set R2_TEST_ENDPOINT to run against MinIO)', () => {
    it('skipped', () => undefined);
  });
}
