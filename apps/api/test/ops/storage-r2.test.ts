/** T-13-02 (V2 TASK-13 AC-1): R2 driver error mapping with a fake S3 client, and per-row driver resolution. */
import { Readable } from 'node:stream';
import { DeleteObjectCommand, GetObjectCommand, HeadObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { AppError } from '../../src/lib/errors';
import {
  LocalPhotoStorage,
  R2PhotoStorage,
  setStorageForTesting,
  StorageNotFoundError,
  StorageUnavailableError,
} from '../../src/lib/storage';
import { openPhoto } from '../../src/modules/photos/read.service';
import { resetDb } from '../helpers/db';
import { makePhoto } from '../helpers/factories';

const OPTS = { accountId: 'acc', accessKeyId: 'AKIA-FAKE', secretAccessKey: 'super-secret-value', bucket: 'b' };
const KEY = 'photos/2026/10/11111111-1111-4111-8111-111111111111.jpg';

function awsError(name: string, status?: number) {
  return Object.assign(new Error(name), { name, $metadata: { httpStatusCode: status } });
}

/** Fake client: records commands and answers with `reply(command)`. */
function fake(reply: (cmd: unknown) => unknown) {
  const sent: unknown[] = [];
  return {
    sent,
    client: {
      async send(cmd: unknown) {
        sent.push(cmd);
        const r = reply(cmd);
        if (r instanceof Error) throw r;
        return r;
      },
    },
  };
}

describe('R2PhotoStorage › error mapping (mocked S3)', () => {
  it('save sends PutObject with jpeg content type and private cache control', async () => {
    const f = fake(() => ({}));
    const key = await new R2PhotoStorage(OPTS, f.client).save(Buffer.from([1]));
    const put = f.sent[0] as PutObjectCommand;
    expect(put).toBeInstanceOf(PutObjectCommand);
    expect(put.input).toMatchObject({ Bucket: 'b', Key: key, ContentType: 'image/jpeg', CacheControl: 'private, max-age=0' });
  });

  it('GetObject NoSuchKey → StorageNotFoundError', async () => {
    const f = fake(() => awsError('NoSuchKey', 404));
    await expect(new R2PhotoStorage(OPTS, f.client).open(KEY)).rejects.toBeInstanceOf(StorageNotFoundError);
    expect(f.sent[0]).toBeInstanceOf(GetObjectCommand);
  });

  it('HeadObject 404 → exists false; 200 → true', async () => {
    const missing = fake(() => awsError('NotFound', 404));
    expect(await new R2PhotoStorage(OPTS, missing.client).exists(KEY)).toBe(false);
    expect(missing.sent[0]).toBeInstanceOf(HeadObjectCommand);
    const present = fake(() => ({}));
    expect(await new R2PhotoStorage(OPTS, present.client).exists(KEY)).toBe(true);
  });

  it('DeleteObject of a missing key succeeds', async () => {
    const f = fake(() => awsError('NoSuchKey', 404));
    await expect(new R2PhotoStorage(OPTS, f.client).delete(KEY)).resolves.toBeUndefined();
    expect(f.sent[0]).toBeInstanceOf(DeleteObjectCommand);
  });

  it('timeouts and 5xx → StorageUnavailableError naming only the error class', async () => {
    for (const err of [awsError('TimeoutError'), awsError('InternalError', 500)]) {
      const f = fake(() => err);
      const p = new R2PhotoStorage(OPTS, f.client).open(KEY);
      await expect(p).rejects.toBeInstanceOf(StorageUnavailableError);
      const msg = await p.catch((e: Error) => e.message);
      expect(msg).not.toContain(OPTS.secretAccessKey);
      expect(msg).not.toContain(KEY);
    }
  });

  it('refuses traversal keys before calling the client', async () => {
    const f = fake(() => ({}));
    await expect(new R2PhotoStorage(OPTS, f.client).open('../x.jpg')).rejects.toThrow('invalid storage key');
    expect(f.sent).toHaveLength(0);
  });
});

describe('per-row driver resolution (openPhoto)', () => {
  const bytes = Buffer.from([0xff, 0xd8, 9, 0xff, 0xd9]);
  let local: LocalPhotoStorage;

  beforeEach(async () => {
    await resetDb();
    local = new LocalPhotoStorage(process.env.PHOTO_STORAGE_DIR!);
  });
  afterEach(() => setStorageForTesting('cloudflare_r2', undefined));

  async function read(id: string) {
    const chunks: Buffer[] = [];
    for await (const c of await openPhoto(id)) chunks.push(Buffer.from(c as Buffer));
    return Buffer.concat(chunks);
  }

  it('reads a cloudflare_r2 row through R2 and a local row through the local driver', async () => {
    const f = fake(() => ({ Body: Readable.from([bytes]) }));
    setStorageForTesting('cloudflare_r2', new R2PhotoStorage(OPTS, f.client));
    const r2Row = await makePhoto({ storageDriver: 'cloudflare_r2', storageKey: KEY });
    expect((await read(r2Row.id)).equals(bytes)).toBe(true);

    const localKey = await local.save(bytes);
    const localRow = await makePhoto({ storageDriver: 'local', storageKey: localKey });
    expect((await read(localRow.id)).equals(bytes)).toBe(true);
    expect(f.sent).toHaveLength(1);
    await local.delete(localKey);
  });

  it('R2 timeout on read → SERVICE_UNAVAILABLE (503); missing object → NOT_FOUND', async () => {
    setStorageForTesting('cloudflare_r2', new R2PhotoStorage(OPTS, fake(() => awsError('TimeoutError')).client));
    const row = await makePhoto({ storageDriver: 'cloudflare_r2', storageKey: KEY });
    await expect(openPhoto(row.id)).rejects.toMatchObject({ code: 'SERVICE_UNAVAILABLE', status: 503 });

    setStorageForTesting('cloudflare_r2', new R2PhotoStorage(OPTS, fake(() => awsError('NoSuchKey', 404)).client));
    await expect(openPhoto(row.id)).rejects.toBeInstanceOf(AppError);
    await expect(openPhoto(row.id)).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});
