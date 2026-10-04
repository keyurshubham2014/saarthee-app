import { maskPhone } from './profile.service';
import { registerExportSection } from './privacy.registry';

/**
 * Export sections owned by TASK-04 and, because TASK-01 created the tables, the issue sections
 * (TASK-04 §5.2). Only the requesting user's rows; never FCM tokens; phone masked (ASSUMPTION §5.6).
 */
registerExportSection('profile', async (userId, tx) => {
  const u = await tx.user.findUniqueOrThrow({ where: { id: userId } });
  return {
    id: u.id,
    displayName: u.displayName,
    phoneMasked: maskPhone(u.phoneE164),
    language: u.language,
    role: u.role,
    status: u.status,
    homeWardId: u.homeWardId,
    ageConfirmedAt: u.ageConfirmedAt,
    createdAt: u.createdAt,
    lastSeenAt: u.lastSeenAt,
  };
});

registerExportSection('consents', (userId, tx) =>
  tx.consent.findMany({
    where: { userId },
    orderBy: { grantedAt: 'asc' },
    select: { purpose: true, textVersion: true, grantedAt: true, withdrawnAt: true },
  }),
);

registerExportSection('devices', async (userId, tx) => {
  const rows = await tx.device.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } });
  return rows.map((d) => ({
    id: d.id,
    platform: d.platform,
    appVersion: d.appVersion,
    language: d.language,
    topics: d.topics,
    pushEnabled: d.fcmToken !== null,
    createdAt: d.createdAt,
    lastSeenAt: d.lastSeenAt,
  }));
});

registerExportSection('notifications', (userId, tx) =>
  tx.notification.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
    select: { id: true, kind: true, route: true, titleEn: true, titleGu: true, bodyEn: true, bodyGu: true, status: true, createdAt: true, readAt: true },
  }),
);

registerExportSection('issues', async (userId, tx) => {
  const rows = await tx.issue.findMany({
    where: { reporterId: userId },
    orderBy: { createdAt: 'asc' },
    select: { id: true, status: true, createdAt: true, wardId: true, title: true, description: true, category: { select: { slug: true } } },
  });
  return rows.map(({ category, ...r }) => ({ ...r, category: category.slug }));
});

registerExportSection('me_toos', (userId, tx) =>
  tx.meToo.findMany({ where: { userId }, orderBy: { createdAt: 'asc' }, select: { issueId: true, createdAt: true } }),
);

registerExportSection('follows', (userId, tx) =>
  tx.follow.findMany({ where: { userId }, orderBy: { createdAt: 'asc' }, select: { issueId: true, createdAt: true } }),
);

registerExportSection('issue_verifications', (userId, tx) =>
  tx.issueVerification.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
    select: { id: true, issueId: true, answer: true, distanceM: true, createdAt: true, photoId: true },
  }),
);
