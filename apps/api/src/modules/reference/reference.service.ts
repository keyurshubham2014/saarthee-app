import { randomInt } from 'node:crypto';
import { Prisma, type SourceTag } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { MSG } from '../../lib/validation';

const inviteSelect = {
  id: true,
  code: true,
  sourceTag: true,
  groupLabel: true,
  wardHint: true,
  isActive: true,
  createdAt: true,
} as const;

const categorySelect = { id: true, name: true, ccrsLabel: true, sortOrder: true, isActive: true } as const;

const isUniqueViolation = (err: unknown) => err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
const isNotFound = (err: unknown) => err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025';

export async function listInviteCodes() {
  const rows = await prisma.inviteCode.findMany({
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    select: { ...inviteSelect, _count: { select: { complaints: true } } },
  });
  return rows.map(({ _count, ...r }) => ({ ...r, complaintCount: _count.complaints }));
}

// No 0/O/1/I to keep codes easy to read aloud.
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function generateCode(): string {
  let s = '';
  for (let i = 0; i < 8; i += 1) s += ALPHABET[randomInt(ALPHABET.length)];
  return s;
}

export async function createInviteCode(
  input: { code?: string; sourceTag: Exclude<SourceTag, 'unknown'>; groupLabel: string; wardHint?: string },
  adminId: string,
) {
  const explicit = input.code?.toUpperCase();
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const code = explicit ?? generateCode();
    try {
      return await prisma.inviteCode.create({
        data: {
          code,
          sourceTag: input.sourceTag,
          groupLabel: input.groupLabel,
          wardHint: input.wardHint ?? null,
          createdBy: adminId,
        },
        select: inviteSelect,
      });
    } catch (err) {
      if (!isUniqueViolation(err)) throw err;
      if (explicit) throw new AppError('INVITE_CODE_TAKEN', { message: MSG.inviteCode });
    }
  }
  throw new AppError('INTERNAL_ERROR');
}

export async function updateInviteCode(id: string, input: { groupLabel?: string; wardHint?: string | null; isActive?: boolean }) {
  try {
    return await prisma.inviteCode.update({ where: { id }, data: input, select: inviteSelect });
  } catch (err) {
    if (isNotFound(err)) throw new AppError('NOT_FOUND');
    throw err;
  }
}

export async function listCategories() {
  return prisma.ccrsCategory.findMany({ orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }], select: categorySelect });
}

const nameTaken = () =>
  new AppError('VALIDATION_FAILED', { status: 409, details: [{ field: 'name', issue: 'A category with that name already exists.' }] });

export async function createCategory(input: { name: string; ccrsLabel?: string; sortOrder: number }) {
  try {
    return await prisma.ccrsCategory.create({
      data: { name: input.name, ccrsLabel: input.ccrsLabel ?? null, sortOrder: input.sortOrder },
      select: categorySelect,
    });
  } catch (err) {
    if (isUniqueViolation(err)) throw nameTaken();
    throw err;
  }
}

export async function updateCategory(
  id: string,
  input: { name?: string; ccrsLabel?: string | null; sortOrder?: number; isActive?: boolean },
) {
  try {
    return await prisma.ccrsCategory.update({ where: { id }, data: input, select: categorySelect });
  } catch (err) {
    if (isNotFound(err)) throw new AppError('NOT_FOUND');
    if (isUniqueViolation(err)) throw nameTaken();
    throw err;
  }
}
