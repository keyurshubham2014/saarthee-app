import type { AppLanguage, UserRole, UserStatus } from '@prisma/client';
import { defineSeedModule } from '../types';

/** Fixed ids so other modules (and later tasks) can reference sample users. */
export const seedUserId = (nn: number) => `5eed0001-0000-4000-8000-0000000000${String(nn).padStart(2, '0')}`;

/**
 * 6 clearly fictional sample users. Phones are invented test numbers (+9190000000NN, NN 21–26, distinct
 * from the v1 fixtures' 01–11); Firebase uids seed-uid-NN exist only in the Auth Emulator.
 */
export const SEED_USERS: readonly {
  nn: number;
  displayName: string;
  language: AppLanguage;
  role: UserRole;
  status: UserStatus;
}[] = [
  { nn: 21, displayName: 'Sample Citizen Asha', language: 'gu', role: 'citizen', status: 'active' },
  { nn: 22, displayName: 'Sample Citizen Bhavin', language: 'en', role: 'citizen', status: 'active' },
  { nn: 23, displayName: 'Sample Citizen Chetna', language: 'gu', role: 'citizen', status: 'active' },
  { nn: 24, displayName: 'Sample Citizen Dev', language: 'en', role: 'citizen', status: 'active' },
  { nn: 25, displayName: 'Sample Moderator Esha', language: 'gu', role: 'moderator', status: 'active' },
  { nn: 26, displayName: 'Sample Citizen Farhan', language: 'en', role: 'citizen', status: 'suspended' },
];

export default defineSeedModule({
  name: 'citizens',
  requires: ['users', 'consents'],
  async run({ prisma }) {
    for (const u of SEED_USERS) {
      const id = seedUserId(u.nn);
      if (await prisma.user.findUnique({ where: { id }, select: { id: true } })) continue;
      await prisma.user.create({
        data: {
          id,
          phoneE164: `+9190000000${u.nn}`,
          firebaseUid: `seed-uid-${u.nn}`,
          displayName: u.displayName,
          language: u.language,
          role: u.role,
          status: u.status,
          consents: { create: [{ purpose: 'core_service', textVersion: 'v2' }] },
        },
      });
    }
  },
});
