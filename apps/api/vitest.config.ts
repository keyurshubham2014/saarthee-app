import { defineConfig } from 'vitest/config';
import { loadTestEnv } from './test/env';

// Throws before anything runs when the test database name does not contain "_test" (test/env.ts).
const env = loadTestEnv(__dirname);

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    globalSetup: ['test/global-setup.ts'],
    setupFiles: ['test/setup.ts'],
    env,
    // Each file gets its own fresh copy of the migrated template database (test/setup.ts), so files are
    // isolated from each other; inside a file, tests call resetDb() where they need an empty database.
    // Files run one after another: parallel workers (forks and threads pools) hung intermittently on this
    // machine (emulated amd64 PostGIS); set TEST_PARALLEL=1 to try parallel files.
    fileParallelism: process.env.TEST_PARALLEL === '1',
    pool: 'threads',
    testTimeout: 20_000,
    hookTimeout: 60_000,
    reporters: process.env.CI ? ['default', 'junit'] : ['default'],
    outputFile: { junit: 'test-results/junit.xml' },
  },
});
