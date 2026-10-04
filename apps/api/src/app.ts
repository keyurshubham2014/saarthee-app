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
  // CORS: exact-origin allow-list (CORS_ORIGINS + TASK-10 STAFF_WEB_ORIGINS); credentials off, Authorization allowed.
  const corsOrigins = [...config.CORS_ORIGINS, ...config.STAFF_WEB_ORIGINS];
  if (corsOrigins.length > 0) {
    app.use((req, res, next) => {
      const origin = req.header('origin');
      if (origin && corsOrigins.includes(origin)) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
        if (req.method === 'OPTIONS') {
          res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE');
          res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept-Language, X-Install-Id, X-App-Version, X-Platform, X-Request-Id');
          res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
          res.setHeader('Access-Control-Max-Age', '600');
          return void res.status(204).end();
        }
        res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition');
      }
      next();
    });
  }
  // TASK-11: signed webhooks (POST /webhooks/*) verify the HMAC over the exact bytes received.
  app.use(express.json({ limit: '64kb', verify: (req, _res, buf) => { if (req.url?.startsWith('/api/v1/webhooks/')) (req as { rawBody?: Buffer }).rawBody = buf; } }));
  app.use('/api/v1', apiRouter);
  // TASK-07: public share/evidence page /i/{id} (outside /api/v1).
  app.use(sharePageRouter);
  app.use(notFound);
  app.use(errorHandler);
  return app;
}
