// Create an admin, or reset a password with --reset (03 §5.3, 06 §2.1). Never echoes or logs the password.
// Usage (in apps/api):  npm run admin:create            interactive create
//                       npm run admin:create -- --reset   reset password + log out all sessions
// Non-interactive first run: SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD (+ optional ADMIN_DISPLAY_NAME) in .env.
import { createInterface } from 'node:readline';
import { Writable } from 'node:stream';
import { prisma } from '../src/lib/db';
import { auditLog } from '../src/lib/audit';
import { checkPasswordPolicy, hashPassword } from '../src/lib/password';

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function ask(question: string, hidden = false): Promise<string> {
  let muted = false;
  const output = new Writable({
    write(chunk, _enc, cb) {
      if (!muted) process.stdout.write(chunk);
      cb();
    },
  });
  const rl = createInterface({ input: process.stdin, output, terminal: true });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      if (hidden) process.stdout.write('\n');
      resolve(answer.trim());
    });
    muted = hidden;
  });
}

async function readPassword(): Promise<string> {
  const first = await ask('Password (min 12 characters): ', true);
  const second = await ask('Repeat password: ', true);
  if (first !== second) throw new Error('Passwords do not match.');
  return first;
}

function fail(message: string): never {
  console.error(message);
  process.exit(1);
}

async function main() {
  const reset = process.argv.includes('--reset');
  const envEmail = process.env.SEED_ADMIN_EMAIL?.trim();
  const envPassword = process.env.SEED_ADMIN_PASSWORD;
  const nonInteractive = !reset && !!envEmail && !!envPassword && !process.stdin.isTTY;

  const email = (nonInteractive ? envEmail! : await ask('Admin email: ')).toLowerCase();
  if (!EMAIL.test(email) || email.length > 255) fail('That email address is not valid.');

  const existing = await prisma.adminUser.findUnique({ where: { email }, select: { id: true } });
  if (reset) {
    if (!existing) fail('No admin with that email exists.');
  } else if (existing) {
    fail('An admin with that email already exists. Use --reset to change the password.');
  }

  const displayName = reset
    ? ''
    : nonInteractive
      ? (process.env.ADMIN_DISPLAY_NAME?.trim() || 'Operator')
      : await ask('Display name: ');
  if (!reset && (displayName.length < 1 || displayName.length > 100)) fail('Display name must be 1–100 characters.');

  const password = nonInteractive ? envPassword! : await readPassword();
  const policy = checkPasswordPolicy(password);
  if (!policy.ok) fail(policy.reason);
  const passwordHash = await hashPassword(password);

  if (reset && existing) {
    await prisma.adminUser.update({
      where: { id: existing.id },
      data: { passwordHash, tokenVersion: { increment: 1 } },
    });
    auditLog(null, 'password_reset', existing.id);
    console.log('Password reset. All existing sessions for this admin are logged out.');
  } else {
    const created = await prisma.adminUser.create({ data: { email, displayName, passwordHash }, select: { id: true } });
    console.log(`Admin created (id ${created.id}).`);
  }
  if (nonInteractive) console.log('Remove SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD from .env now (05 §2.2).');
}

main()
  .catch((err: unknown) => {
    console.error('admin:create failed:', err instanceof Error ? err.message : 'unknown error');
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
