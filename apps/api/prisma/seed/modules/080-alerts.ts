import { defineSeedModule } from '../types';

/** Placeholder registered by V2 TASK-01; TASK-08 fills `run` (sample alerts in every status). */
export default defineSeedModule({
  name: 'alerts',
  requires: ['alerts'],
  async run({ log }) {
    log('Seed alerts: module not implemented yet (TASK-08)');
  },
});
