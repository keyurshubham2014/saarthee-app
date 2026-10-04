/**
 * Me too removal and Follow / Unfollow (V2 TASK-07 §5.3, REQ-F-031). Row insert/delete and the counter
 * update share one transaction; counters move by exactly one only when a row changed. Removing Me too
 * keeps the follow; a reporter may unfollow their own issue.
 */
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

async function assertVisible(issueId: string, userId: string) {
  const i = await prisma.issue.findUnique({ where: { id: issueId }, select: { visibility: true, reporterId: true } });
  if (!i || (i.visibility !== 'public' && i.reporterId !== userId)) throw new AppError('NOT_FOUND');
}

export async function removeMeToo(userId: string, issueId: string): Promise<{ meTooCount: number }> {
  await assertVisible(issueId, userId);
  return prisma.$transaction(async (tx) => {
    const deleted = await tx.$executeRaw`DELETE FROM me_toos WHERE issue_id = ${issueId}::uuid AND user_id = ${userId}::uuid`;
    const [r] = await tx.$queryRaw<{ me_too_count: number }[]>`
      UPDATE issues SET me_too_count = GREATEST(me_too_count - ${deleted > 0 ? 1 : 0}::int, 0)
      WHERE id = ${issueId}::uuid RETURNING me_too_count`;
    return { meTooCount: Number(r?.me_too_count ?? 0) };
  });
}

export async function setFollow(userId: string, issueId: string, on: boolean): Promise<{ followerCount: number; isFollowing: boolean }> {
  await assertVisible(issueId, userId);
  return prisma.$transaction(async (tx) => {
    const changed = on
      ? await tx.$executeRaw`INSERT INTO follows (issue_id, user_id) VALUES (${issueId}::uuid, ${userId}::uuid) ON CONFLICT DO NOTHING`
      : await tx.$executeRaw`DELETE FROM follows WHERE issue_id = ${issueId}::uuid AND user_id = ${userId}::uuid`;
    const delta = changed > 0 ? (on ? 1 : -1) : 0;
    const [r] = await tx.$queryRaw<{ follower_count: number }[]>`
      UPDATE issues SET follower_count = GREATEST(follower_count + ${delta}::int, 0)
      WHERE id = ${issueId}::uuid RETURNING follower_count`;
    return { followerCount: Number(r?.follower_count ?? 0), isFollowing: on };
  });
}
