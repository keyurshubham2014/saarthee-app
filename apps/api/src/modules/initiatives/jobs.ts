import { remindInitiatives } from './remind';

/**
 * Job definitions for the TASK-06 runner (`src/jobs`, registered by the integrator — wave-3 rule; this
 * module never imports the runner). 24-hour initiative reminders every 15 minutes (REQ-F-060); the job
 * itself is idempotent (reminder_sent_at under FOR UPDATE SKIP LOCKED), so overlapping runs are safe.
 */
export const jobs = [
  {
    name: 'initiatives-remind',
    everyMs: 15 * 60_000,
    run: async (): Promise<void> => {
      await remindInitiatives();
    },
  },
] as const;

export default jobs;
