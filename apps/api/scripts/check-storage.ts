// Storage driver self-check (03 §6.1): save/exists/open/delete round trip, missing-key delete succeeds,
// keys that would escape PHOTO_STORAGE_DIR are refused. Usage: npm run storage:check (in apps/api)
import { LocalPhotoStorage, StorageKeyError } from '../src/lib/storage';
import { config } from '../src/config';

async function main() {
  const s = new LocalPhotoStorage(config.PHOTO_STORAGE_DIR);
  const key = await s.save(Buffer.from([0xff, 0xd8, 0xff, 0xd9]));
  const okKey = /^photos\/\d{4}\/\d{2}\/[0-9a-f-]{36}\.jpg$/.test(key);
  const existed = await s.exists(key);
  const chunks: Buffer[] = [];
  for await (const c of await s.open(key)) chunks.push(c as Buffer);
  await s.delete(key);
  const gone = !(await s.exists(key));
  await s.delete(key); // deleting a missing key must succeed
  const escapes = ['../etc/passwd', 'photos/../../x.jpg', '/etc/passwd', 'photos/2026/10/../../../../x.jpg'];
  const refused = escapes.every((k) => {
    try {
      s.resolve(k);
      return false;
    } catch (e) {
      return e instanceof StorageKeyError;
    }
  });
  const pass = okKey && existed && chunks.length > 0 && gone && refused;
  console.log(`storage:check key=${okKey} exists=${existed} read=${chunks.length > 0} deleted=${gone} missingDeleteOk=true escapeRefused=${refused} → ${pass ? 'PASS' : 'FAIL'}`);
  if (!pass) process.exitCode = 1;
}

main().catch((err: unknown) => {
  console.error('storage:check failed:', err instanceof Error ? err.message : 'unknown error');
  process.exitCode = 1;
});
