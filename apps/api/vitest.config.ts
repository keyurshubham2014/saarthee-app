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
    // One shared test database: files run one after another, each test starts from resetDb().
    fileParallelism: false,
    testTimeout: 20_000,
    hookTimeout: 60_000,
    reporters: process.env.CI ? ['default', 'junit'] : ['default'],
    outputFile: { junit: 'test-results/junit.xml' },
  },
});
