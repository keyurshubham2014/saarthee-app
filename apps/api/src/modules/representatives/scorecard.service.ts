/**
 * Public ward scorecard (TASK-09 §5.2, REQ-F-046, REQ-D-012). One indexed row of `ward_scorecard_mv`;
 * medians/percentages below SCORECARD_MIN_SAMPLE are returned as null; hidden while election mode is active
 * for the ward. The 90-day window is fixed in the view definition (migration 20261009090200).
 */
import { config } from '../../config';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { electionStatus } from '../settings/electionMode';

export const SCORECARD_WINDOW_DAYS = 90;

interface MvRow {
  issues_reported: number;
  median_days_ack: string | null;
  ack_sample: number;
  median_days_fix: string | null;
  fix_sample: number;
  verified_pct: string | null;
  verified_sample: number;
  reopen_pct: string | null;
  reopen_sample: number;
  open_backlog: number;
  reports_per_1000: string | null;
  refreshed_at: Date;
}

const num = (v: string | null) => (v === null ? null : Number(v));

export async function wardScorecard(wardId: string) {
  const ward = await prisma.ward.findUnique({ where: { id: wardId }, select: { id: true, population: true } });
  if (!ward) throw new AppError('NOT_FOUND');
  const election = await electionStatus(wardId);
  if (election.active) return { wardId, hidden: true as const, reason: 'election_mode' as const, until: election.until };

  const rows = await prisma.$queryRaw<MvRow[]>`SELECT * FROM ward_scorecard_mv WHERE ward_id = ${wardId}::uuid`;
  const r = rows[0];
  const min = config.SCORECARD_MIN_SAMPLE;
  const gate = (v: string | null, n: number) => (n >= min ? num(v) : null);
  return {
    wardId,
    hidden: false as const,
    windowDays: SCORECARD_WINDOW_DAYS,
    minSample: min,
    refreshedAt: r?.refreshed_at ?? null,
    metrics: {
      issuesReported: r?.issues_reported ?? 0,
      medianDaysAck: r ? gate(r.median_days_ack, r.ack_sample) : null,
      medianDaysFix: r ? gate(r.median_days_fix, r.fix_sample) : null,
      verifiedPct: r ? gate(r.verified_pct, r.verified_sample) : null,
      reopenPct: r ? gate(r.reopen_pct, r.reopen_sample) : null,
      openBacklog: r?.open_backlog ?? 0,
      reportsPer1000: r ? num(r.reports_per_1000) : null,
    },
    population: {
      value: ward.population,
      sourceNote: ward.population === null ? null : 'Census of India 2011 (ward population as published by AMC)',
    },
  };
}

/** Job body (`scorecard-refresh`, hourly). CONCURRENTLY keeps reads working during the refresh. */
export async function refreshScorecard(): Promise<void> {
  const started = Date.now();
  await prisma.$executeRawUnsafe('REFRESH MATERIALIZED VIEW CONCURRENTLY ward_scorecard_mv');
  logger.info({ event: 'scorecard_refreshed', ms: Date.now() - started }, 'scorecard_refreshed');
}
