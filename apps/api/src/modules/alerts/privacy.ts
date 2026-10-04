import { registerErasureStep, registerExportSection } from '../me/privacy.registry';

/** TASK-08 personal data: a user's alert subscriptions (extra wards, muted types). Registered once at import. */
registerExportSection('alert_subscriptions', (userId, tx) =>
  tx.subscription.findMany({
    where: { userId },
    select: { scope: true, scopeId: true, mutedTypes: true, criticalOnly: true, createdAt: true },
  }),
);

registerErasureStep('alert_subscriptions', async (userId, tx) => {
  await tx.subscription.deleteMany({ where: { userId } });
});
