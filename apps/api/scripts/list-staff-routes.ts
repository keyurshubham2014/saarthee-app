/** Prints every registered `/staff/*` route (helper for maintaining src/middleware/staffMatrix.ts). */
import { listRoutes } from '../src/middleware/routeList';
import { apiRouter } from '../src/routes';

for (const r of listRoutes(apiRouter).filter((x) => x.split(' ')[1]!.startsWith('/staff')).sort()) console.log(r);
process.exit(0);
