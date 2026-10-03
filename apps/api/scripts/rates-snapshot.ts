// Prints pilot_rates_v as a console table (03 §5.3). Usage (in apps/api): npm run rates:snapshot
import { prisma } from '../src/lib/db';
import { getRates } from '../src/modules/rates/rates.service';

getRates()
  .then(({ rows, computedAt }) => {
    console.log(`pilot rates at ${computedAt}`);
    console.table(rows);
  })
  .catch((err: unknown) => {
    console.error('rates:snapshot failed:', err instanceof Error ? err.message : 'unknown error');
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
