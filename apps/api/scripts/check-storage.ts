// Storage driver self-check (03 §6.1, V2 TASK-13 step 1) against the configured STORAGE_DRIVER:
// save/exists/open/delete round trip, missing-key delete succeeds, keys that could escape the store are
// refused. Never prints keys' bucket, credentials or paths. Usage: npm run storage:check (in apps/api)
import { config } from '../src/config';
import { StorageKeyError, storageFor } from '../src/lib/storage';

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xd9]);

async function main() {
  const s = storageFor(config.STORAGE_DRIVER);
  const key = await s.save(JPEG);
  const okKey = /^photos\/\d{4}\/\d{2}\/[0-9a-f-]{36}\.jpg$/.test(key);
  const existed = await s.exists(key);
  const chunks: Buffer[] = [];
  for await (const c of await s.open(key)) chunks.push(c as Buffer);
  const sameBytes = Buffer.concat(chunks).equals(JPEG);
  await s.delete(key);
  const gone = !(await s.exists(key));
  await s.delete(key); // deleting a missing key must succeed
  const escapes = ['../etc/passwd', 'photos/../../x.jpg', '/etc/passwd', 'photos/2026/10/../../../../x.jpg'];
  let refused = true;
  for (const k of escapes) {
    try {
      await s.exists(k);
      refused = false;
    } catch (e) {
      if (!(e instanceof StorageKeyError)) refused = false;
    }
  }
  const pass = okKey && existed && sameBytes && gone && refused;
  console.log(
    `storage:check driver=${s.driver} key=${okKey} exists=${existed} read=${sameBytes} deleted=${gone} ` +
      `missingDeleteOk=true escapeRefused=${refused} → ${pass ? 'PASS' : 'FAIL'}`,
  );
  if (!pass) process.exitCode = 1;
}

main().catch((err: unknown) => {
  console.error('storage:check failed:', err instanceof Error ? err.message : 'unknown error');
  process.exitCode = 1;
});
