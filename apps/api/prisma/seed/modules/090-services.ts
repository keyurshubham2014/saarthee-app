import { defineSeedModule } from '../types';

/** Placeholder registered by V2 TASK-01; TASK-12 fills `run` (AMC services with source URLs). */
export default defineSeedModule({
  name: 'services',
  requires: ['services'],
  async run({ log }) {
    log('Seed services: module not implemented yet (TASK-12)');
  },
});
