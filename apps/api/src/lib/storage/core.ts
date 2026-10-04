import { randomUUID } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { access, mkdir, rename, rm, stat, writeFile, constants } from 'node:fs/promises';
import path from 'node:path';
import type { Readable } from 'node:stream';
import type { StorageDriver } from '@prisma/client';

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

/** The object does not exist (same class for every driver). */
export class StorageNotFoundError extends Error {
  constructor() {
    super('stored object not found');
  }
}

/** The backend could not be reached or failed (timeout, 5xx); carries the error class name only. */
export class StorageUnavailableError extends Error {
  constructor(reason: string) {
    super(`storage unavailable: ${reason}`);
  }
}

/** Throws StorageKeyError unless `key` is a server-generated photo key (traversal-proof). */
export function assertPhotoKey(key: string): void {
  if (!KEY_PATTERN.test(key)) throw new StorageKeyError();
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
    try {
      await access(full, constants.R_OK);
    } catch {
      throw new StorageNotFoundError();
    }
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
