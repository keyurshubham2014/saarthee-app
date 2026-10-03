import { config } from './config';
import { createApp } from './app';
import { logger } from './lib/logger';
import { prisma } from './lib/db';

const server = createApp().listen(config.API_PORT, config.API_HOST, () => {
  logger.info({ host: config.API_HOST, port: config.API_PORT, env: config.APP_ENV }, 'api listening');
});

function shutdown(signal: string) {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    void prisma.$disconnect().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
