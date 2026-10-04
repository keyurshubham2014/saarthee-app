import { Readable } from 'node:stream';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
  type S3ClientConfig,
} from '@aws-sdk/client-s3';
import {
  assertPhotoKey,
  newPhotoKey,
  StorageNotFoundError,
  StorageUnavailableError,
  type PhotoStorage,
} from './core';

export interface R2Options {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  /** Override for tests (MinIO) — default `https://<accountId>.r2.cloudflarestorage.com`. */
  endpoint?: string;
}

/** Narrow client surface so tests can inject a fake (T-13-02). */
export interface S3Like {
  send(command: unknown): Promise<unknown>;
}

const TIMEOUT_MS = 10_000;

export function r2ClientConfig(o: R2Options): S3ClientConfig {
  return {
    region: 'auto',
    endpoint: o.endpoint ?? `https://${o.accountId}.r2.cloudflarestorage.com`,
    credentials: { accessKeyId: o.accessKeyId, secretAccessKey: o.secretAccessKey },
    // MinIO needs path-style addressing; R2 accepts both.
    forcePathStyle: true,
    maxAttempts: 3, // 1 try + 2 retries, SDK default backoff
    requestHandler: { requestTimeout: TIMEOUT_MS, connectionTimeout: TIMEOUT_MS },
  };
}

function statusOf(err: unknown): number | undefined {
  return (err as { $metadata?: { httpStatusCode?: number } })?.$metadata?.httpStatusCode;
}

function isNotFound(err: unknown): boolean {
  const name = (err as { name?: string })?.name;
  return name === 'NoSuchKey' || name === 'NotFound' || statusOf(err) === 404;
}

/**
 * Cloudflare R2 driver (V2 TASK-13 §5.3). The bucket is private; photos are only served through the API.
 * Errors never include credentials or the key: missing objects map to StorageNotFoundError (same as the
 * local driver), everything else (timeouts, 5xx, network) to StorageUnavailableError.
 */
export class R2PhotoStorage implements PhotoStorage {
  readonly driver = 'cloudflare_r2' as const;
  private readonly client: S3Like;
  private readonly bucket: string;

  constructor(options: R2Options, client?: S3Like) {
    this.bucket = options.bucket;
    this.client = client ?? new S3Client(r2ClientConfig(options));
  }

  private async call<T>(command: unknown): Promise<T> {
    try {
      return (await this.client.send(command)) as T;
    } catch (err) {
      if (isNotFound(err)) throw new StorageNotFoundError();
      throw new StorageUnavailableError((err as { name?: string })?.name ?? 'unknown');
    }
  }

  async save(bytes: Buffer): Promise<string> {
    const key = newPhotoKey();
    await this.call(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: bytes,
        ContentType: 'image/jpeg',
        CacheControl: 'private, max-age=0',
      }),
    );
    return key;
  }

  async open(key: string): Promise<Readable> {
    assertPhotoKey(key);
    const out = await this.call<{ Body?: unknown }>(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
    const body = out.Body;
    if (body instanceof Readable) return body;
    if (body && typeof (body as { transformToByteArray?: unknown }).transformToByteArray === 'function') {
      const bytes = await (body as { transformToByteArray(): Promise<Uint8Array> }).transformToByteArray();
      return Readable.from([Buffer.from(bytes)]);
    }
    throw new StorageNotFoundError();
  }

  async delete(key: string): Promise<void> {
    assertPhotoKey(key);
    try {
      await this.call(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
    } catch (err) {
      if (err instanceof StorageNotFoundError) return; // missing = success
      throw err;
    }
  }

  async exists(key: string): Promise<boolean> {
    assertPhotoKey(key);
    try {
      await this.call(new HeadObjectCommand({ Bucket: this.bucket, Key: key }));
      return true;
    } catch (err) {
      if (err instanceof StorageNotFoundError) return false;
      throw err;
    }
  }
}
