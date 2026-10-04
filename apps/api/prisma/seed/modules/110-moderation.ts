import { daysAgo, defineSeedModule } from '../types';
import { seedUserId } from './040-citizens';
import { seedIssueId } from './050-issues';

/** TASK-10 fixed ids. */
const flagId = (n: number) => `5eed0010-0000-4000-8000-0000000001${String(n).padStart(2, '0')}`;

/** Allow-listed feature flags with their defaults (TASK-10 §5.2); election_mode is TASK-09's. */
const SETTING_DEFAULTS: Record<string, boolean> = {
  relay_enabled: true,
  alerts_feed_drafts_enabled: false,
  scorecard_public: true,
  moderation_sensitive_review: true,
};

/**
 * TASK-10 moderation sample data: two open flags on sample issue 1 (Flagged tab) and feature-flag defaults.
 * The sensitive sample issue already fills the Sensitive tab. No out-of-area issue is seeded: POST /issues
 * refuses points outside the wards (OUTSIDE_SERVICE_AREA) and the seed counts are fixed by TASK-01's seed test;
 * the Outside-city-wards tab is covered by test/staff/moderation.test.ts. Idempotent (fixed ids).
 */
export default defineSeedModule({
  name: 'moderation',
  requires: ['moderation_flags', 'issues', 'app_settings', 'categories'],
  async run({ prisma, log }) {
    const flags = [
      { n: 1, reporter: 22, reason: 'spam' as const },
      { n: 2, reporter: 23, reason: 'abusive' as const },
    ];
    const issue1 = seedIssueId(1);
    if (await prisma.issue.findUnique({ where: { id: issue1 }, select: { id: true } })) {
      for (const f of flags) {
        await prisma.moderationFlag.upsert({
          where: { id: flagId(f.n) },
          create: { id: flagId(f.n), targetType: 'issue', targetId: issue1, issueId: issue1, reporterId: seedUserId(f.reporter), reason: f.reason, createdAt: daysAgo(1) },
          update: {},
        });
      }
    }
    for (const [key, value] of Object.entries(SETTING_DEFAULTS)) {
      await prisma.appSetting.upsert({ where: { key }, create: { key, value }, update: {} });
    }
    log('moderation: 2 flags, feature-flag defaults');
  },
});
