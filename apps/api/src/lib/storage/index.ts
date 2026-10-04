import { access, mkdir, realpath, constants } from 'node:fs/promises';
import path from 'node:path';
import type { StorageDriver } from '@prisma/client';
import { config } from '../../config';
import { LocalPhotoStorage, type PhotoStorage } from './core';
import { R2PhotoStorage } from './r2';

export * from './core';
export { R2PhotoStorage } from './r2';

const instances = new Map<StorageDriver, PhotoStorage>();

function build(driver: StorageDriver): PhotoStorage {
  if (driver === 'local') {
    if (!config.PHOTO_STORAGE_DIR) throw new Error('PHOTO_STORAGE_DIR is not set; local photos cannot be read');
    return new LocalPhotoStorage(config.PHOTO_STORAGE_DIR);
  }
  const { R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_ENDPOINT } = config;
  if (!R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY || !R2_BUCKET) {
    throw new Error('R2_* variables are not set; cloudflare_r2 photos cannot be read');
  }
  return new R2PhotoStorage({
    accountId: R2_ACCOUNT_ID,
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
    bucket: R2_BUCKET,
    endpoint: R2_ENDPOINT,
  });
}

/**
 * The driver that stored a given row (`photos.storage_driver`) — reads resolve per row so photos saved
 * by an earlier driver stay readable after STORAGE_DRIVER changes (V2 TASK-13 §5.2).
 */
export function storageFor(driver: StorageDriver): PhotoStorage {
  let s = instances.get(driver);
  if (!s) {
    s = build(driver);
    instances.set(driver, s);
  }
  return s;
}

/** Replaces a driver instance (tests only). */
export function setStorageForTesting(driver: StorageDriver, s: PhotoStorage | undefined): void {
  if (s) instances.set(driver, s);
  else instances.delete(driver);
}

/** The active driver for new writes (STORAGE_DRIVER). Resolved lazily on each access. */
export const storage: PhotoStorage = {
  get driver() {
    return storageFor(config.STORAGE_DRIVER).driver;
  },
  save: (bytes) => storageFor(config.STORAGE_DRIVER).save(bytes),
  open: (key) => storageFor(config.STORAGE_DRIVER).open(key),
  delete: (key) => storageFor(config.STORAGE_DRIVER).delete(key),
  exists: (key) => storageFor(config.STORAGE_DRIVER).exists(key),
};

/**
 * Startup check. Local: the photo folder exists, is writable, and is outside the repository (TASK-04
 * step 2). R2: the client can be built (the bucket is reached on first use; `storage:check` probes it).
 */
export async function assertStorageReady(): Promise<void> {
  if (config.STORAGE_DRIVER === 'cloudflare_r2') {
    storageFor('cloudflare_r2');
    return;
  }
  const dir = path.resolve(config.PHOTO_STORAGE_DIR ?? '');
  await mkdir(dir, { recursive: true, mode: 0o700 });
  await access(dir, constants.W_OK | constants.R_OK);
  const realDir = await realpath(dir);
  // apps/api/src/lib/storage → repository root is five levels up (dist/src/lib/storage in the image:
  // the check still holds because the image has no repository around it).
  const repoRoot = await realpath(path.resolve(__dirname, '../../../../..'));
  if (realDir === repoRoot || realDir.startsWith(repoRoot + path.sep)) {
    throw new Error('PHOTO_STORAGE_DIR must be outside the repository');
  }
}
