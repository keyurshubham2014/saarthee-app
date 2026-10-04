/**
 * GET /issues/{id} (V2 TASK-07 §5.3, REQ-F-030): the public issue, the viewer's capabilities and a
 * timeline preview. Capabilities come from TASK-06's single source (readLifecycle → transition rules).
 */
import type { AuthenticatedUser } from '../../middleware/requireUser';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { listEvents } from '../lifecycle/events.service';
import { readLifecycle } from '../lifecycle/read.service';
import { OPEN_STATUSES } from './engage.service';
import { publicIssueInclude, toPublicIssue, type Lang } from './public';
import { rejectionReasonText } from '../staff/reject-reasons';

export async function getIssueDetail(id: string, viewer: AuthenticatedUser | undefined, lang: Lang) {
  const row = await prisma.issue.findUnique({ where: { id }, include: publicIssueInclude });
  const staff = viewer !== undefined && viewer.role !== 'citizen';
  const isReporter = viewer !== undefined && row?.reporterId === viewer.id;
  if (!row || ((row.visibility === 'hidden' || row.status === 'rejected') && !staff && !isReporter)) throw new AppError('NOT_FOUND');

  const [life, timeline, mine] = await Promise.all([
    readLifecycle(id, viewer),
    listEvents(id, viewer, undefined, 5),
    viewer
      ? Promise.all([
          prisma.meToo.count({ where: { issueId: id, userId: viewer.id } }),
          prisma.follow.count({ where: { issueId: id, userId: viewer.id } }),
        ])
      : Promise.resolve([0, 0] as const),
  ]);
  const can = life.viewer.can;
  const open = OPEN_STATUSES.includes(row.status);
  let rejectionReason: string | null = null;
  if (row.status === 'rejected' && (isReporter || staff)) {
    const e = await prisma.issueEvent.findFirst({ where: { issueId: id, toStatus: 'rejected' }, orderBy: { createdAt: 'desc' }, select: { note: true } });
    rejectionReason = rejectionReasonText(e?.note ?? null, lang);
  }
  return {
    issue: { ...toPublicIssue(row, lang), visibility: isReporter || staff ? row.visibility : undefined, rejectionReason },
    viewer: {
      signedIn: viewer !== undefined,
      isReporter,
      hasMeToo: mine[0] > 0,
      isFollowing: mine[1] > 0,
      canMeToo: !isReporter && open && row.visibility === 'public',
      canVerify: can.verify,
      canMarkFixed: can.markFixed,
      canAcknowledge: can.acknowledge,
      canLinkCcrs: isReporter && row.ccrsNumber === null && open,
      canMarkCcrsClosed: can.ccrsClosed,
      canEscalate: can.escalate,
      // TASK-10 owns flagging; hidden until its endpoint exists.
      canFlag: false,
    },
    ccrs: {
      linked: row.ccrsNumber !== null,
      ...(isReporter && row.ccrsNumber ? { number: row.ccrsNumber } : {}),
      closedAt: row.ccrsClosedAt,
    },
    timelinePreview: timeline.items,
  };
}
