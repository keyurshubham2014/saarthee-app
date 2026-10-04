import { hashPassword } from '../../../src/lib/password';
import { defineSeedModule } from '../types';

/** v1 admin login (kept until staff move to OTP, Spec §7). Created once; never updated. */
export default defineSeedModule({
  name: 'admin',
  requires: ['admin_users'],
  async run({ prisma, adminEmail, adminPassword }) {
    const existing = await prisma.adminUser.findUnique({ where: { email: adminEmail }, select: { id: true } });
    if (existing) return;
    await prisma.adminUser.create({
      data: { email: adminEmail, passwordHash: await hashPassword(adminPassword), displayName: 'Dev Admin' },
    });
  },
});
