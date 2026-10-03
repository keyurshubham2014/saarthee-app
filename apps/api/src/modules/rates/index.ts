import { Router } from 'express';
import { getRates } from './rates.service';

/** Mounted on the /admin router. */
export const ratesRouter = Router();

ratesRouter.get('/rates', async (_req, res) => {
  res.json(await getRates());
});
