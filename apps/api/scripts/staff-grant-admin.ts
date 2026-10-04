/**
 * TASK-10 §5.5: the admin role is granted only from the CLI, never through the API.
 *   npm run staff:grant-admin -- --phone +919876543210
 * The person must have signed in to the app once (a users row exists). Bumps token_version so the next
 * sign-in carries the new role. Prints the user id only (never the phone).
 */
import { PrismaClient } from '@prisma/client';

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main() {
  const phone = arg('phone')?.trim();
  if (!phone || !/^\+91[6-9]\d{9}$/.test(phone)) {
    console.error('Usage: npm run staff:grant-admin -- --phone +91XXXXXXXXXX');
    process.exit(2);
  }
  const prisma = new PrismaClient();
  try {
    const user = await prisma.user.findUnique({ where: { phoneE164: phone }, select: { id: true, role: true, status: true } });
    if (!user || user.status === 'deleted') {
      console.error('No account with that phone. Ask the person to sign in to the app once, then retry.');
      process.exit(1);
    }
    if (user.role === 'admin') {
      console.log(`User ${user.id} is already an admin.`);
      return;
    }
    await prisma.user.update({ where: { id: user.id }, data: { role: 'admin', tokenVersion: { increment: 1 } } });
    console.log(`User ${user.id} is now an admin (was ${user.role}). They must sign in again.`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error('staff:grant-admin failed:', e instanceof Error ? e.message : e);
  process.exit(1);
});
