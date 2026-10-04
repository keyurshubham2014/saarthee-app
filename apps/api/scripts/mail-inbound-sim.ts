/**
 * Dev only (TASK-11 M-11-08): simulates the mail provider's inbound webhook for a relayed message's email reply.
 *   npm run mail:inbound-sim -- <messageId> "Reply text" [apiBase]
 * Looks up (or creates) the message's reply token, signs the JSON payload with MAIL_INBOUND_SECRET and posts it
 * to <apiBase>/webhooks/mail-inbound (default http://127.0.0.1:4000/api/v1). Prints only the HTTP status.
 */
import { config } from '../src/config';
import { prisma } from '../src/lib/db';
import { newReplyToken, replyAddress, signInbound } from '../src/modules/rep-messages/inbox.service';

async function main() {
  const [messageId, text, base = 'http://127.0.0.1:4000/api/v1'] = process.argv.slice(2);
  if (!messageId || !text) throw Object.assign(new Error('usage'), { code: 'USAGE: <messageId> "<reply text>" [apiBase]' });
  if (!config.MAIL_INBOUND_SECRET) throw Object.assign(new Error('secret'), { code: 'MAIL_INBOUND_SECRET is not set' });
  const msg = await prisma.repMessage.findUniqueOrThrow({ where: { id: messageId }, select: { replyToken: true } });
  const token = msg.replyToken ?? newReplyToken();
  if (!msg.replyToken) await prisma.repMessage.update({ where: { id: messageId }, data: { replyToken: token } });
  const payload = JSON.stringify({
    to: replyAddress(token), from: 'office@example.org',
    text: `${text}\n\nOn Mon, 5 Oct 2026, Saarthee Relay wrote:\n> original message`, receivedAt: new Date().toISOString(),
  });
  const res = await fetch(`${base}/webhooks/mail-inbound`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Saarthee-Signature': signInbound(payload, config.MAIL_INBOUND_SECRET) },
    body: payload,
  });
  console.log(`mail-inbound-sim: HTTP ${res.status}`);
}

main()
  .catch((err: unknown) => {
    console.error(`mail-inbound-sim failed: ${(err as { code?: string }).code ?? (err as Error).name}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
