/**
 * Manual push check (staff only, TASK-04 M-04-05):
 *   npm run push:test -- --topic ward_12
 *   npm run push:test -- --user <userId>
 * Sends a `system` test message through the configured PUSH_DRIVER and prints the delivery-log row status.
 */
import { prisma } from '../src/lib/db';
import { notifyTopic, notifyUser, type PushMessage } from '../src/lib/push';

const message: PushMessage = {
  kind: 'system',
  route: '/alerts',
  channel: 'alerts',
  title: { en: 'Saarthee test notification', gu: 'સારથી પરીક્ષણ સૂચના' },
  body: { en: 'If you see this, push works. Tap to open Alerts.', gu: 'આ દેખાય તો પુશ કામ કરે છે. ચેતવણીઓ ખોલવા ટૅપ કરો.' },
};

async function main() {
  const args = process.argv.slice(2);
  const flag = (name: string) => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const topic = flag('topic');
  const user = flag('user');
  if (!topic && !user) throw new Error('usage: push:test -- --topic ward_12 | --user <userId>');
  const row = topic ? await notifyTopic(topic, message) : await notifyUser(user!, message);
  console.log(`push:test notification=${row.id} status=${row.status} providerIds=${row.providerMessageIds.length} error=${row.errorCode ?? '-'}`);
}

main()
  .catch((err: unknown) => {
    console.error(`push:test failed: ${(err as Error).message}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
