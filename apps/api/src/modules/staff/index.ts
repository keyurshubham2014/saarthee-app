/**
 * TASK-10 staff console API: me/summary, moderation queue and issue tools, users & roles, categories,
 * app settings and CSV exports. Every route is role-guarded (requireStaff) and listed in staffMatrix.ts.
 */
import { Router } from 'express';
import { categoriesRouter } from './categories.routes';
import { exportRouter } from './export.routes';
import { meRouter } from './me.routes';
import { moderationRouter } from './moderation.routes';
import { settingsRouter } from './settings.routes';
import { usersRouter } from './users.routes';

export const staffRouter = Router();
staffRouter.use(meRouter);
staffRouter.use(moderationRouter);
staffRouter.use(usersRouter);
staffRouter.use(categoriesRouter);
staffRouter.use(settingsRouter);
staffRouter.use(exportRouter);

export { getAppSetting, APP_SETTING_KEYS } from './settings.routes';
export { staffTransition } from './status.service';
