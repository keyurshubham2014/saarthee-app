/**
 * Built-in feed providers (TASK-07 nearby issues) and adapters over the TASK-08 alerts and TASK-12
 * initiatives/services/tips services that are already on main. Removing one of those modules only
 * removes its registration here; the feed then reports that section as degraded.
 */
import { listAlerts } from '../alerts/alerts.service';
import { listInitiatives } from '../initiatives/initiatives.service';
import { listIssues } from '../issues/list.service';
import { listServices, listTips } from '../services/services.service';
import { FEED_LIMITS, registerFeedProvider } from './registry';

registerFeedProvider('nearbyIssues', async ({ wardId, lang }) => {
  const r = await listIssues(
    { ward: wardId, status: ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'], sort: 'most_affected', limit: FEED_LIMITS.nearbyIssues, lang },
    undefined,
  );
  return r.items;
});

registerFeedProvider('alerts', async ({ wardId, now }) => (await listAlerts({ wardIds: [wardId], active: true, limit: FEED_LIMITS.alerts, now })).items);

registerFeedProvider('drives', async ({ wardId }) => (await listInitiatives({ ward: wardId, upcoming: true, limit: FEED_LIMITS.drives })).items);

registerFeedProvider('serviceShortcuts', async () => (await listServices({})).items.slice(0, FEED_LIMITS.serviceShortcuts));

registerFeedProvider('tips', async ({ wardId }) => (await listTips({ ward: wardId })).items.slice(0, FEED_LIMITS.tips));
