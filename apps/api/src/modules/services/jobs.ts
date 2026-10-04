import { checkAllServiceLinks } from './link-check';

/**
 * Job definitions for the TASK-06 runner (`src/jobs`, registered by the integrator — wave-3 rule; this
 * module never imports the runner). Monthly link check at 06:00 on the 1st, Asia/Kolkata (REQ-F-058).
 */
export const jobs = [
  {
    name: 'services-check-links',
    cron: '0 6 1 * *',
    tz: 'Asia/Kolkata',
    run: async (): Promise<void> => {
      await checkAllServiceLinks();
    },
  },
] as const;

export default jobs;
