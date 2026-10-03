import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

/** Case-insensitive lookup (codes are stored uppercase). Unknown or inactive → INVITE_CODE_INVALID. */
export async function validateInviteCode(code: string): Promise<{ valid: true; groupLabel: string }> {
  const invite = await prisma.inviteCode.findUnique({
    where: { code: code.toUpperCase() },
    select: { groupLabel: true, isActive: true },
  });
  if (!invite || !invite.isActive) throw new AppError('INVITE_CODE_INVALID');
  return { valid: true, groupLabel: invite.groupLabel };
}
