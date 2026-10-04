import { defineSeedModule } from '../types';
import { seedAmcProblemTypes, seedV2Categories, V2_CATEGORIES } from '../v2-categories';

/**
 * The 14 v2 categories with reviewed reference data (V2 TASK-05 §5.2: names, icons, SLA targets, sensitive
 * flags, colour tokens `category.<slug>`) and the AMC CCRS problem-type mapping from the committed snapshot.
 * The module keeps its TASK-01 name `categories-dev` so seed ordering stays stable.
 */
export const DEV_CATEGORIES = V2_CATEGORIES;

export default defineSeedModule({
  name: 'categories-dev',
  requires: ['categories', 'amc_problem_types'],
  async run({ prisma }) {
    await seedV2Categories(prisma);
    await seedAmcProblemTypes(prisma);
  },
});
