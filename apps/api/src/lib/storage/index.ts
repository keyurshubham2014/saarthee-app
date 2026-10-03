import { randomUUID } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { access, mkdir, realpath, rename, rm, stat, writeFile, constants } from 'node:fs/promises';
import path from 'node:path';
import type { Readable } from 'node:stream';
import type { StorageDriver } from '@prisma/client';
import { config } from '../../config';

/**
 * Storage interface (03 §6.1). Keys are opaque, server-generated (`photos/<yyyy>/<mm>/<uuid>.jpg`).
 * Every implementation must behave identically: delete of a missing key succeeds.
 */
export interface PhotoStorage {
  readonly driver: StorageDriver;
  save(bytes: Buffer): Promise<string>;
  open(key: string): Promise<Readable>;
  delete(key: string): Promise<void>;
  exists(key: string): Promise<boolean>;
}

const KEY_PATTERN = /^photos\/\d{4}\/\d{2}\/[0-9a-f-]{36}\.jpg$/;

export function newPhotoKey(now = new Date()): string {
  const yyyy = String(now.getUTCFullYear());
  const mm = String(now.getUTCMonth() + 1).padStart(2, '0');
  return `photos/${yyyy}/${mm}/${randomUUID()}.jpg`;
}

export class StorageKeyError extends Error {
  constructor() {
    super('invalid storage key');
  }
}

/** Local-disk driver: files live under PHOTO_STORAGE_DIR; keys resolving outside it are refused. */
export class LocalPhotoStorage implements PhotoStorage {
  readonly driver = 'local' as const;
  private readonly root: string;

  constructor(root: string) {
    this.root = path.resolve(root);
  }

  /** Maps a key to an absolute path, refusing anything that is malformed or escapes the root. */
  resolve(key: string): string {
    if (!KEY_PATTERN.test(key)) throw new StorageKeyError();
    const full = path.resolve(this.root, key);
    if (!full.startsWith(this.root + path.sep)) throw new StorageKeyError();
    return full;
  }

  async save(bytes: Buffer): Promise<string> {
    const key = newPhotoKey();
    const full = this.resolve(key);
    await mkdir(path.dirname(full), { recursive: true, mode: 0o700 });
    const tmp = `${full}.${randomUUID()}.tmp`;
    await writeFile(tmp, bytes, { mode: 0o600, flag: 'wx' });
    await rename(tmp, full);
    return key;
  }

  async open(key: string): Promise<Readable> {
    const full = this.resolve(key);
    await access(full, constants.R_OK);
    return createReadStream(full);
  }

  async delete(key: string): Promise<void> {
    await rm(this.resolve(key), { force: true });
  }

  async exists(key: string): Promise<boolean> {
    try {
      return (await stat(this.resolve(key))).isFile();
    } catch (err) {
      if (err instanceof StorageKeyError) throw err;
      return false;
    }
  }
}

function createStorage(): PhotoStorage {
  if (config.STORAGE_DRIVER !== 'local') {
    // The Cloudflare driver is a deployment-time addition (03 §6); refuse to start rather than misbehave.
    throw new Error(`STORAGE_DRIVER=${config.STORAGE_DRIVER} is not available in this build; use local`);
  }
  return new LocalPhotoStorage(config.PHOTO_STORAGE_DIR);
}

export const storage: PhotoStorage = createStorage();

/** Startup check (TASK-04 step 2): the photo folder exists, is writable, and is outside the repository. */
export async function assertStorageReady(): Promise<void> {
  const dir = path.resolve(config.PHOTO_STORAGE_DIR);
  await mkdir(dir, { recursive: true, mode: 0o700 });
  await access(dir, constants.W_OK | constants.R_OK);
  const realDir = await realpath(dir);
  // apps/api/src/lib/storage → repository root is five levels up.
  const repoRoot = await realpath(path.resolve(__dirname, '../../../../..'));
  if (realDir === repoRoot || realDir.startsWith(repoRoot + path.sep)) {
    throw new Error('PHOTO_STORAGE_DIR must be outside the repository');
  }
}
