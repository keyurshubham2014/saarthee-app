/**
 * Feed section provider registry (V2 TASK-07 §5.3). A module adds a Home section by calling
 * registerFeedProvider() at import time; the feed never imports alerts/initiatives/services itself.
 * Each provider runs under a 150 ms budget; failure, timeout or absence → `{items: [], degraded: true}`.
 */
import { logger } from '../../lib/logger';

export const FEED_SECTIONS = ['alerts', 'nearbyIssues', 'drives', 'serviceShortcuts', 'tips'] as const;
export type FeedSection = (typeof FEED_SECTIONS)[number];

export interface FeedContext {
  wardId: string;
  lang: 'en' | 'gu';
  now: Date;
}

export type FeedProvider = (ctx: FeedContext) => Promise<unknown[]>;

export const FEED_LIMITS: Record<FeedSection, number> = { alerts: 5, nearbyIssues: 10, drives: 5, serviceShortcuts: 6, tips: 1 };
export const PROVIDER_TIMEOUT_MS = 150;

const providers = new Map<FeedSection, FeedProvider>();

export function registerFeedProvider(section: FeedSection, provider: FeedProvider): void {
  providers.set(section, provider);
}

/** Tests: drop or replace a provider (returns the previous one so it can be restored). */
export function swapFeedProvider(section: FeedSection, provider: FeedProvider | undefined): FeedProvider | undefined {
  const prev = providers.get(section);
  if (provider) providers.set(section, provider);
  else providers.delete(section);
  return prev;
}

const lastWarn = new Map<string, number>();
function warnOncePerMinute(section: string, reason: string) {
  const t = Date.now();
  if ((lastWarn.get(section) ?? 0) > t - 60_000) return;
  lastWarn.set(section, t);
  logger.warn({ section, reason }, 'feed_section_degraded');
}

export async function runSection(section: FeedSection, ctx: FeedContext): Promise<{ items: unknown[]; degraded: boolean }> {
  const p = providers.get(section);
  if (!p) return { items: [], degraded: true };
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<'timeout'>((resolve) => {
    timer = setTimeout(() => resolve('timeout'), PROVIDER_TIMEOUT_MS);
  });
  try {
    const r = await Promise.race([p(ctx), timeout]);
    if (r === 'timeout') {
      warnOncePerMinute(section, 'timeout');
      return { items: [], degraded: true };
    }
    return { items: r.slice(0, FEED_LIMITS[section]), degraded: false };
  } catch (err) {
    warnOncePerMinute(section, err instanceof Error ? err.message : 'error');
    return { items: [], degraded: true };
  } finally {
    clearTimeout(timer);
  }
}
