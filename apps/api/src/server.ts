import type { Server } from 'node:http';
import { config } from './config';
import { createApp } from './app';
import { logger } from './lib/logger';
import { prisma } from './lib/db';
import { assertStorageReady } from './lib/storage';

let server: Server | undefined;

async function start() {
  try {
    await assertStorageReady();
  } catch (err) {
    logger.fatal({ reason: err instanceof Error ? err.message : 'unknown' }, 'photo storage not ready');
    process.exit(1);
  }
  server = createApp().listen(config.API_PORT, config.API_HOST, () => {
    logger.info({ host: config.API_HOST, port: config.API_PORT, env: config.APP_ENV }, 'api listening');
  });
}

function shutdown(signal: string) {
  logger.info({ signal }, 'shutting down');
  const done = () => void prisma.$disconnect().finally(() => process.exit(0));
  if (server) server.close(done);
  else done();
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

void start();
