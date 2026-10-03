import { readFileSync } from 'node:fs';
import path from 'node:path';
import argon2 from 'argon2';

// Argon2id with OWASP-recommended minimums (m=19 MiB, t=2, p=1). 06 §2.1.
const OPTIONS = { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 } as const;

export function hashPassword(plain: string): Promise<string> {
  return argon2.hash(plain, OPTIONS);
}

export async function verifyPassword(hash: string, plain: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, plain);
  } catch {
    return false;
  }
}

// Dummy hash so unknown-email logins take as long as wrong-password ones (TASK-05 §5.3 step 2).
let dummyHash: Promise<string> | undefined;
export async function verifyAgainstDummy(plain: string): Promise<boolean> {
  dummyHash ??= hashPassword('dummy-password-for-timing-equalisation');
  return verifyPassword(await dummyHash, plain);
}

let commonPasswords: Set<string> | undefined;
function loadCommonPasswords(): Set<string> {
  if (!commonPasswords) {
    // Public SecLists "10k-most-common" list, bundled with the API (06 §2.1).
    const file = path.resolve(__dirname, '../../../scripts/data/common-passwords-10k.txt');
    commonPasswords = new Set(
      readFileSync(file, 'utf8')
        .split(/\r?\n/)
        .map((l) => l.trim().toLowerCase())
        .filter(Boolean),
    );
  }
  return commonPasswords;
}

/** Password policy (06 §2.1): at least 12 characters and not in the common list (case-insensitive). */
export function checkPasswordPolicy(plain: string): { ok: true } | { ok: false; reason: string } {
  if (plain.length < 12) return { ok: false, reason: 'Password must be at least 12 characters.' };
  if (loadCommonPasswords().has(plain.toLowerCase())) {
    return { ok: false, reason: 'That password is too common. Choose another.' };
  }
  return { ok: true };
}
