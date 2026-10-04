/** TASK-12 test helpers: services, initiatives, tips and role users with session tokens. */
import type { Prisma, UserRole } from '@prisma/client';
import { vi } from 'vitest';
import { prisma } from '../../src/lib/db';
import { logger } from '../../src/lib/logger';
import { signUserToken } from '../../src/lib/tokens';
import { makeUser } from '../helpers/factories';

let n = 0;
const next = () => ++n;

export const HOUR = 3_600_000;
export const DAY = 24 * HOUR;
export const inHours = (h: number) => new Date(Date.now() + h * HOUR);

/** A user of `role` with a valid citizen-session token. */
export async function roleUser(role: UserRole = 'citizen', data: Partial<Prisma.UserUncheckedCreateInput> = {}) {
  const user = await makeUser({ role, ...data });
  const { accessToken } = signUserToken({ id: user.id, tokenVersion: user.tokenVersion, role: user.role });
  return { user, token: accessToken, auth: { Authorization: `Bearer ${accessToken}` } };
}

export async function makeService(data: Partial<Prisma.ServiceUncheckedCreateInput> = {}) {
  const k = next();
  return prisma.service.create({
    data: {
      slug: `svc-${k}`,
      category: 'tax',
      nameEn: `Service ${k}`,
      nameGu: `સેવા ${k}`,
      department: 'Dept',
      departmentGu: 'વિભાગ',
      summaryEn: `Summary ${k}`,
      summaryGu: `સારાંશ ${k}`,
      howToEn: '1. Open the page.\n2. Do it.',
      howToGu: '1. પેજ ખોલો.\n2. કરો.',
      url: `https://example.test/svc-${k}`,
      online: true,
      ...data,
    },
  });
}

export async function makeInitiative(data: Partial<Prisma.InitiativeUncheckedCreateInput> = {}) {
  const k = next();
  const startsAt = (data.startsAt as Date | undefined) ?? inHours(72);
  return prisma.initiative.create({
    data: {
      titleEn: `Drive ${k}`,
      titleGu: `કાર્યક્રમ ${k}`,
      descriptionEn: 'A sample drive.',
      descriptionGu: 'નમૂનો.',
      type: 'cleanup',
      organiser: 'RWA',
      organiserName: 'Test RWA',
      locationTextEn: 'Gate 1',
      locationTextGu: 'ગેટ 1',
      status: 'published',
      ...data,
      startsAt,
      endsAt: (data.endsAt as Date | undefined) ?? new Date(startsAt.getTime() + 2 * HOUR),
    },
  });
}

export async function goingRsvp(initiativeId: string, userId: string, status = 'going') {
  await prisma.rsvp.create({ data: { initiativeId, userId, status } });
  if (status === 'going') await prisma.initiative.update({ where: { id: initiativeId }, data: { goingCount: { increment: 1 } } });
}

/** Captures `staff_action` audit lines written through the logger. */
export function captureStaffAudit() {
  const lines: Record<string, unknown>[] = [];
  const spy = vi.spyOn(logger, 'info').mockImplementation(((obj: unknown, msg?: string) => {
    if (msg === 'staff_action') lines.push(obj as Record<string, unknown>);
  }) as typeof logger.info);
  return { lines, restore: () => spy.mockRestore() };
}
