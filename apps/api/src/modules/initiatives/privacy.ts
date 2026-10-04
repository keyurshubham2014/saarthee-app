import { registerErasureStep, registerExportSection } from '../me/privacy.registry';

/**
 * TASK-12 §5.2 privacy hooks: `GET /me/export` section `rsvps`, and the `DELETE /me` step that removes
 * the user's RSVPs and gives back their seats on drives that have not started yet.
 */
registerExportSection('rsvps', async (userId, tx) => {
  const rows = await tx.rsvp.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
    include: { initiative: { select: { titleEn: true, titleGu: true, startsAt: true } } },
  });
  return rows.map((r) => ({
    initiativeId: r.initiativeId,
    titleEn: r.initiative.titleEn,
    titleGu: r.initiative.titleGu,
    startsAt: r.initiative.startsAt,
    status: r.status,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  }));
});

registerErasureStep('rsvps', async (userId, tx) => {
  const future = await tx.rsvp.findMany({
    where: { userId, status: 'going', initiative: { startsAt: { gt: new Date() } } },
    select: { initiativeId: true },
  });
  for (const { initiativeId } of future) {
    await tx.$executeRaw`UPDATE initiatives SET going_count = GREATEST(going_count - 1, 0) WHERE id = ${initiativeId}::uuid`;
  }
  await tx.rsvp.deleteMany({ where: { userId } });
  // Attendance marks made by this user (if staff) stay, without the link to them.
  await tx.rsvp.updateMany({ where: { attendanceMarkedBy: userId }, data: { attendanceMarkedBy: null } });
});
