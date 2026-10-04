import express from 'express';
import helmet from 'helmet';
import { config } from './config';
import { requestId } from './middleware/requestId';
import { requestLog } from './middleware/requestLog';
import { errorHandler, notFound } from './middleware/errorHandler';
import { apiRouter } from './routes';
import { sharePageRouter } from './modules/share-page';

/** Builds the Express app without listening (server.ts listens). */
export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', config.TRUST_PROXY);
  app.use(requestId);
  app.use(requestLog);
  app.use(
    helmet({
      contentSecurityPolicy: { useDefaults: false, directives: { defaultSrc: ["'none'"] } },
      frameguard: { action: 'deny' },
      referrerPolicy: { policy: 'no-referrer' },
      // HSTS only in production (V2 TASK-13 §5.3); local http stays usable.
      strictTransportSecurity:
        config.APP_ENV === 'production' ? { maxAge: 15_552_000, includeSubDomains: true, preload: false } : false,
    }),
  );
  if (config.CORS_ORIGINS.length > 0) {
    app.use((req, res, next) => {
      const origin = req.header('origin');
      if (origin && config.CORS_ORIGINS.includes(origin)) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
      }
      next();
    });
  }
  app.use(express.json({ limit: '64kb' }));
  app.use('/api/v1', apiRouter);
  // TASK-07: public share/evidence page /i/{id} (outside /api/v1).
  app.use(sharePageRouter);
  app.use(notFound);
  app.use(errorHandler);
  return app;
}
